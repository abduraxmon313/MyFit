// Validates Worker secrets from the environment and writes them to a JSON
// file for `wrangler deploy --secrets-file`. Never prints secret values.
// Usage: node scripts/prepare-secrets.mjs <output-file>
import { writeFileSync } from "node:fs";

const out = process.argv[2];
if (!out) throw new Error("output file required");

const problems = [];
const value = (name) => {
  const v = process.env[name];
  if (!v || !v.trim()) problems.push(`${name} is missing`);
  return v?.trim() ?? "";
};

const accessKeyId = value("R2_ACCESS_KEY_ID");
const secretAccessKey = value("R2_SECRET_ACCESS_KEY");
const rawAccount = value("FIREBASE_SERVICE_ACCOUNT");

if (accessKeyId && !/^[A-Za-z0-9]{20,64}$/.test(accessKeyId)) {
  problems.push("R2_ACCESS_KEY_ID has an unexpected format");
}
if (secretAccessKey && secretAccessKey.length < 32) {
  problems.push("R2_SECRET_ACCESS_KEY looks too short");
}

let account = null;
if (rawAccount) {
  try {
    account = JSON.parse(rawAccount);
  } catch {
    problems.push("FIREBASE_SERVICE_ACCOUNT is not valid JSON (paste the whole file)");
  }
}
if (account) {
  if (account.type !== "service_account") problems.push("FIREBASE_SERVICE_ACCOUNT.type is not service_account");
  if (account.project_id !== "myfit-d6275") problems.push("FIREBASE_SERVICE_ACCOUNT belongs to another project");
  if (typeof account.client_email !== "string" || !account.client_email.endsWith(".iam.gserviceaccount.com")) {
    problems.push("FIREBASE_SERVICE_ACCOUNT.client_email is invalid");
  }
  if (typeof account.private_key !== "string" || !account.private_key.includes("BEGIN PRIVATE KEY")) {
    problems.push("FIREBASE_SERVICE_ACCOUNT.private_key is invalid");
  }
}

if (problems.length) {
  for (const p of problems) console.error(`::error::${p}`);
  process.exit(1);
}

// Optional: DevSMS token for SMS sign-in (/auth/sms/*).
const devSms = process.env.DEVSMS_API_TOKEN?.trim() ?? "";
if (!devSms) console.log("DEVSMS_API_TOKEN not set: SMS sign-in stays disabled");

// Optional: Calorie API key for barcode/food lookup (/food/*).
const calorieKey = process.env.CALORIE_API_KEY?.trim() ?? "";
if (!calorieKey) console.log("CALORIE_API_KEY not set: Calorie API lookup stays disabled");

writeFileSync(
  out,
  JSON.stringify({
    R2_ACCESS_KEY_ID: accessKeyId,
    R2_SECRET_ACCESS_KEY: secretAccessKey,
    // Compact single-line JSON (well under the 5 KB secret limit).
    FIREBASE_SERVICE_ACCOUNT: JSON.stringify(account),
    ...(devSms ? { DEVSMS_API_TOKEN: devSms } : {}),
    ...(calorieKey ? { CALORIE_API_KEY: calorieKey } : {}),
  }),
  { mode: 0o600 },
);
console.log(`Secrets validated (service account: ${account.client_email.split("@")[0]}@…)`);
