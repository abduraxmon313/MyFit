import { FirebaseTokenVerifier } from "./auth";
import { ApiError } from "./errors";
import { FirestoreRest, parseServiceAccount, type FirestoreApi } from "./firestore";
import { IdentityRest, type IdentityApi } from "./identity";
import { presignPut } from "./presign";
import {
  DevSmsSender,
  hmacKeyFromSecret,
  sendSmsCode,
  verifySmsCode,
  type SmsDeps,
} from "./sms";
import {
  deleteProfileImages,
  uploadProfileImage,
  type ProfileBucket,
  type ProfileDeps,
} from "./profile";
import {
  createUpload,
  finalizeUpload,
  UPLOAD_URL_TTL_SECONDS,
  type UploadDeps,
  type VideoBucket,
} from "./uploads";

export interface Env {
  VIDEOS: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  R2_ENDPOINT: string;
  R2_BUCKET: string;
  R2_PUBLIC_BASE_URL: string;
  ALLOWED_ORIGINS?: string;
  // Secrets (wrangler secret put):
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  FIREBASE_SERVICE_ACCOUNT: string;
  /** DevSMS API token (optional until SMS sign-in is enabled). */
  DEVSMS_API_TOKEN?: string;
}

const MAX_BODY_BYTES = 8 * 1024;

export function r2VideoBucket(bucket: R2Bucket): VideoBucket {
  return {
    async head(key) {
      const object = await bucket.head(key);
      return object
        ? { size: object.size, contentType: object.httpMetadata?.contentType }
        : null;
    },
    async readRange(key, offset, length) {
      const object = await bucket.get(key, { range: { offset, length } });
      if (!object) throw new Error("Object disappeared");
      return new Uint8Array(await object.arrayBuffer());
    },
    async delete(key) {
      await bucket.delete(key);
    },
  };
}

export function r2ProfileBucket(bucket: R2Bucket): ProfileBucket {
  return {
    async put(key, bytes, contentType) {
      await bucket.put(key, bytes, {
        httpMetadata: {
          contentType,
          // Keys are unique per upload, so the public URL can be cached.
          cacheControl: "public, max-age=31536000, immutable",
        },
      });
    },
    async list(prefix, limit) {
      const listed = await bucket.list({ prefix, limit });
      return listed.objects.map((object) => object.key);
    },
    async delete(keys) {
      await bucket.delete(keys);
    },
  };
}

// Per-isolate singletons keep the JWKS and OAuth token caches warm.
let verifier: FirebaseTokenVerifier | null = null;
let firestore: { key: string; api: FirestoreApi } | null = null;

function tokenVerifier(env: Env) {
  verifier ??= new FirebaseTokenVerifier(env.FIREBASE_PROJECT_ID);
  return verifier;
}

/** Built lazily, after the token is verified, so a bad secret never turns
 *  unauthenticated requests into 500s. */
function firestoreApi(env: Env): FirestoreApi {
  const key = `${env.FIREBASE_PROJECT_ID}|${env.FIREBASE_SERVICE_ACCOUNT?.length}`;
  if (!firestore || firestore.key !== key) {
    firestore = {
      key,
      api: new FirestoreRest(
        env.FIREBASE_PROJECT_ID,
        parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT),
      ),
    };
  }
  return firestore.api;
}

let identity: { key: string; api: IdentityApi } | null = null;
let otpKey: { key: string; value: Promise<CryptoKey> } | null = null;

function smsDeps(env: Env): SmsDeps {
  const key = `${env.FIREBASE_PROJECT_ID}|${env.FIREBASE_SERVICE_ACCOUNT?.length}`;
  if (!identity || identity.key !== key) {
    identity = {
      key,
      api: new IdentityRest(env.FIREBASE_PROJECT_ID, parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT)),
    };
  }
  if (!otpKey || otpKey.key !== key) {
    // Derived from an existing secret: no extra secret to manage.
    otpKey = {
      key,
      value: hmacKeyFromSecret(parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT).private_key),
    };
  }
  const hmac = otpKey.value;
  return {
    db: lazyFirestore(env),
    identity: identity.api,
    sender: new DevSmsSender(env.DEVSMS_API_TOKEN ?? ""),
    hmacKey: () => hmac,
  };
}

/** Defers every Firestore call to [firestoreApi]. */
function lazyFirestore(env: Env): FirestoreApi {
  return {
    get: (path, tx) => firestoreApi(env).get(path, tx),
    lastLessonOrder: (id, tx) => firestoreApi(env).lastLessonOrder(id, tx),
    beginTransaction: () => firestoreApi(env).beginTransaction(),
    rollback: (tx) => firestoreApi(env).rollback(tx),
    commit: (writes, tx) => firestoreApi(env).commit(writes, tx),
  };
}

