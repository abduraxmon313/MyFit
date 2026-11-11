import { ApiError, invalid, unavailable } from "./errors";
import { FirestoreAborted, type FirestoreApi, type FsFields } from "./firestore";
import type { IdentityApi } from "./identity";

/**
 * SMS sign-in through DevSMS (devsms.uz) instead of Firebase Phone Auth.
 *
 *  POST /auth/sms/send   { phone }        -> SMS with a 6 digit code
 *  POST /auth/sms/verify { phone, code }  -> Firebase custom token
 *
 * The code is generated here and stored only as an HMAC in Firestore
 * (`sms_codes/{sha256(phone)}`, no client access). The Firebase user is
 * looked up by phone number, so existing users keep their UID and data.
 */

export const CODE_TTL_MS = 5 * 60 * 1000;
export const RESEND_AFTER_MS = 60 * 1000;
export const MAX_SENDS_PER_DAY = 5;
export const MAX_ATTEMPTS = 5;
export const MAX_SENDS_PER_IP_HOUR = 10;
const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const TRANSACTION_ATTEMPTS = 4;

export interface SmsSender {
  /** Sends [code] to [phone] (digits, e.g. 998901234567). */
  sendCode(phone: string, code: string): Promise<void>;
}

export interface SmsDeps {
  db: FirestoreApi;
  identity: IdentityApi;
  sender: SmsSender;
  /** HMAC key for stored codes (derived from a Worker secret). */
  hmacKey: () => Promise<CryptoKey>;
  now?: () => Date;
  randomCode?: () => string;
}

/** `998XXXXXXXXX` from common Uzbek inputs; throws otherwise. */
export function normalizeUzPhone(input: unknown): string {
  let digits = String(input ?? "").replace(/\D/g, "");
  if (digits.length === 9) digits = `998${digits}`;
  if (!/^998\d{9}$/.test(digits)) {
    throw invalid("invalid-phone", "Uzbek phone number required (+998XXXXXXXXX)");
  }
  return digits;
}

export function randomSixDigits(): string {
  // Rejection sampling: uniform 000000-999999.
  const limit = Math.floor(0x1_0000_0000 / 1_000_000) * 1_000_000;
  for (;;) {
    const [value] = crypto.getRandomValues(new Uint32Array(1));
    if (value! < limit) return String(value! % 1_000_000).padStart(6, "0");
  }
}

export async function hmacKeyFromSecret(secret: string): Promise<CryptoKey> {
  const material = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`myfit-sms-otp-v1\n${secret}`),
  );
  return crypto.subtle.importKey("raw", material, { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
    "verify",
  ]);
}

const hex = (buffer: ArrayBuffer) =>
  Array.from(new Uint8Array(buffer), (b) => b.toString(16).padStart(2, "0")).join("");

async function sha256Hex(text: string) {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
}

