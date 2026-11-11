import { ApiError, invalid, unavailable } from "./errors";
import { FirestoreAborted, type FirestoreApi, type FsFields } from "./firestore";
import { DevSmsClient, renderTemplate, type DevSmsTemplate } from "./devsms";
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
      ? { ok: true as const, previous: fields }
      : { ok: false as const, reason: attempts + 1 >= MAX_ATTEMPTS ? "too-many-attempts" : "invalid-code" };
  });

  if (!outcome.ok) {
    throw outcome.reason === "code-expired"
      ? new ApiError(410, "code-expired", "Code expired, request a new one")
      : outcome.reason === "too-many-attempts"
        ? new ApiError(429, "too-many-attempts", "Too many wrong codes, request a new one")
        : invalid("invalid-code", "Wrong code");
  }

  try {
    const uid = await deps.identity.uidForPhone(`+${phone}`);
    return { customToken: await deps.identity.customToken(uid) };
  } catch (error) {
    // Sign-in failed on our side: give the code back so the user can retry
    // it (same expiry; the wrong-attempt counter is unchanged).
    try {
      await deps.db.commit([{ kind: "set", path: phoneDoc, fields: outcome.previous }]);
    } catch {
      console.error("could not restore SMS code after sign-in failure");
    }
    throw error;
  }
}

/** Which DevSMS template the OTP uses (chosen by the owner, see docs). */
export interface OtpTemplateConfig {
  templateId: string;
  /**
   * Text replaced by the code: a token like `{code}`, or the example code
   * written literally in the approved template (e.g. `583921`). Auto when
   * the text has exactly one token.
   */
  codePlaceholder?: string;
  /** Fixed values for other tokens, e.g. `{"{app}": "MyFit"}`. */
  values?: Record<string, string>;
  from?: string;
}

export function parseOtpTemplateConfig(env: {
  DEVSMS_OTP_TEMPLATE_ID?: string;
  DEVSMS_OTP_CODE_PLACEHOLDER?: string;
  DEVSMS_OTP_TEMPLATE_VALUES?: string;
  DEVSMS_FROM?: string;
}): OtpTemplateConfig | undefined {
  const templateId = (env.DEVSMS_OTP_TEMPLATE_ID ?? "").trim();
  if (!templateId) return undefined;
  let values: Record<string, string> = {};
  const raw = (env.DEVSMS_OTP_TEMPLATE_VALUES ?? "").trim();
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      values = Object.fromEntries(Object.entries(parsed).map(([k, v]) => [k, String(v)]));
    } catch {
      throw new ApiError(500, "sms-misconfigured", "DEVSMS_OTP_TEMPLATE_VALUES is not JSON");
    }
  }
  return {
    templateId,
    codePlaceholder: (env.DEVSMS_OTP_CODE_PLACEHOLDER ?? "").trim() || undefined,
    values,
    from: (env.DEVSMS_FROM ?? "").trim() || undefined,
  };
}

const TEMPLATE_CACHE_MS = 10 * 60 * 1000;
const templateCache = new Map<string, { template: DevSmsTemplate; expiresAt: number }>();

/**
 * Sends the OTP through DevSMS. Without a configured template it uses the
 * pre-approved universal OTP; with one, it reads the owner's template via
 * `templates:read`, fills the code and sends it with `template_id`.
 */
export class DevSmsSender implements SmsSender {
  private readonly client: DevSmsClient;

  constructor(
    apiToken: string,
    fetcher: typeof fetch = (input, init) => fetch(input, init),
    private readonly serviceName = "MyFit",
    private readonly template?: OtpTemplateConfig,
    private readonly now: () => number = () => Date.now(),
  ) {
    this.client = new DevSmsClient(apiToken, fetcher);
  }

  async sendCode(phone: string, code: string): Promise<void> {
    if (!this.template) {
      await this.client.sendUniversalOtp(phone, code, this.serviceName);
      return;
    }
    const template = await this.findTemplate(this.template.templateId);
    const token =
      this.template.codePlaceholder ??
      (template.placeholders.length === 1 ? template.placeholders[0] : undefined);
    if (!token || !template.text.includes(token)) {
      throw new ApiError(
        500,
        "sms-misconfigured",
        `Template ${template.id} has no code placeholder (${template.placeholders.join(", ") || "none"})`,
      );
    }
    const values = { ...this.template.values };
    let message: string;
    if (template.placeholders.includes(token)) {
      message = renderTemplate(template.text, { ...values, [token]: code });
    } else {
      // Literal example code in the approved text: swap it for the real one.
      if (template.text.split(token).length !== 2) {
        throw new ApiError(500, "sms-misconfigured", `Code text ${token} must appear exactly once`);
      }
      message = renderTemplate(template.text, values).split(token).join(code);
    }
    try {
      await this.client.sendSms(phone, message, template.id, this.template.from);
    } catch (error) {
      // DevSMS did not accept the text (nothing charged): keep sign-in
      // working with the pre-approved universal OTP.
      if (error instanceof ApiError && error.reason === "sms-rejected") {
        console.error("Template SMS rejected, falling back to universal OTP", template.id);
        await this.client.sendUniversalOtp(phone, code, this.serviceName);
        return;
      }
      throw error;
    }
  }

  private async findTemplate(id: string): Promise<DevSmsTemplate> {
    const cached = templateCache.get(id);
    if (cached && cached.expiresAt > this.now()) return cached.template;
    const template = (await this.client.listTemplates()).find((t) => String(t.id) === id);
    if (!template) {
      throw new ApiError(500, "sms-misconfigured", `DevSMS template ${id} not found`);
    }
    templateCache.set(id, { template, expiresAt: this.now() + TEMPLATE_CACHE_MS });
    return template;
  }
}

/** Test hook. */
export function clearTemplateCache() {
  templateCache.clear();
}
