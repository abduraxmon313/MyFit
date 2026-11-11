// Smoke-tests the deployed video Worker. Never prints tokens or keys.
// Usage: WORKER_URL=https://… [FIREBASE_SERVICE_ACCOUNT=…] [FIREBASE_WEB_API_KEY=…] node scripts/smoke.mjs
//
// Without credentials: checks routing, method/path handling and that
// requests without a valid token are rejected.
// With the service account: mints a short-lived Firebase user "ci-smoke-…",
// calls /createVideoUpload with its real ID token and expects 403 not-admin.
// That proves Google JWKS verification and the Firestore admins/{uid} read
// both work in production. The temporary user is deleted afterwards.
import { importPKCS8, SignJWT } from "jose";

const base = (process.env.WORKER_URL ?? "").replace(/\/+$/, "");
if (!/^(https:\/\/[^/]+|http:\/\/127\.0\.0\.1:\d+)$/.test(base)) throw new Error("WORKER_URL must be an https origin");

let failures = 0;
function check(name, ok, detail) {
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${ok ? "" : `  (${detail})`}`);
  if (!ok) failures += 1;
}

async function call(path, { method = "POST", token, body } = {}) {
  const headers = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(`${base}${path}`, {
    method,
    headers,
    body: method === "POST" ? JSON.stringify(body ?? {}) : undefined,
  });
  const json = await response.json().catch(() => null);
  return { status: response.status, reason: json?.error?.reason, json };
}

const validBody = {
  categoryId: "cardio",
  title: "CI smoke test",
  fileName: "smoke.mp4",
  contentType: "video/mp4",
  sizeBytes: 1024,
};

// 1. Public behaviour.
{
  const r = await call("/createVideoUpload", { body: validBody });
  check("createVideoUpload without token -> 401", r.status === 401 && r.reason === "sign-in-required", `${r.status} ${r.reason}`);
}
{
  const r = await call("/finalizeVideoUpload", { body: { uploadId: "x" } });
  check("finalizeVideoUpload without token -> 401", r.status === 401, `${r.status} ${r.reason}`);
}
{
  const fake = "eyJhbGciOiJSUzI1NiIsImtpZCI6Im5vcGUifQ.eyJzdWIiOiJhdHRhY2tlciJ9.c2lnbmF0dXJl";
  const r = await call("/createVideoUpload", { token: fake, body: validBody });
  check("forged token -> 401 invalid-token", r.status === 401 && r.reason === "invalid-token", `${r.status} ${r.reason}`);
}
{
  const r = await call("/createVideoUpload", { method: "GET" });
  check("GET -> 405", r.status === 405, `${r.status}`);
}
{
  // Invalid number: validated before any SMS is sent (costs nothing).
  const r = await call("/auth/sms/send", { body: { phone: "123" } });
  check("SMS send with invalid phone -> 400 invalid-phone", r.status === 400 && r.reason === "invalid-phone", `${r.status} ${r.reason}`);
}
{
  const r = await call("/admin");
  check("unknown path -> 404", r.status === 404, `${r.status}`);
}

// 2. Real Firebase token (optional).
const rawAccount = process.env.FIREBASE_SERVICE_ACCOUNT;
const apiKey = process.env.FIREBASE_WEB_API_KEY;
if (rawAccount && apiKey) {
  const account = JSON.parse(rawAccount);
  const uid = `ci-smoke-${Date.now()}`;
  const identity = "https://identitytoolkit.googleapis.com/v1";
  let idToken = null;
  try {
    const now = Math.floor(Date.now() / 1000);
    const customToken = await new SignJWT({ uid })
      .setProtectedHeader({ alg: "RS256", typ: "JWT" })
      .setIssuer(account.client_email)
      .setSubject(account.client_email)
      .setAudience("https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit")
      .setIssuedAt(now)
      .setExpirationTime(now + 300)
      .sign(await importPKCS8(account.private_key, "RS256"));
    const signIn = await fetch(`${identity}/accounts:signInWithCustomToken?key=${apiKey}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    });
    const signInJson = await signIn.json().catch(() => ({}));
    idToken = signInJson.idToken ?? null;
    if (idToken && process.env.GITHUB_ACTIONS) console.log(`::add-mask::${idToken}`);
    check("Firebase issued a test ID token", Boolean(idToken), signInJson.error?.message ?? `HTTP ${signIn.status}`);

    if (idToken) {
      const r = await call("/createVideoUpload", { token: idToken, body: validBody });
      check(
        "real ID token + non-admin -> 403 not-admin (JWKS + Firestore OK)",
        r.status === 403 && r.reason === "not-admin",
        `${r.status} ${r.reason}`,
      );
      const spoof = await call("/createVideoUpload", { token: idToken, body: { ...validBody, uid: "someone-else" } });
      check("client-supplied uid is ignored -> 403", spoof.status === 403, `${spoof.status} ${spoof.reason}`);
    }
  } finally {
    if (idToken) {
      const del = await fetch(`${identity}/accounts:delete?key=${apiKey}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ idToken }),
      });
      check("temporary test user deleted", del.ok, `HTTP ${del.status}`);
    }
  }
} else {
  console.log("SKIP  real-token test (no service account / API key)");
}

if (failures) {
  console.error(`${failures} smoke check(s) failed`);
  process.exit(1);
}
console.log("All smoke checks passed");