async function codeHash(key: CryptoKey, phone: string, code: string) {
  return hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${phone}:${code}`)));
}

function sameHex(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const time = (value: unknown) => (value instanceof Date ? value.getTime() : 0);
const num = (value: unknown) => (typeof value === "number" && Number.isFinite(value) ? value : 0);

async function inTransaction<T>(db: FirestoreApi, run: (tx: string) => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    const tx = await db.beginTransaction();
    try {
      return await run(tx);
    } catch (error) {
      if (error instanceof FirestoreAborted && attempt < TRANSACTION_ATTEMPTS) continue;
      if (!(error instanceof ApiError)) await db.rollback(tx);
      if (error instanceof FirestoreAborted) {
        throw unavailable("database-unavailable", "Firestore is busy, retry");
      }
      throw error;
    }
  }
}

function tooMany(reason: string, message: string, retryAfterMs: number) {
  const error = new ApiError(429, reason, message);
  (error as ApiError & { retryAfter?: number }).retryAfter = Math.ceil(retryAfterMs / 1000);
  return error;
}

/** POST /auth/sms/send */
export async function sendSmsCode(deps: SmsDeps, body: unknown, clientIp: string | null) {
  const phone = normalizeUzPhone((body as Record<string, unknown> | null)?.phone);
  const nowDate = deps.now?.() ?? new Date();
  const now = nowDate.getTime();
  const phoneDoc = `sms_codes/${await sha256Hex(phone)}`;
  const ipDoc = clientIp ? `sms_ip/${await sha256Hex(`ip:${clientIp}`)}` : null;
  const code = (deps.randomCode ?? randomSixDigits)();
  const hash = await codeHash(await deps.hmacKey(), phone, code);

  await inTransaction(deps.db, async (tx) => {
    const current = (await deps.db.get(phoneDoc, tx))?.fields ?? {};
    const sinceLast = now - time(current.sentAt);
    if (sinceLast < RESEND_AFTER_MS) {
      await deps.db.rollback(tx);
      throw tooMany("resend-too-soon", "Wait before requesting a new code", RESEND_AFTER_MS - sinceLast);
    }
    const sameDay = now - time(current.dayStart) < DAY_MS;
    const sendsToday = sameDay ? num(current.sendsToday) : 0;
    if (sendsToday >= MAX_SENDS_PER_DAY) {
      await deps.db.rollback(tx);
      throw tooMany("too-many-requests", "Daily SMS limit reached", DAY_MS - (now - time(current.dayStart)));
    }

    let ipFields: FsFields | null = null;
    if (ipDoc) {
      const ip = (await deps.db.get(ipDoc, tx))?.fields ?? {};
      const sameHour = now - time(ip.windowStart) < HOUR_MS;
      const count = sameHour ? num(ip.count) : 0;
      if (count >= MAX_SENDS_PER_IP_HOUR) {
        await deps.db.rollback(tx);
        throw tooMany("too-many-requests", "Too many requests from this network", HOUR_MS - (now - time(ip.windowStart)));
      }
      ipFields = {
        count: count + 1,
        windowStart: sameHour ? (ip.windowStart as Date) : nowDate,
        expiresAt: new Date(now + DAY_MS),
      };
    }

    await deps.db.commit(
      [
        {
          kind: "set",
          path: phoneDoc,
          fields: {
            codeHash: hash,
            attempts: 0,
            sentAt: nowDate,
            expiresAt: new Date(now + CODE_TTL_MS),
            dayStart: sameDay ? (current.dayStart as Date) : nowDate,
            sendsToday: sendsToday + 1,
          },
        },
        ...(ipDoc && ipFields ? [{ kind: "set" as const, path: ipDoc, fields: ipFields }] : []),
      ],
      tx,
    );
  });

  await deps.sender.sendCode(phone, code);
  return {
    sent: true,
    expiresInSeconds: CODE_TTL_MS / 1000,
    resendAfterSeconds: RESEND_AFTER_MS / 1000,
  };
}

/** POST /auth/sms/verify */
export async function verifySmsCode(deps: SmsDeps, body: unknown) {
  const input = (body ?? {}) as Record<string, unknown>;
  const phone = normalizeUzPhone(input.phone);
  const code = String(input.code ?? "").trim();
  if (!/^\d{6}$/.test(code)) throw invalid("invalid-code", "6 digit code required");
  const now = (deps.now?.() ?? new Date()).getTime();
  const phoneDoc = `sms_codes/${await sha256Hex(phone)}`;
  const expected = await codeHash(await deps.hmacKey(), phone, code);

  const outcome = await inTransaction(deps.db, async (tx) => {
    const fields = (await deps.db.get(phoneDoc, tx))?.fields;
    if (!fields || typeof fields.codeHash !== "string" || fields.consumed === true || time(fields.expiresAt) < now) {
      await deps.db.rollback(tx);
      return { ok: false as const, reason: "code-expired" };
    }
    const attempts = num(fields.attempts);
    if (attempts >= MAX_ATTEMPTS) {
      await deps.db.rollback(tx);
      return { ok: false as const, reason: "too-many-attempts" };
    }
    const match = sameHex(fields.codeHash, expected);
    await deps.db.commit(
      [
        {
          kind: "set",
          path: phoneDoc,
          fields: match
            ? { ...fields, codeHash: null, consumed: true, attempts: attempts + 1 }
            : { ...fields, attempts: attempts + 1 },
        },
      ],
      tx,
    );
    return match
      ? { ok: true as const }
      : { ok: false as const, reason: attempts + 1 >= MAX_ATTEMPTS ? "too-many-attempts" : "invalid-code" };
  });

  if (!outcome.ok) {
    throw outcome.reason === "code-expired"
      ? new ApiError(410, "code-expired", "Code expired, request a new one")
      : outcome.reason === "too-many-attempts"
        ? new ApiError(429, "too-many-attempts", "Too many wrong codes, request a new one")
        : invalid("invalid-code", "Wrong code");
  }

  const uid = await deps.identity.uidForPhone(`+${phone}`);
  return { customToken: await deps.identity.customToken(uid) };
}

/** DevSMS universal OTP (pre-approved templates, no moderation needed). */
export class DevSmsSender implements SmsSender {
  constructor(
    private readonly apiToken: string,
    private readonly fetcher: typeof fetch = (input, init) => fetch(input, init),
    private readonly serviceName = "MyFit",
  ) {}

  async sendCode(phone: string, code: string): Promise<void> {
    if (!this.apiToken) throw new ApiError(500, "sms-misconfigured", "DEVSMS_API_TOKEN is not set");
    const idempotencyKey = crypto.randomUUID();
    const body = JSON.stringify({
      phone,
      otp: { template_type: 4, service_name: this.serviceName, code },
    });
    // One retry with the same Idempotency-Key never sends a second SMS.
    for (let attempt = 0; attempt < 2; attempt++) {
      let response: Response;
      try {
        response = await this.fetcher("https://devsms.uz/api/v1/sms", {
          method: "POST",
          headers: {
            authorization: `Bearer ${this.apiToken}`,
            "content-type": "application/json",
            accept: "application/json",
            "idempotency-key": idempotencyKey,
          },
          body,
        });
      } catch {
        if (attempt === 0) continue;
        throw unavailable("sms-unavailable", "SMS service unreachable");
      }
      const json = (await response.json().catch(() => ({}))) as Record<string, unknown>;
      if (response.ok && json.success !== false) return;
      const errorCode = String(json.error_code ?? "");
      console.error("DevSMS failed", response.status, errorCode);
      if ((response.status === 502 || response.status === 409) && attempt === 0) continue;
      if (response.status === 401 || response.status === 403) {
        throw new ApiError(502, "sms-misconfigured", "SMS provider rejected the request");
      }
      if (response.status === 402 || errorCode === "insufficient_balance") {
        throw new ApiError(503, "sms-unavailable", "SMS balance is empty");
      }
      if (response.status === 422 || response.status === 400) {
        throw invalid("invalid-phone", "SMS provider rejected the phone number");
      }
      throw unavailable("sms-unavailable", "SMS service failed");
    }
    throw unavailable("sms-unavailable", "SMS service failed");
  }
}
