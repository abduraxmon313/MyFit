import { describe, expect, it } from "vitest";
import { handle, type Env } from "../src/index";
import { unauthenticated } from "../src/errors";
import {
  MAX_PROFILE_IMAGE_BYTES,
  readLimited,
  sniffImageType,
  type ProfileBucket,
  type ProfileDeps,
} from "../src/profile";
import type { UploadDeps } from "../src/uploads";
import { FakeBucket, FakeDb } from "./helpers";

const env = {
  FIREBASE_PROJECT_ID: "myfit-d6275",
  R2_PUBLIC_BASE_URL: "https://pub.r2.dev",
  ALLOWED_ORIGINS: "",
} as Env;

const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 1, 2, 3]);
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 16, 74, 70, 73, 70]);
const WEBP = new TextEncoder().encode("RIFF\u0010\u0000\u0000\u0000WEBPVP8 ");

class FakeProfileBucket implements ProfileBucket {
  objects = new Map<string, { bytes: Uint8Array; contentType: string }>();
  async put(key: string, bytes: Uint8Array, contentType: string) {
    this.objects.set(key, { bytes, contentType });
  }
  async list(prefix: string, limit: number) {
    return [...this.objects.keys()].filter((k) => k.startsWith(prefix)).slice(0, limit);
  }
  async delete(keys: string[]) {
    for (const key of keys) this.objects.delete(key);
  }
}

function harness() {
  const bucket = new FakeProfileBucket();
  let n = 0;
  const profile: ProfileDeps = {
    bucket,
    publicBaseUrl: "https://pub.r2.dev",
    now: () => new Date(1_700_000_000_000 + ++n),
    randomSuffix: () => "abc123",
  };
  // Video deps exist but must never be touched by profile routes.
  const db = new FakeDb();
  const video: UploadDeps = {
    db,
    bucket: new FakeBucket(),
    publicBaseUrl: "https://pub.r2.dev",
    presign: async () => {
      throw new Error("video presign must not run");
    },
  };
  const verify = async (header: string | null) => {
    if (header === "Bearer alice") return { uid: "alice" };
    if (header === "Bearer bob") return { uid: "bob" };
    throw unauthenticated("sign-in-required", "Missing bearer token");
  };
  const run = (request: Request) => handle(request, env, { verify, deps: video, profile });
  return { bucket, run, db };
}

function upload(
  bytes: BodyInit | null,
  { token, type = "image/png", query = "" }: { token?: string; type?: string; query?: string } = {},
) {
  const headers: Record<string, string> = { "content-type": type };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request(`https://w.example/profile/upload${query}`, { method: "POST", headers, body: bytes });
}

function remove(token?: string, json: unknown = {}) {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request("https://w.example/profile/delete", { method: "POST", headers, body: JSON.stringify(json) });
}

async function result(response: Response) {
  const json = (await response.json()) as any;
  return { status: response.status, reason: json.error?.reason, json };
}

