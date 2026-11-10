const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret, defineString} = require("firebase-functions/params");
// `firebase-functions/v2` also loads the Realtime Database provider, which
// needs the optional `@firebase/app` peer and crashes on load.
const {setGlobalOptions} = require("firebase-functions/v2/options");
const {initializeApp, getApps} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {asList, number, normalizeFood} = require("./fatsecret_helpers");
const r2Video = require("./r2_video");

const fatSecretClientId = defineSecret("FATSECRET_CLIENT_ID");
const fatSecretClientSecret = defineSecret("FATSECRET_CLIENT_SECRET");

setGlobalOptions({region: "europe-west1", maxInstances: 10});

const tokens = new Map();

async function accessToken(scope = "basic") {
  const cached = tokens.get(scope);
  if (cached && Date.now() < cached.expiresAt - 60_000) return cached.token;

  const credentials = Buffer.from(
    `${fatSecretClientId.value()}:${fatSecretClientSecret.value()}`,
  ).toString("base64");
  const response = await fetch("https://oauth.fatsecret.com/connect/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({grant_type: "client_credentials", scope}),
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) {
    throw new Error(`FatSecret OAuth failed (${response.status})`);
  }
  const json = await response.json();
  if (!json.access_token) throw new Error("OAuth response has no token");
  tokens.set(scope, {token: json.access_token, expiresAt: Date.now() + number(json.expires_in) * 1000});
  return json.access_token;
}

async function fatSecretGet(path, parameters, scope = "basic") {
  const token = await accessToken(scope);
  const url = new URL(`https://platform.fatsecret.com/rest/${path}`);
  for (const [key, value] of Object.entries(parameters)) {
    if (value != null && value !== "") url.searchParams.set(key, String(value));
  }
  url.searchParams.set("format", "json");
  const response = await fetch(url, {
    headers: {Authorization: `Bearer ${token}`},
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`FatSecret request failed (${response.status})`);
  const json = await response.json();
  if (json.error) throw new Error(`FatSecret API error ${json.error.code}`);
  return json;
}

async function detailsFor(food) {
  const foodId = String(food.food_id ?? "");
  if (!foodId) return null;
  const json = await fatSecretGet("food/v4", {food_id: foodId});
  return normalizeFood(json.food ?? json);
}

exports.fatSecretSearch = onCall(
  {
    secrets: [fatSecretClientId, fatSecretClientSecret],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
    const query = String(request.data?.query ?? "").trim().slice(0, 100);
    if (query.length < 2) return {foods: []};
    const page = Number(request.data?.page ?? 0);
    if (!Number.isInteger(page) || page < 0 || page > 1000) {
      throw new HttpsError("invalid-argument", "Invalid page");
    }

    try {
      const search = await fatSecretGet("foods/search/v1", {
        search_expression: query,
        max_results: 20,
        page_number: page,
      });
      const matches = asList(search?.foods?.food);
      const settled = await Promise.allSettled(matches.map(detailsFor));
      const seen = new Set();
      const foods = settled
        .filter((result) => result.status === "fulfilled" && result.value)
        .map((result) => result.value)
        .filter((food) => {
          const key = String(food.id);
          if (seen.has(key)) return false;
          seen.add(key);
          return true;
        });
      if (matches.length > 0 && foods.length === 0) throw new Error("No food details available");
      return {foods, nextPage: (page + 1) * 20 < number(search?.foods?.total_results) ? page + 1 : null};
    } catch (error) {
      console.error("FatSecret search failed", error?.message ?? error);
      throw new HttpsError("unavailable", "FatSecret is temporarily unavailable");
    }
  },
);

exports.fatSecretBarcode = onCall(
  {secrets: [fatSecretClientId, fatSecretClientSecret], timeoutSeconds: 25, memory: "256MiB"},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required");
    const raw = String(request.data?.barcode ?? "").trim();
    // UPC-E requires explicit expansion; do not confuse it with EAN-8.
    if (!/^\d{12,13}$/.test(raw) && !/^\d{8}$/.test(raw)) {
      throw new HttpsError("invalid-argument", "EAN-8, UPC-A or EAN-13 required");
    }
    try {
      const json = await fatSecretGet("food/barcode/find-by-id/v2", {barcode: raw.padStart(13, "0")}, "barcode");
      return {food: normalizeFood(json.food ?? json)};
    } catch (error) {
      console.error("FatSecret barcode failed", error?.message ?? error);
      throw new HttpsError("unavailable", "Barcode lookup unavailable");
    }
  },
);

// ---------------------------------------------------------------------------
// Lesson videos on Cloudflare R2 (see docs/R2_VIDEO.md).
// Credentials live only in Firebase Functions Secrets.
// ---------------------------------------------------------------------------

const r2AccessKeyId = defineSecret("R2_ACCESS_KEY_ID");
const r2SecretAccessKey = defineSecret("R2_SECRET_ACCESS_KEY");
const r2Endpoint = defineString("R2_ENDPOINT", {
  default: "https://7d6c72f2d7ccf971e52c251086f2bfa1.r2.cloudflarestorage.com",
});
const r2Bucket = defineString("R2_BUCKET", {default: "myfit-videos"});
// Switch to a custom domain later without code changes.
const r2PublicBaseUrl = defineString("R2_PUBLIC_BASE_URL", {
  default: "https://pub-32dc4a48be774882aaf3dd1d07697a5b.r2.dev",
});

let r2Client = null;
let r2ClientKey = null;

function r2() {
  const config = {
    endpoint: r2Endpoint.value(),
    accessKeyId: r2AccessKeyId.value(),
    secretAccessKey: r2SecretAccessKey.value(),
  };
  const key = `${config.endpoint}|${config.accessKeyId}`;
  if (!r2Client || r2ClientKey !== key) {
    r2Client = r2Video.createR2Client(config);
    r2ClientKey = key;
  }
  return r2Client;
}

function firestore() {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}

async function videoCall(label, run) {
  try {
    return await run();
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error(`${label} failed`, error?.name, error?.message);
    throw new HttpsError("internal", "Video upload failed", {reason: "internal"});
  }
}

exports.createVideoUploadUrl = onCall(
  {secrets: [r2AccessKeyId, r2SecretAccessKey], timeoutSeconds: 30, memory: "256MiB"},
  (request) => videoCall("createVideoUploadUrl", () => r2Video.createUploadSession({
    db: firestore(),
    s3: r2(),
    bucket: r2Bucket.value(),
    auth: request.auth,
    data: request.data,
  })),
);

exports.finalizeVideoUpload = onCall(
  {secrets: [r2AccessKeyId, r2SecretAccessKey], timeoutSeconds: 120, memory: "512MiB"},
  (request) => videoCall("finalizeVideoUpload", () => r2Video.finalizeUpload({
    db: firestore(),
    s3: r2(),
    bucket: r2Bucket.value(),
    publicBaseUrl: r2PublicBaseUrl.value(),
    auth: request.auth,
    data: request.data,
  })),
);
