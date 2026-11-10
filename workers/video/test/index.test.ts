import { describe, expect, it } from "vitest";
import { handle, type Env } from "../src/index";
import { unauthenticated } from "../src/errors";
import type { UploadDeps } from "../src/uploads";
import { FakeBucket, FakeDb } from "./helpers";

const env = {
  FIREBASE_PROJECT_ID: "myfit-d6275",
  R2_ENDPOINT: "https://acc.r2.cloudflarestorage.com",
  R2_BUCKET: "myfit-videos",
  R2_PUBLIC_BASE_URL: "https://pub.r2.dev",
  ALLOWED_ORIGINS: "https://myfit-d6275.web.app",
} as Env;

function harness() {
  const db = new FakeDb();
  db.docs.set("admins/admin1", {});
  const deps: UploadDeps = {
    db,
    bucket: new FakeBucket(),
    publicBaseUrl: "https://pub.r2.dev",
    presign: async (key) => `https://acc.r2.cloudflarestorage.com/myfit-videos/${key}?sig`,
  };
  const verify = async (header: string | null) => {
    if (header === "Bearer good-admin") return { uid: "admin1" };
    if (header === "Bearer good-user") return { uid: "user1" };
    throw unauthenticated("invalid-token", "bad");
  };
  return { db, deps, verify };
}

const body = {
  categoryId: "cardio",
  title: "Isinish",
  fileName: "a.mp4",
  contentType: "video/mp4",
  sizeBytes: 10,
};

function post(path: string, init: { token?: string; json?: unknown; raw?: string; origin?: string; type?: string } = {}) {
  const headers: Record<string, string> = { "content-type": init.type ?? "application/json" };
  if (init.token) headers.authorization = `Bearer ${init.token}`;
  if (init.origin) headers.origin = init.origin;
  return new Request(`https://myfit-video.example.workers.dev${path}`, {
    method: "POST",
    headers,
    body: init.raw ?? JSON.stringify(init.json ?? {}),
  });
}

async function call(request: Request) {
  const h = harness();
  const response = await handle(request, env, { verify: h.verify, deps: h.deps });
  return { response, json: (await response.json().catch(() => null)) as any, db: h.db };
}

describe("HTTP API", () => {
  it("creates an upload for an admin; uid comes from the token only", async () => {
    const { response, json, db } = await call(
      post("/createVideoUpload", { token: "good-admin", json: { ...body, uid: "user1" } }),
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(json.uploadUrl).toContain("/myfit-videos/lessons/cardio/");
    expect(db.docs.get(`video_uploads/${json.uploadId}`)!.uid).toBe("admin1");
  });

  it("returns reasons with proper status codes", async () => {
    expect((await call(post("/createVideoUpload", { json: body }))).json.error.reason).toBe("invalid-token");
    const user = await call(post("/createVideoUpload", { token: "good-user", json: body }));
    expect([user.response.status, user.json.error.reason]).toEqual([403, "not-admin"]);
    const big = await call(post("/createVideoUpload", { token: "good-admin", json: { ...body, sizeBytes: 2 ** 31 + 1 } }));
    expect([big.response.status, big.json.error.reason]).toEqual([400, "too-large"]);
    const missing = await call(post("/finalizeVideoUpload", { token: "good-admin", json: { uploadId: "nope" } }));
    expect([missing.response.status, missing.json.error.reason]).toEqual([404, "upload-not-found"]);
  });

  it("verifies the token before reading the body", async () => {
    const result = await call(post("/createVideoUpload", { raw: "not json" }));
    expect(result.response.status).toBe(401);
  });

  it("rejects bad bodies, methods and paths", async () => {
    expect((await call(post("/createVideoUpload", { token: "good-admin", raw: "{" }))).response.status).toBe(400);
    expect((await call(post("/createVideoUpload", { token: "good-admin", type: "text/plain" }))).response.status).toBe(415);
    const huge = await call(post("/createVideoUpload", { token: "good-admin", raw: JSON.stringify({ title: "x".repeat(9000) }) }));
    expect(huge.response.status).toBe(413);
    expect((await call(post("/admin"))).response.status).toBe(404);
    const get = await call(new Request("https://x.workers.dev/createVideoUpload"));
    expect(get.response.status).toBe(405);
  });

  it("allows CORS only for configured browser origins", async () => {
    const allowed = await call(post("/createVideoUpload", { token: "good-admin", json: body, origin: "https://myfit-d6275.web.app" }));
    expect(allowed.response.headers.get("access-control-allow-origin")).toBe("https://myfit-d6275.web.app");
    const other = await call(post("/createVideoUpload", { token: "good-admin", json: body, origin: "https://evil.example" }));
    expect(other.response.headers.get("access-control-allow-origin")).toBeNull();
    const h = harness();
    const preflight = await handle(
      new Request("https://x.workers.dev/finalizeVideoUpload", { method: "OPTIONS", headers: { origin: "https://myfit-d6275.web.app" } }),
      env,
      { verify: h.verify, deps: h.deps },
    );
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get("access-control-allow-headers")).toContain("authorization");
  });

  it("hides internal error details", async () => {
    const h = harness();
    h.deps.presign = async () => {
      throw new Error("secret detail");
    };
    const response = await handle(post("/createVideoUpload", { token: "good-admin", json: body }), env, h);
    expect(response.status).toBe(500);
    const text = await response.text();
    expect(text).not.toContain("secret detail");
    expect(JSON.parse(text).error.reason).toBe("internal");
  });
});
