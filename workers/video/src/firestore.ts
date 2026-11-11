import { importPKCS8, SignJWT } from "jose";
import { ApiError, unavailable } from "./errors";
import type { Fetcher } from "./auth";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const SCOPE = "https://www.googleapis.com/auth/datastore";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

export function parseServiceAccount(raw: string | undefined): ServiceAccount {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw ?? "");
  } catch {
    throw new Error("FIREBASE_SERVICE_ACCOUNT is not valid JSON");
  }
  const account = parsed as Partial<ServiceAccount>;
  if (
    typeof account.client_email !== "string" ||
    typeof account.private_key !== "string" ||
    !account.private_key.includes("PRIVATE KEY")
  ) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT lacks client_email/private_key");
  }
  return { client_email: account.client_email, private_key: account.private_key };
}

/** Plain JS values stored in Firestore documents. */
export type FsValue =
  | null
  | boolean
  | number
  | string
  | Date
  | FsValue[]
  | { [key: string]: FsValue };
export type FsFields = Record<string, FsValue>;

type RestValue = Record<string, unknown>;

export function encodeValue(value: FsValue): RestValue {
  if (value === null) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    if (!Number.isFinite(value)) throw new Error("Non-finite number");
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === "string") return { stringValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  return { mapValue: { fields: encodeFields(value) } };
}

export function encodeFields(fields: FsFields): Record<string, RestValue> {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, encodeValue(value)]),
  );
}

export function decodeValue(value: RestValue): FsValue {
  if ("nullValue" in value) return null;
  if ("booleanValue" in value) return value.booleanValue as boolean;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("stringValue" in value) return value.stringValue as string;
  if ("timestampValue" in value) return new Date(value.timestampValue as string);
  if ("arrayValue" in value) {
    const values = (value.arrayValue as { values?: RestValue[] }).values ?? [];
    return values.map(decodeValue);
  }
  if ("mapValue" in value) {
    return decodeFields(
      (value.mapValue as { fields?: Record<string, RestValue> }).fields ?? {},
    );
  }
  // Unsupported types (references, geo points, bytes) are not used here.
  return null;
}

export function decodeFields(fields: Record<string, RestValue>): FsFields {
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]),
  );
}

export interface FsDocument {
  id: string;
  fields: FsFields;
}

export type FsWrite =
  | { kind: "create"; path: string; fields: FsFields }
  | { kind: "update"; path: string; fields: FsFields }
  /** Create or fully replace (no precondition). */
  | { kind: "set"; path: string; fields: FsFields };

/** The subset of Firestore used by the video API (injectable for tests). */
export interface FirestoreApi {
  get(path: string, transaction?: string): Promise<FsDocument | null>;
  /** Highest `order` among `courses/{courseId}/lessons`. */
  lastLessonOrder(courseId: string, transaction?: string): Promise<number>;
  beginTransaction(): Promise<string>;
  rollback(transaction: string): Promise<void>;
  commit(writes: FsWrite[], transaction?: string): Promise<void>;
}

/** Transaction contention; the caller may retry. */
export class FirestoreAborted extends Error {}

/**
 * Firestore REST client authenticated as a service account.
 * Service accounts bypass security rules, so callers must enforce access.
 */
export class FirestoreRest implements FirestoreApi {
  private token: { value: string; expiresAt: number } | null = null;
  private keyPromise: ReturnType<typeof importPKCS8> | null = null;
  private readonly root: string;

  constructor(
    projectId: string,
    private readonly account: ServiceAccount,
    private readonly fetcher: Fetcher = (input, init) => fetch(input, init),
    private readonly now: () => number = () => Date.now(),
  ) {
    this.root = `projects/${projectId}/databases/(default)/documents`;
  }

  private url(suffix: string) {
    return `https://firestore.googleapis.com/v1/${this.root}${suffix}`;
  }

  private name(path: string) {
    return `${this.root}/${path}`;
  }

