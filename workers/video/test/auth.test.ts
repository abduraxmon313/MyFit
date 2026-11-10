import { describe, expect, it } from "vitest";
import { base64url, exportJWK, generateKeyPair, SignJWT, type JWK } from "jose";
import { FIREBASE_JWKS_URL, FirebaseTokenVerifier } from "../src/auth";
import { ApiError } from "../src/errors";

const PROJECT = "myfit-d6275";
const NOW = Date.UTC(2026, 10, 10, 12, 0, 0);
const nowSeconds = Math.floor(NOW / 1000);

async function keyPair(kid: string) {
  const { publicKey, privateKey } = await generateKeyPair("RS256", { extractable: true });
  const jwk = { ...(await exportJWK(publicKey)), kid, alg: "RS256", use: "sig" } as JWK;
  return { jwk, privateKey };
}

const primary = await keyPair("key-1");
const rotated = await keyPair("key-2");
const attacker = await keyPair("key-1"); // same kid, different key

function jwksServer(initial: JWK[]) {
  const state = { keys: initial, calls: 0, maxAge: 3600 };
  const fetcher = (async (url: RequestInfo | URL) => {
    expect(String(url)).toBe(FIREBASE_JWKS_URL);
    state.calls += 1;
    return new Response(JSON.stringify({ keys: state.keys }), {
      headers: { "cache-control": `public, max-age=${state.maxAge}` },
    });
  }) as typeof fetch;
  return { state, fetcher };
}

interface TokenOptions {
  key?: CryptoKey;
  kid?: string;
  claims?: Record<string, unknown>;
  omit?: string[];
}

async function token({ key = primary.privateKey, kid = "key-1", claims = {}, omit = [] }: TokenOptions = {}) {
  const payload: Record<string, unknown> = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    sub: "admin-uid",
    iat: nowSeconds - 60,
    exp: nowSeconds + 3000,
    auth_time: nowSeconds - 600,
    user_id: "admin-uid",
    ...claims,
  };
  for (const name of omit) delete payload[name];
  return new SignJWT(payload).setProtectedHeader({ alg: "RS256", kid }).sign(key);
}

async function reason(verifier: FirebaseTokenVerifier, header: string | null) {
  try {
    await verifier.verify(header);
    return "ok";
  } catch (error) {
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).status).toBe(401);
    return (error as ApiError).reason;
  }
}

describe("FirebaseTokenVerifier", () => {
  it("accepts a valid token and returns the uid from `sub`", async () => {
    const { fetcher } = jwksServer([primary.jwk]);
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => NOW);
    const user = await verifier.verify(`Bearer ${await token()}`);
    expect(user.uid).toBe("admin-uid");
  });

  it("caches Google keys for max-age", async () => {
    const { state, fetcher } = jwksServer([primary.jwk]);
    let now = NOW;
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => now);
    const valid = `Bearer ${await token()}`;
    await verifier.verify(valid);
    await verifier.verify(valid);
    expect(state.calls).toBe(1);
    now += 3601 * 1000;
    await reason(verifier, valid); // expired by now, but keys were refetched
    expect(state.calls).toBe(2);
  });

  it("refetches on an unknown kid (key rotation)", async () => {
    const { state, fetcher } = jwksServer([primary.jwk]);
    let now = NOW;
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => now);
    await verifier.verify(`Bearer ${await token()}`);
    state.keys = [primary.jwk, rotated.jwk];
    now += 31 * 1000;
    const user = await verifier.verify(
      `Bearer ${await token({ key: rotated.privateKey, kid: "key-2" })}`,
    );
    expect(user.uid).toBe("admin-uid");
    expect(state.calls).toBe(2);
  });

  it("does not hammer Google for unknown kids", async () => {
    const { state, fetcher } = jwksServer([primary.jwk]);
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => NOW);
    await verifier.verify(`Bearer ${await token()}`);
    const forged = `Bearer ${await token({ key: rotated.privateKey, kid: "nope" })}`;
    for (let i = 0; i < 5; i++) expect(await reason(verifier, forged)).toBe("invalid-token");
    expect(state.calls).toBe(1);
  });

  it("rejects bad signatures, issuer, audience and expiry", async () => {
    const { fetcher } = jwksServer([primary.jwk]);
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => NOW);
    const check = async (options: TokenOptions) => reason(verifier, `Bearer ${await token(options)}`);

    expect(await check({ key: attacker.privateKey })).toBe("invalid-token");
    expect(await check({ claims: { iss: "https://securetoken.google.com/other" } })).toBe("invalid-token");
    expect(await check({ claims: { iss: "https://accounts.google.com" } })).toBe("invalid-token");
    expect(await check({ claims: { aud: "other-project" } })).toBe("invalid-token");
    expect(await check({ claims: { exp: nowSeconds - 120 } })).toBe("token-expired");
    expect(await check({ claims: { iat: nowSeconds + 600 } })).toBe("invalid-token");
    expect(await check({ claims: { auth_time: nowSeconds + 600 } })).toBe("invalid-token");
    expect(await check({ claims: { sub: "" } })).toBe("invalid-token");
    expect(await check({ claims: { sub: "x".repeat(129) } })).toBe("invalid-token");
    expect(await check({ omit: ["auth_time"] })).toBe("invalid-token");
    expect(await check({ omit: ["exp"] })).toBe("invalid-token");
  });

  it("rejects unsigned, HS256 and tampered tokens", async () => {
    const { fetcher } = jwksServer([primary.jwk]);
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => NOW);
    const enc = (value: unknown) => base64url.encode(JSON.stringify(value));
    const claims = {
      iss: `https://securetoken.google.com/${PROJECT}`,
      aud: PROJECT,
      sub: "attacker",
      iat: nowSeconds,
      exp: nowSeconds + 3000,
      auth_time: nowSeconds,
    };
    const none = `${enc({ alg: "none", kid: "key-1" })}.${enc(claims)}.`;
    expect(await reason(verifier, `Bearer ${none}`)).toBe("sign-in-required");
    const noneSig = `${enc({ alg: "none", kid: "key-1" })}.${enc(claims)}.AAAA`;
    expect(await reason(verifier, `Bearer ${noneSig}`)).toBe("invalid-token");

    const hs = await new SignJWT(claims)
      .setProtectedHeader({ alg: "HS256", kid: "key-1" })
      .sign(new TextEncoder().encode("secret"));
    expect(await reason(verifier, `Bearer ${hs}`)).toBe("invalid-token");

    // A valid signature over a different payload (uid swap) must fail.
    const [header, , signature] = (await token()).split(".");
    const swapped = `${header}.${enc({ ...claims, sub: "victim" })}.${signature}`;
    expect(await reason(verifier, `Bearer ${swapped}`)).toBe("invalid-token");
  });

  it("requires a Bearer header", async () => {
    const { fetcher } = jwksServer([primary.jwk]);
    const verifier = new FirebaseTokenVerifier(PROJECT, fetcher, () => NOW);
    expect(await reason(verifier, null)).toBe("sign-in-required");
    expect(await reason(verifier, `Basic ${await token()}`)).toBe("sign-in-required");
    expect(await reason(verifier, "Bearer abc")).toBe("sign-in-required");
  });

  it("reports Google key outages as unavailable", async () => {
    const verifier = new FirebaseTokenVerifier(
      PROJECT,
      (async () => new Response("down", { status: 503 })) as typeof fetch,
      () => NOW,
    );
    await expect(verifier.verify(`Bearer ${await token()}`)).rejects.toMatchObject({
      status: 503,
      reason: "auth-unavailable",
    });
  });
});
