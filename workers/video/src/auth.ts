import {
  createLocalJWKSet,
  decodeProtectedHeader,
  errors as joseErrors,
  jwtVerify,
  type JSONWebKeySet,
} from "jose";
import { unauthenticated, unavailable } from "./errors";

/** Google's public keys for Firebase Auth ID tokens (JWK format). */
export const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const CLOCK_TOLERANCE_SECONDS = 60;
const DEFAULT_JWKS_TTL_MS = 60 * 60 * 1000;
/** Unknown `kid`s trigger a refetch at most this often (key rotation). */
const MIN_REFETCH_INTERVAL_MS = 30 * 1000;

export interface VerifiedUser {
  uid: string;
  authTime: number;
}

export type Fetcher = typeof fetch;

interface CachedKeys {
  jwks: JSONWebKeySet;
  keySet: ReturnType<typeof createLocalJWKSet>;
  expiresAt: number;
  fetchedAt: number;
}

/**
 * Verifies Firebase ID tokens against Google's rotating JWKS.
 *
 * Keys are cached per isolate for `Cache-Control: max-age`. A token whose
 * `kid` is not in the cache forces one refetch (rate-limited), so rotation
 * works without trusting any unsigned data.
 */
export class FirebaseTokenVerifier {
  private cache: CachedKeys | null = null;
  private pending: Promise<CachedKeys> | null = null;

  constructor(
    private readonly projectId: string,
    private readonly fetcher: Fetcher = (input, init) => fetch(input, init),
    private readonly now: () => number = () => Date.now(),
  ) {
    if (!/^[a-z0-9-]{4,40}$/.test(projectId)) {
      throw new Error("Invalid FIREBASE_PROJECT_ID");
    }
  }

  async verify(authorization: string | null): Promise<VerifiedUser> {
    const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(
      authorization ?? "",
    );
    if (!match) {
      throw unauthenticated("sign-in-required", "Missing bearer token");
    }
    const token = match[1]!;

    let kid: string | undefined;
    try {
      const header = decodeProtectedHeader(token);
      if (header.alg !== "RS256" || typeof header.kid !== "string") {
        throw new Error("unexpected header");
      }
      kid = header.kid;
    } catch {
      throw unauthenticated("invalid-token", "Malformed token header");
    }

    let keys = await this.keys(false);
    if (!keys.jwks.keys.some((key) => key.kid === kid)) {
      keys = await this.keys(true);
    }

    const nowSeconds = Math.floor(this.now() / 1000);
    let payload;
    try {
      ({ payload } = await jwtVerify(token, keys.keySet, {
        algorithms: ["RS256"],
        issuer: `https://securetoken.google.com/${this.projectId}`,
        audience: this.projectId,
        clockTolerance: CLOCK_TOLERANCE_SECONDS,
        currentDate: new Date(this.now()),
        requiredClaims: ["exp", "iat", "sub", "auth_time"],
      }));
    } catch (error) {
      if (error instanceof joseErrors.JWTExpired) {
        throw unauthenticated("token-expired", "ID token expired");
      }
      throw unauthenticated("invalid-token", "ID token verification failed");
    }

    const { sub, iat, auth_time: authTime } = payload as {
      sub?: unknown;
      iat?: unknown;
      auth_time?: unknown;
    };
    if (typeof sub !== "string" || sub.length === 0 || sub.length > 128) {
      throw unauthenticated("invalid-token", "Invalid subject");
    }
    if (typeof iat !== "number" || iat > nowSeconds + CLOCK_TOLERANCE_SECONDS) {
      throw unauthenticated("invalid-token", "Token issued in the future");
    }
    if (
      typeof authTime !== "number" ||
      authTime > nowSeconds + CLOCK_TOLERANCE_SECONDS
    ) {
      throw unauthenticated("invalid-token", "Invalid auth_time");
    }
    return { uid: sub, authTime };
  }

  private async keys(forceRefresh: boolean): Promise<CachedKeys> {
    const now = this.now();
    const cached = this.cache;
    if (cached) {
      const fresh = cached.expiresAt > now;
      const throttled = now - cached.fetchedAt < MIN_REFETCH_INTERVAL_MS;
      if (fresh && (!forceRefresh || throttled)) return cached;
    }
    this.pending ??= this.download().finally(() => {
      this.pending = null;
    });
    try {
      this.cache = await this.pending;
    } catch (error) {
      // Keep serving the previous keys if Google is briefly unreachable.
      if (cached) return cached;
      throw error;
    }
    return this.cache;
  }

  private async download(): Promise<CachedKeys> {
    let response: Response;
    try {
      response = await this.fetcher(FIREBASE_JWKS_URL, {
        headers: { accept: "application/json" },
      });
    } catch {
      throw unavailable("auth-unavailable", "Cannot reach Google key server");
    }
    if (!response.ok) {
      throw unavailable("auth-unavailable", `JWKS HTTP ${response.status}`);
    }
    const jwks = (await response.json()) as JSONWebKeySet;
    if (!Array.isArray(jwks?.keys) || jwks.keys.length === 0) {
      throw unavailable("auth-unavailable", "Empty JWKS");
    }
    const maxAge = /max-age=(\d+)/.exec(
      response.headers.get("cache-control") ?? "",
    );
    const ttl = maxAge ? Number(maxAge[1]) * 1000 : DEFAULT_JWKS_TTL_MS;
    const now = this.now();
    return {
      jwks,
      keySet: createLocalJWKSet(jwks),
      expiresAt: now + Math.min(ttl, 24 * DEFAULT_JWKS_TTL_MS),
      fetchedAt: now,
    };
  }
}
