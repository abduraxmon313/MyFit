import { ApiError, invalid, unavailable } from "./errors";

/**
 * DevSMS (https://devsms.uz/docs/api) client: read approved templates
 * (`templates:read`) and send template SMS (`sms:send`).
 *
 * Read-only towards templates: this code never creates, edits or deletes
 * templates in the DevSMS cabinet.
 */

export const DEVSMS_BASE = "https://devsms.uz/api/v1";
const MAX_TEMPLATE_PAGES = 20;

export interface DevSmsTemplate {
  id: number | string;
  name: string;
  text: string;
  status: string | null;
  /** Placeholder tokens exactly as written in [text], e.g. `{code}`, `%d`. */
  placeholders: string[];
}

/** `{code}`, `{{code}}`, `%d` / `%s` / `%w`, `#code#` (unique, in order). */
export function templatePlaceholders(text: string): string[] {
  const found = text.match(/\{\{\s*[\w.-]+\s*\}\}|\{[\w.-]+\}|%[a-z]\b|#[\w.-]+#/gi) ?? [];
  return [...new Set(found)];
}

/**
 * Replaces every placeholder token with its value. Throws when any token is
 * left without a value, so a half-filled SMS is never sent.
 */
export function renderTemplate(text: string, values: Record<string, string>): string {
  let out = text;
  for (const token of templatePlaceholders(text)) {
    const value = values[token];
    if (value === undefined) {
      throw new ApiError(500, "sms-misconfigured", `No value for template placeholder ${token}`);
    }
    out = out.split(token).join(value);
  }
  return out;
}

const str = (value: unknown) => (typeof value === "string" ? value : value == null ? "" : String(value));

/** Accepts the field names DevSMS may use for a template record. */
export function normalizeTemplate(raw: Record<string, unknown>): DevSmsTemplate | null {
  const id = raw.id ?? raw.template_id;
  if (typeof id !== "number" && typeof id !== "string") return null;
  const text = str(raw.text ?? raw.template ?? raw.content ?? raw.message ?? raw.body ?? raw.original_text);
  const name = str(raw.name ?? raw.title ?? raw.label) || `#${id}`;
  const status = raw.status ?? raw.state ?? null;
  return { id, name, text, status: status == null ? null : str(status), placeholders: templatePlaceholders(text) };
}

function listOf(json: any): unknown[] {
  const data = json?.data ?? json;
  if (Array.isArray(data)) return data;
  for (const key of ["items", "templates", "data", "results"]) {
    if (Array.isArray(data?.[key])) return data[key];
  }
  if (Array.isArray(json?.templates)) return json.templates;
  return [];
}

function nextCursor(json: any): string | null {
  const value =
    json?.meta?.next_cursor ?? json?.meta?.nextCursor ?? json?.next_cursor ?? json?.data?.next_cursor ?? null;
  return typeof value === "string" && value ? value : null;
}

function providerError(status: number, json: any, operation: string): ApiError {
  const code = str(json?.error_code);
  console.error(`DevSMS ${operation} failed`, status, code);
  if (status === 401) return new ApiError(502, "sms-misconfigured", "DevSMS token is invalid or expired");
  if (status === 403) {
    return new ApiError(
      502,
      "sms-misconfigured",
      code === "forbidden" ? `DevSMS key lacks the permission for ${operation}` : "DevSMS refused the request",
    );
  }
  if (status === 402 || code === "insufficient_balance") {
    return new ApiError(503, "sms-unavailable", "SMS balance is empty");
  }
  if (status === 422 || status === 400) {
    return invalid("invalid-phone", "SMS provider rejected the phone number or text");
  }
  return unavailable("sms-unavailable", `DevSMS ${operation} failed`);
}

export class DevSmsClient {
  constructor(
    private readonly apiToken: string,
    private readonly fetcher: typeof fetch = (input, init) => fetch(input, init),
  ) {}

  private headers(extra: Record<string, string> = {}) {
    if (!this.apiToken) throw new ApiError(500, "sms-misconfigured", "DEVSMS_API_TOKEN is not set");
    return { authorization: `Bearer ${this.apiToken}`, accept: "application/json", ...extra };
  }

  /** GET /templates (all pages). Requires `templates:read`. */
  async listTemplates(): Promise<DevSmsTemplate[]> {
    const templates: DevSmsTemplate[] = [];
    let cursor: string | null = null;
    for (let page = 0; page < MAX_TEMPLATE_PAGES; page++) {
      const url = new URL(`${DEVSMS_BASE}/templates`);
      if (cursor) url.searchParams.set("cursor", cursor);
      const headers = this.headers();
      let response: Response;
      try {
        response = await this.fetcher(url.toString(), { headers });
      } catch {
        throw unavailable("sms-unavailable", "DevSMS unreachable");
      }
      const json = await response.json().catch(() => ({}));
      if (!response.ok || (json as any)?.success === false) {
        throw providerError(response.status, json, "templates:read");
      }
      for (const raw of listOf(json)) {
        if (raw && typeof raw === "object") {
          const template = normalizeTemplate(raw as Record<string, unknown>);
          if (template) templates.push(template);
        }
      }
      cursor = nextCursor(json);
      if (!cursor) break;
    }
    return templates;
  }

  /**
   * POST /sms. Sends [message] (must match an approved template) with its
   * `template_id`. Retries once with the same Idempotency-Key, so a retry
   * never sends or charges a second SMS.
   */
  async sendSms(phone: string, message: string, templateId?: number | string, from?: string): Promise<void> {
    const body = JSON.stringify({
      phone,
      message,
      ...(templateId !== undefined && templateId !== "" ? { template_id: Number(templateId) || templateId } : {}),
      ...(from ? { from } : {}),
    });
    await this.post("/sms", body, "sms:send");
  }

  /** POST /sms with a universal OTP (DevSMS pre-approved login template). */
  async sendUniversalOtp(phone: string, code: string, serviceName: string): Promise<void> {
    const body = JSON.stringify({ phone, otp: { template_type: 4, service_name: serviceName, code } });
    await this.post("/sms", body, "sms:send");
  }

  private async post(path: string, body: string, operation: string) {
    const headers = this.headers({ "content-type": "application/json", "idempotency-key": crypto.randomUUID() });
    for (let attempt = 0; attempt < 2; attempt++) {
      let response: Response;
      try {
        response = await this.fetcher(`${DEVSMS_BASE}${path}`, { method: "POST", headers, body });
      } catch {
        if (attempt === 0) continue;
        throw unavailable("sms-unavailable", "DevSMS unreachable");
      }
      const json = await response.json().catch(() => ({}));
      if (response.ok && (json as any)?.success !== false) return;
      if ((response.status === 502 || response.status === 409) && attempt === 0) continue;
      throw providerError(response.status, json, operation);
    }
    throw unavailable("sms-unavailable", "DevSMS failed");
  }
}