function corsHeaders(request: Request, env: Env): Record<string, string> {
  const origin = request.headers.get("origin");
  const allowed = (env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (!origin || !allowed.includes(origin)) return {};
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-max-age": "3600",
    vary: "origin",
  };
}

function json(body: unknown, status: number, extra: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      ...extra,
    },
  });
}

async function readJson(request: Request): Promise<unknown> {
  if (!(request.headers.get("content-type") ?? "").startsWith("application/json")) {
    throw new ApiError(415, "invalid-request", "JSON body required");
  }
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (declared > MAX_BODY_BYTES) {
    throw new ApiError(413, "invalid-request", "Body too large");
  }
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) {
    throw new ApiError(413, "invalid-request", "Body too large");
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new ApiError(400, "invalid-request", "Invalid JSON");
  }
}

export async function handle(
  request: Request,
  env: Env,
  override?: {
    verify?: (h: string | null) => Promise<{ uid: string }>;
    deps?: UploadDeps;
    profile?: ProfileDeps;
    sms?: SmsDeps;
  },
): Promise<Response> {
  const cors = corsHeaders(request, env);
  const { pathname } = new URL(request.url);
  const videoRoutes = ["/createVideoUpload", "/finalizeVideoUpload"];
  const profileRoutes = ["/profile/upload", "/profile/delete"];
  const smsRoutes = ["/auth/sms/send", "/auth/sms/verify"];
  const routes = [...videoRoutes, ...profileRoutes, ...smsRoutes];
  try {
    if (!routes.includes(pathname)) {
      throw new ApiError(404, "not-found", "Unknown endpoint");
    }
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (request.method !== "POST") {
      throw new ApiError(405, "method-not-allowed", "POST only");
    }

    if (smsRoutes.includes(pathname)) {
      // Public: the user is not signed in yet. Rate limits live in sms.ts.
      const body = await readJson(request);
      const sms = override?.sms ?? smsDeps(env);
      const result =
        pathname === "/auth/sms/send"
          ? await sendSmsCode(sms, body, request.headers.get("cf-connecting-ip"))
          : await verifySmsCode(sms, body);
      return json(result, 200, cors);
    }

    const verify =
      override?.verify ?? ((header: string | null) => tokenVerifier(env).verify(header));

    if (profileRoutes.includes(pathname)) {
      // Any signed-in user; only for their own UID (no admin needed).
      const { uid } = await verify(request.headers.get("authorization"));
      const profile: ProfileDeps = override?.profile ?? {
        bucket: r2ProfileBucket(env.VIDEOS),
        publicBaseUrl: env.R2_PUBLIC_BASE_URL,
      };
      const result =
        pathname === "/profile/upload"
          ? await uploadProfileImage(profile, uid, request)
          : await deleteProfileImages(profile, uid, await readJson(request));
      return json(result, 200, cors);
    }

    let deps = override?.deps;
    if (!deps) {
      deps = {
        db: lazyFirestore(env),
        bucket: r2VideoBucket(env.VIDEOS),
        publicBaseUrl: env.R2_PUBLIC_BASE_URL,
        presign: (key, type, size) =>
          presignPut(
            {
              endpoint: env.R2_ENDPOINT,
              bucket: env.R2_BUCKET,
              accessKeyId: env.R2_ACCESS_KEY_ID,
              secretAccessKey: env.R2_SECRET_ACCESS_KEY,
            },
            key,
            type,
            size,
            UPLOAD_URL_TTL_SECONDS,
          ),
      };
    }

    // The UID comes only from the verified token, never from the body.
    const { uid } = await verify(request.headers.get("authorization"));
    const body = await readJson(request);
    const result =
      pathname === "/createVideoUpload"
        ? await createUpload(deps, uid, body)
        : await finalizeUpload(deps, uid, body);
    return json(result, 200, cors);
  } catch (error) {
    if (error instanceof ApiError) {
      const retryAfter = (error as ApiError & { retryAfter?: number }).retryAfter;
      return json(
        {
          error: {
            reason: error.reason,
            message: error.message,
            ...(retryAfter ? { retryAfterSeconds: retryAfter } : {}),
          },
        },
        error.status,
        retryAfter ? { ...cors, "retry-after": String(retryAfter) } : cors,
      );
    }
    console.error("video api failed", (error as Error)?.name, (error as Error)?.message);
    return json(
      { error: { reason: "internal", message: "Video upload failed" } },
      500,
      cors,
    );
  }
}

export default {
  fetch: (request, env) => handle(request, env),
} satisfies ExportedHandler<Env>;
