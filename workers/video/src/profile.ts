import { ApiError, forbidden, invalid, unavailable } from "./errors";
import { publicVideoUrl } from "./uploads";

/**
 * Profile photos in R2 under `profile-images/{uid}/`.
 *
 * - The UID always comes from the verified Firebase ID token.
 * - An optional `uid` (query or JSON) must equal the token UID (else 403),
 *   so a client cannot write or delete another user's photo.
 * - Object keys are generated here; the client never chooses a path.
 */

export const MAX_PROFILE_IMAGE_BYTES = 5 * 1024 * 1024;
export const PROFILE_PREFIX = "profile-images/";
const MAX_LISTED = 100;

export const PROFILE_IMAGE_TYPES: Readonly<Record<string, string>> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

/** The parts of the R2 binding used for profile photos (injectable). */
export interface ProfileBucket {
  put(key: string, bytes: Uint8Array, contentType: string): Promise<void>;
  list(prefix: string, limit: number): Promise<string[]>;
  delete(keys: string[]): Promise<void>;
}

export interface ProfileDeps {
  bucket: ProfileBucket;
  publicBaseUrl: string;
  now?: () => Date;
  randomSuffix?: () => string;
}

const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export function profilePrefix(uid: string) {
  if (!UID_PATTERN.test(uid)) throw invalid("invalid-uid", "Invalid user id");
  return `${PROFILE_PREFIX}${uid}/`;
}

/** 403 when the client names a different user than the token. */
export function assertOwnUid(tokenUid: string, requested: unknown) {
  if (requested === undefined || requested === null || requested === "") return;
  if (requested !== tokenUid) {
    throw forbidden("not-owner", "You can only change your own profile photo");
  }
}

/** Detects the real image type from magic bytes. */
export function sniffImageType(bytes: Uint8Array): string | null {
  const at = (i: number) => bytes[i] ?? -1;
  if (at(0) === 0xff && at(1) === 0xd8 && at(2) === 0xff) return "image/jpeg";
  if (
    [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((b, i) => at(i) === b)
  ) {
    return "image/png";
  }
  const ascii = (from: number, to: number) =>
    String.fromCharCode(...bytes.subarray(from, to));
  if (bytes.length >= 12 && ascii(0, 4) === "RIFF" && ascii(8, 12) === "WEBP") {
    return "image/webp";
  }
  return null;
}

/** Reads at most [max] bytes; larger bodies are rejected without buffering them. */
export async function readLimited(
  body: ReadableStream<Uint8Array> | null,
  max: number,
): Promise<Uint8Array> {
  if (!body) return new Uint8Array(0);
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.length;
    if (total > max) {
      await reader.cancel().catch(() => {});
      throw new ApiError(413, "too-large", "Image is larger than 5 MB");
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

function randomSuffix() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** POST /profile/upload — raw image body, `Content-Type: image/jpeg|png|webp`. */
export async function uploadProfileImage(
  deps: ProfileDeps,
  uid: string,
  request: Request,
) {
  const url = new URL(request.url);
  assertOwnUid(uid, url.searchParams.get("uid"));
  const prefix = profilePrefix(uid);

  const declaredType = (request.headers.get("content-type") ?? "")
    .toLowerCase()
    .split(";")[0]!
    .trim();
  const extension = PROFILE_IMAGE_TYPES[declaredType];
  if (!extension) {
    throw new ApiError(415, "unsupported-format", "Only JPEG, PNG or WebP images");
  }
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (declaredLength > MAX_PROFILE_IMAGE_BYTES) {
    throw new ApiError(413, "too-large", "Image is larger than 5 MB");
  }

  const bytes = await readLimited(request.body, MAX_PROFILE_IMAGE_BYTES);
  if (bytes.length === 0) throw invalid("empty-file", "Image is empty");
  if (sniffImageType(bytes) !== declaredType) {
    throw new ApiError(415, "unsupported-format", "File content is not the declared image type");
  }

  const now = deps.now?.() ?? new Date();
  const objectKey = `${prefix}${now.getTime()}-${(deps.randomSuffix ?? randomSuffix)()}.${extension}`;
  try {
    await deps.bucket.put(objectKey, bytes, declaredType);
  } catch {
    throw unavailable("storage-unavailable", "Image storage is unavailable");
  }

  // Keep only the newest photo of this user (never touches other prefixes).
  try {
    const old = (await deps.bucket.list(prefix, MAX_LISTED)).filter(
      (key) => key !== objectKey && key.startsWith(prefix),
    );
    if (old.length) await deps.bucket.delete(old);
  } catch {
    console.error("profile cleanup failed", uid);
  }

  return {
    url: publicVideoUrl(deps.publicBaseUrl, objectKey),
    objectKey,
    contentType: declaredType,
    sizeBytes: bytes.length,
  };
}

/** POST /profile/delete — removes every photo of the token's user. */
export async function deleteProfileImages(
  deps: ProfileDeps,
  uid: string,
  body: unknown,
) {
  const requested =
    body && typeof body === "object" ? (body as Record<string, unknown>).uid : undefined;
  assertOwnUid(uid, requested);
  const prefix = profilePrefix(uid);
  let keys: string[];
  try {
    keys = (await deps.bucket.list(prefix, MAX_LISTED)).filter((key) =>
      key.startsWith(prefix),
    );
    if (keys.length) await deps.bucket.delete(keys);
  } catch {
    throw unavailable("storage-unavailable", "Image storage is unavailable");
  }
  return { deleted: keys.length };
}