  private async accessToken(): Promise<string> {
    const now = this.now();
    if (this.token && this.token.expiresAt > now) return this.token.value;
    this.keyPromise ??= importPKCS8(this.account.private_key, "RS256");
    const issuedAt = Math.floor(now / 1000);
    const assertion = await new SignJWT({ scope: SCOPE })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuer(this.account.client_email)
      .setSubject(this.account.client_email)
      .setAudience(TOKEN_URL)
      .setIssuedAt(issuedAt)
      .setExpirationTime(issuedAt + 3600)
      .sign(await this.keyPromise);
    const response = await this.send(TOKEN_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    if (!response.ok) {
      console.error("Google OAuth failed", response.status);
      throw unavailable("database-unavailable", "Google OAuth failed");
    }
    const json = (await response.json()) as {
      access_token?: string;
      expires_in?: number;
    };
    if (!json.access_token) {
      throw unavailable("database-unavailable", "No access token");
    }
    this.token = {
      value: json.access_token,
      expiresAt: now + Math.max(60, (json.expires_in ?? 3600) - 300) * 1000,
    };
    return this.token.value;
  }

  private async send(url: string, init: RequestInit): Promise<Response> {
    try {
      return await this.fetcher(url, init);
    } catch {
      throw unavailable("database-unavailable", "Cannot reach Google APIs");
    }
  }

  private async call(url: string, init: RequestInit = {}): Promise<Response> {
    const token = await this.accessToken();
    const response = await this.send(url, {
      ...init,
      headers: {
        ...(init.headers as Record<string, string> | undefined),
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
    });
    if (response.status === 409) {
      throw new FirestoreAborted("Transaction aborted");
    }
    return response;
  }

  private async fail(response: Response, operation: string): Promise<never> {
    const text = await response.text().catch(() => "");
    console.error(`Firestore ${operation} failed`, response.status, text.slice(0, 300));
    if (response.status === 429 || response.status >= 500) {
      throw unavailable("database-unavailable", `Firestore ${operation} failed`);
    }
    throw new ApiError(500, "internal", `Firestore ${operation} failed`);
  }

  async get(path: string, transaction?: string): Promise<FsDocument | null> {
    const query = transaction
      ? `?transaction=${encodeURIComponent(transaction)}`
      : "";
    const response = await this.call(this.url(`/${path}${query}`));
    if (response.status === 404) return null;
    if (!response.ok) return this.fail(response, "get");
    const doc = (await response.json()) as {
      fields?: Record<string, RestValue>;
    };
    return {
      id: path.split("/").pop()!,
      fields: decodeFields(doc.fields ?? {}),
    };
  }

  async lastLessonOrder(courseId: string, transaction?: string) {
    const response = await this.call(this.url(`/courses/${courseId}:runQuery`), {
      method: "POST",
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "lessons" }],
          orderBy: [{ field: { fieldPath: "order" }, direction: "DESCENDING" }],
          limit: 1,
        },
        ...(transaction ? { transaction } : {}),
      }),
    });
    if (!response.ok) return this.fail(response, "runQuery");
    const rows = (await response.json()) as {
      document?: { fields?: Record<string, RestValue> };
    }[];
    const order = rows.find((row) => row.document)?.document?.fields?.order;
    const value = order ? Number(decodeValue(order)) : 0;
    return Number.isFinite(value) ? value : 0;
  }

  async beginTransaction(): Promise<string> {
    const response = await this.call(this.url(":beginTransaction"), {
      method: "POST",
      body: JSON.stringify({ options: { readWrite: {} } }),
    });
    if (!response.ok) return this.fail(response, "beginTransaction");
    return ((await response.json()) as { transaction: string }).transaction;
  }

  async rollback(transaction: string): Promise<void> {
    try {
      await this.call(this.url(":rollback"), {
        method: "POST",
        body: JSON.stringify({ transaction }),
      });
    } catch {
      // Best effort; the transaction expires on its own.
    }
  }

  async commit(writes: FsWrite[], transaction?: string): Promise<void> {
    const body = {
      writes: writes.map((write) =>
        write.kind === "set"
          ? {
              update: {
                name: this.name(write.path),
                fields: encodeFields(write.fields),
              },
            }
          : write.kind === "create"
          ? {
              update: {
                name: this.name(write.path),
                fields: encodeFields(write.fields),
              },
              currentDocument: { exists: false },
            }
          : {
              update: {
                name: this.name(write.path),
                fields: encodeFields(write.fields),
              },
              updateMask: { fieldPaths: Object.keys(write.fields) },
              currentDocument: { exists: true },
            },
      ),
      ...(transaction ? { transaction } : {}),
    };
    const response = await this.call(this.url(":commit"), {
      method: "POST",
      body: JSON.stringify(body),
    });
    if (!response.ok) return this.fail(response, "commit");
  }
}
