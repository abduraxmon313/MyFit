import { importPKCS8, SignJWT } from "jose";
import { ApiError, forbidden, unavailable } from "./errors";
import type { Fetcher } from "./auth";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const IDENTITY_SCOPE = "https://www.googleapis.com/auth/identitytoolkit";
const CUSTOM_TOKEN_AUDIENCE =
  "https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit";

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

/** Firebase Auth user lookup/creation and custom tokens (Spark plan). */
export interface IdentityApi {
  /** UID of the Firebase user with [phone] (E.164), creating one if needed. */
  uidForPhone(phone: string): Promise<string>;
  customToken(uid: string): Promise<string>;
}

/**
 * Identity Toolkit admin REST API with the service account.
 * The account needs the "Firebase Authentication Admin" role. Custom tokens
 * are signed locally with the service-account key.
 */
export class IdentityRest implements IdentityApi {
  private token: { value: string; expiresAt: number } | null = null;
  private keyPromise: ReturnType<typeof importPKCS8> | null = null;
  private readonly base: string;

  constructor(
    projectId: string,
    private readonly account: ServiceAccount,
    private readonly fetcher: Fetcher = (input, init) => fetch(input, init),
    private readonly now: () => number = () => Date.now(),
  ) {
    this.base = `https://identitytoolkit.googleapis.com/v1/projects/${projectId}`;
  }

  private key() {
    this.keyPromise ??= importPKCS8(this.account.private_key, "RS256");
    return this.keyPromise;
  }

  private async accessToken(): Promise<string> {
    const now = this.now();
    if (this.token && this.token.expiresAt > now) return this.token.value;
    const iat = Math.floor(now / 1000);
    const assertion = await new SignJWT({ scope: IDENTITY_SCOPE })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuer(this.account.client_email)
      .setSubject(this.account.client_email)
      .setAudience(TOKEN_URL)
      .setIssuedAt(iat)
      .setExpirationTime(iat + 3600)
      .sign(await this.key());
    const response = await this.send(TOKEN_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    if (!response.ok) throw unavailable("auth-unavailable", "Google OAuth failed");
    const json = (await response.json()) as { access_token?: string; expires_in?: number };
    if (!json.access_token) throw unavailable("auth-unavailable", "No access token");
    this.token = {
      value: json.access_token,
      expiresAt: now + Math.max(60, (json.expires_in ?? 3600) - 300) * 1000,
    };
    return this.token.value;
  }

  private async send(url: string, init: RequestInit) {
    try {
      return await this.fetcher(url, init);
    } catch {
      throw unavailable("auth-unavailable", "Cannot reach Google APIs");
    }
  }

  private async post(path: string, body: unknown) {
    const response = await this.send(`${this.base}${path}`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${await this.accessToken()}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });
    const json = (await response.json().catch(() => ({}))) as Record<string, any>;
    return { response, json };
  }

  private async lookup(phone: string) {
    const { response, json } = await this.post("/accounts:lookup", { phoneNumber: [phone] });
    if (!response.ok) {
      console.error("accounts:lookup failed", response.status, json?.error?.message);
      const message = String(json?.error?.message ?? "");
      if (response.status === 403 || message.includes("INSUFFICIENT_PERMISSION") || message.includes("PERMISSION_DENIED")) {
        throw new ApiError(500, "auth-misconfigured", "Service account lacks Firebase Authentication Admin");
      }
      throw unavailable("auth-unavailable", "User lookup failed");
    }
    const user = (json.users as Record<string, unknown>[] | undefined)?.[0];
    if (!user) return null;
    if (user.disabled === true) throw forbidden("user-disabled", "Account is disabled");
    return String(user.localId);
  }

  async uidForPhone(phone: string): Promise<string> {
    const existing = await this.lookup(phone);
    if (existing) return existing;
    const { response, json } = await this.post("/accounts", { phoneNumber: phone });
    if (response.ok && typeof json.localId === "string") return json.localId;
    // A parallel request created the same phone user first.
    if (String(json?.error?.message ?? "").includes("PHONE_NUMBER_EXISTS")) {
      const again = await this.lookup(phone);
      if (again) return again;
    }
    console.error("accounts create failed", response.status, json?.error?.message);
    throw unavailable("auth-unavailable", "User creation failed");
  }

  async customToken(uid: string): Promise<string> {
    const iat = Math.floor(this.now() / 1000);
    return new SignJWT({ uid })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuer(this.account.client_email)
      .setSubject(this.account.client_email)
      .setAudience(CUSTOM_TOKEN_AUDIENCE)
      .setIssuedAt(iat)
      .setExpirationTime(iat + 3600)
      .sign(await this.key());
  }
}