describe("profile photos", () => {
  it("rejects unauthenticated upload and delete with 401", async () => {
    const h = harness();
    expect(await result(await h.run(upload(PNG)))).toMatchObject({ status: 401, reason: "sign-in-required" });
    expect(await result(await h.run(remove()))).toMatchObject({ status: 401 });
    expect(h.bucket.objects.size).toBe(0);
  });

  it("rejects writing or deleting another UID's photo with 403", async () => {
    const h = harness();
    await h.run(upload(PNG, { token: "bob" }));
    const up = await result(await h.run(upload(PNG, { token: "alice", query: "?uid=bob" })));
    expect(up).toMatchObject({ status: 403, reason: "not-owner" });
    const del = await result(await h.run(remove("alice", { uid: "bob" })));
    expect(del).toMatchObject({ status: 403, reason: "not-owner" });
    expect([...h.bucket.objects.keys()]).toEqual(["profile-images/bob/1700000000001-abc123.png"]);
  });

  it("accepts JPEG, PNG and WebP and returns the public URL", async () => {
    for (const [bytes, type, ext] of [
      [JPEG, "image/jpeg", "jpg"],
      [PNG, "image/png", "png"],
      [WEBP, "image/webp", "webp"],
    ] as const) {
      const h = harness();
      const r = await result(await h.run(upload(bytes, { token: "alice", type, query: "?uid=alice" })));
      expect(r.status).toBe(200);
      expect(r.json.objectKey).toBe(`profile-images/alice/1700000000001-abc123.${ext}`);
      expect(r.json.url).toBe(`https://pub.r2.dev/profile-images/alice/1700000000001-abc123.${ext}`);
      expect(r.json.contentType).toBe(type);
      expect(h.bucket.objects.get(r.json.objectKey)?.contentType).toBe(type);
    }
  });

  it("rejects wrong formats and spoofed content", async () => {
    const h = harness();
    const gif = new TextEncoder().encode("GIF89a....");
    expect(await result(await h.run(upload(gif, { token: "alice", type: "image/gif" })))).toMatchObject({
      status: 415,
      reason: "unsupported-format",
    });
    // Declared PNG, actually JPEG / text.
    expect((await result(await h.run(upload(JPEG, { token: "alice", type: "image/png" })))).status).toBe(415);
    const text = new TextEncoder().encode("<svg onload=alert(1)>");
    expect((await result(await h.run(upload(text, { token: "alice", type: "image/png" })))).status).toBe(415);
    expect(await result(await h.run(upload(new Uint8Array(0), { token: "alice" })))).toMatchObject({
      status: 400,
      reason: "empty-file",
    });
    expect(h.bucket.objects.size).toBe(0);
  });

  it("enforces the 5 MB limit (header and streamed body)", async () => {
    const h = harness();
    const exact = new Uint8Array(MAX_PROFILE_IMAGE_BYTES);
    exact.set(PNG);
    expect((await result(await h.run(upload(exact, { token: "alice" })))).status).toBe(200);
    const big = new Uint8Array(MAX_PROFILE_IMAGE_BYTES + 1);
    big.set(PNG);
    expect(await result(await h.run(upload(big, { token: "alice" })))).toMatchObject({ status: 413, reason: "too-large" });
    // No Content-Length (chunked): the reader stops at the limit.
    const chunks = new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(PNG);
        for (let i = 0; i < 6; i++) controller.enqueue(new Uint8Array(1024 * 1024));
        controller.close();
      },
    });
    await expect(readLimited(chunks, MAX_PROFILE_IMAGE_BYTES)).rejects.toMatchObject({ status: 413 });
  });

  it("replaces the old photo and only touches the user's own prefix", async () => {
    const h = harness();
    await h.run(upload(PNG, { token: "bob" }));
    const first = await result(await h.run(upload(PNG, { token: "alice" })));
    const second = await result(await h.run(upload(JPEG, { token: "alice", type: "image/jpeg" })));
    expect(first.json.objectKey).not.toBe(second.json.objectKey);
    expect([...h.bucket.objects.keys()].sort()).toEqual([
      "profile-images/alice/1700000000003-abc123.jpg",
      "profile-images/bob/1700000000001-abc123.png",
    ]);
    const del = await result(await h.run(remove("alice")));
    expect(del.json).toEqual({ deleted: 1 });
    expect([...h.bucket.objects.keys()]).toEqual(["profile-images/bob/1700000000001-abc123.png"]);
  });

  it("does not require admin and never touches video data", async () => {
    const h = harness();
    expect((await result(await h.run(upload(PNG, { token: "alice" })))).status).toBe(200);
    expect(h.db.docs.size).toBe(0);
  });

  it("detects image types by magic bytes", () => {
    expect(sniffImageType(JPEG)).toBe("image/jpeg");
    expect(sniffImageType(PNG)).toBe("image/png");
    expect(sniffImageType(WEBP)).toBe("image/webp");
    expect(sniffImageType(new Uint8Array([1, 2, 3]))).toBeNull();
  });
});
