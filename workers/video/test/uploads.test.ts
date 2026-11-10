import { describe, expect, it } from "vitest";
import { ApiError } from "../src/errors";
import {
  createUpload,
  finalizeUpload,
  LESSON_CATEGORY_IDS,
  MAX_VIDEO_BYTES,
  publicVideoUrl,
  validateUploadRequest,
  type UploadDeps,
} from "../src/uploads";
import { FakeBucket, FakeDb, mp4 } from "./helpers";

const ADMIN = "admin1";

function setup() {
  const db = new FakeDb();
  db.docs.set(`admins/${ADMIN}`, { role: "admin" });
  const bucket = new FakeBucket();
  const presigned: { key: string; type: string; size: number }[] = [];
  let ids = 0;
  const deps: UploadDeps = {
    db,
    bucket,
    publicBaseUrl: "https://pub-test.r2.dev/",
    presign: async (key, type, size) => {
      presigned.push({ key, type, size });
      return `https://r2.example/${key}?X-Amz-Signature=x`;
    },
    randomId: () => `id${++ids}`,
    now: () => new Date(Date.UTC(2026, 10, 10)),
  };
  return { db, bucket, presigned, deps };
}

const request = (overrides: Record<string, unknown> = {}) => ({
  categoryId: "fullbody",
  title: "1-dars: Isinish",
  description: "Mashg‘ulotdan oldin",
  fileName: "lesson.mp4",
  contentType: "video/mp4",
  sizeBytes: 1000,
  ...overrides,
});

async function rejects(promise: Promise<unknown>, status: number, reason: string) {
  const error = await promise.then(
    () => null,
    (e) => e,
  );
  expect(error).toBeInstanceOf(ApiError);
  expect({ status: error.status, reason: error.reason }).toEqual({ status, reason });
}

describe("validateUploadRequest", () => {
  it("enforces category, MP4 and the 2 GB limit", () => {
    expect(validateUploadRequest(request({ sizeBytes: MAX_VIDEO_BYTES })).sizeBytes).toBe(MAX_VIDEO_BYTES);
    const reason = (data: unknown) => {
      try {
        validateUploadRequest(data);
        return "ok";
      } catch (e) {
        return (e as ApiError).reason;
      }
    };
    expect(reason(request({ sizeBytes: MAX_VIDEO_BYTES + 1 }))).toBe("too-large");
    expect(reason(request({ sizeBytes: 0 }))).toBe("empty-file");
    expect(reason(request({ sizeBytes: "1000" }))).toBe("empty-file");
    expect(reason(request({ sizeBytes: 1.5 }))).toBe("empty-file");
    expect(reason(request({ fileName: "clip.mov" }))).toBe("unsupported-format");
    expect(reason(request({ contentType: "video/quicktime" }))).toBe("unsupported-format");
    expect(reason(request({ categoryId: "../admins" }))).toBe("unknown-category");
    expect(reason(request({ title: " " }))).toBe("invalid-title");
    expect(reason(null)).toBe("unknown-category");
  });

  it("builds public URLs from the configurable base", () => {
    expect(publicVideoUrl("https://video.myfit.uz/", "lessons/a b.mp4")).toBe(
      "https://video.myfit.uz/lessons/a%20b.mp4",
    );
    expect(() => publicVideoUrl("http://insecure", "k")).toThrow();
  });
});

describe("createUpload", () => {
  it("requires an admins/{uid} document", async () => {
    const { deps, presigned, db } = setup();
    await rejects(createUpload(deps, "", request()), 401, "sign-in-required");
    await rejects(createUpload(deps, "user1", request()), 403, "not-admin");
    await rejects(createUpload(deps, "../admins/admin1", request()), 403, "not-admin");
    expect(presigned).toHaveLength(0);
    expect([...db.docs.keys()].filter((p) => p.startsWith("video_uploads/"))).toHaveLength(0);
  });

  it("ignores a client-supplied uid and stores a pending session", async () => {
    const { deps, presigned, db } = setup();
    const result = await createUpload(deps, ADMIN, request({ uid: "someone-else", sizeBytes: 1234 }));
    expect(result.method).toBe("PUT");
    expect(result.headers).toEqual({ "Content-Type": "video/mp4" });
    expect(result.expiresInSeconds).toBe(900);
    expect(result.objectKey).toMatch(/^lessons\/fullbody\/2026\/11\/[0-9a-f-]{36}\.mp4$/);
    expect(presigned).toEqual([{ key: result.objectKey, type: "video/mp4", size: 1234 }]);
    const session = db.docs.get(`video_uploads/${result.uploadId}`)!;
    expect(session.uid).toBe(ADMIN);
    expect(session.status).toBe("pending");
    expect(session.objectKey).toBe(result.objectKey);
    expect((session.expiresAt as Date).getTime() - (session.createdAt as Date).getTime()).toBe(86_400_000);
  });
});

describe("finalizeUpload", () => {
  async function start(env: ReturnType<typeof setup>, bytes: Uint8Array, overrides = {}) {
    return createUpload(env.deps, ADMIN, request({ sizeBytes: bytes.length, ...overrides }));
  }

  it("verifies the object, then creates ordered lessons idempotently", async () => {
    const env = setup();
    const bytes = mp4({ seconds: 90.5 });
    const first = await start(env, bytes);
    env.bucket.put(first.objectKey, bytes);
    const done = await finalizeUpload(env.deps, ADMIN, { uploadId: first.uploadId });
    expect(done.videoUrl).toBe(`https://pub-test.r2.dev/${first.objectKey}`);
    const lesson = env.db.docs.get(`courses/fullbody/lessons/${done.lessonId}`)!;
    // Same document shape as the earlier Cloud Functions version.
    expect(lesson).toMatchObject({
      order: 1,
      title: "1-dars: Isinish",
      description: "Mashg‘ulotdan oldin",
      durationMinutes: 2,
      durationSeconds: 91,
      videoUrl: done.videoUrl,
      thumbnailUrl: null,
      storageProvider: "r2",
      objectKey: first.objectKey,
      sizeBytes: bytes.length,
      contentType: "video/mp4",
      videoCodec: "avc1",
      uploadedBy: ADMIN,
      uploadId: first.uploadId,
    });
    expect(lesson.createdAt).toBeInstanceOf(Date);
    expect(env.db.docs.get(`video_uploads/${first.uploadId}`)).toMatchObject({
      status: "completed",
      lessonId: done.lessonId,
    });

    const again = await finalizeUpload(env.deps, ADMIN, { uploadId: first.uploadId });
    expect(again.lessonId).toBe(done.lessonId);

    const second = await start(env, bytes, { title: "2-dars" });
    env.bucket.put(second.objectKey, bytes);
    const next = await finalizeUpload(env.deps, ADMIN, { uploadId: second.uploadId });
    expect(env.db.docs.get(`courses/fullbody/lessons/${next.lessonId}`)!.order).toBe(2);
    expect(env.bucket.deleted).toHaveLength(0);
  });

  it("retries the transaction on contention", async () => {
    const env = setup();
    const bytes = mp4();
    const upload = await start(env, bytes);
    env.bucket.put(upload.objectKey, bytes);
    env.db.abortCommits = 2;
    const done = await finalizeUpload(env.deps, ADMIN, { uploadId: upload.uploadId });
    expect(env.db.docs.has(`courses/fullbody/lessons/${done.lessonId}`)).toBe(true);
    expect(env.db.transactions).toBe(3);
    env.db.abortCommits = 10;
    const other = await start(env, bytes);
    env.bucket.put(other.objectKey, bytes);
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: other.uploadId }), 503, "database-unavailable");
  });

  it("rejects HEVC and removes only that upload", async () => {
    const env = setup();
    const keep = "lessons/fullbody/2026/10/existing.mp4";
    env.bucket.put(keep, mp4());
    const bytes = mp4({ codec: "hvc1" });
    const upload = await start(env, bytes);
    env.bucket.put(upload.objectKey, bytes);
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: upload.uploadId }), 400, "not-h264");
    expect(env.bucket.deleted).toEqual([upload.objectKey]);
    expect(env.bucket.objects.has(keep)).toBe(true);
    expect(env.db.docs.get(`video_uploads/${upload.uploadId}`)).toMatchObject({ status: "rejected", reason: "not-h264" });
    expect([...env.db.docs.keys()].some((p) => p.startsWith("courses/"))).toBe(false);
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: upload.uploadId }), 409, "upload-rejected");
  });

  it("rejects size/type mismatches and missing objects", async () => {
    const env = setup();
    const bytes = mp4();
    const missing = await start(env, bytes);
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: missing.uploadId }), 409, "object-missing");

    const resized = await start(env, bytes);
    env.bucket.put(resized.objectKey, new Uint8Array([...bytes, 0, 0]));
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: resized.uploadId }), 400, "size-mismatch");

    const typed = await start(env, bytes);
    env.bucket.put(typed.objectKey, bytes, "video/quicktime");
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: typed.uploadId }), 400, "unsupported-format");
  });

  it("checks admin, ownership, ids and expiry", async () => {
    const env = setup();
    const bytes = mp4();
    const upload = await start(env, bytes);
    env.bucket.put(upload.objectKey, bytes);
    await rejects(finalizeUpload(env.deps, "user1", { uploadId: upload.uploadId }), 403, "not-admin");
    env.db.docs.set("admins/admin2", {});
    await rejects(finalizeUpload(env.deps, "admin2", { uploadId: upload.uploadId }), 403, "not-owner");
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: "missing" }), 404, "upload-not-found");
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: "../admins/x" }), 400, "upload-not-found");

    const session = env.db.docs.get(`video_uploads/${upload.uploadId}`)!;
    env.db.docs.set(`video_uploads/${upload.uploadId}`, { ...session, expiresAt: new Date(0) });
    await rejects(finalizeUpload(env.deps, ADMIN, { uploadId: upload.uploadId }), 409, "upload-expired");
    expect([...env.db.docs.keys()].some((p) => p.startsWith("courses/"))).toBe(false);
  });

  it("keeps the category list in sync with the app", async () => {
    const { readFileSync } = await import("node:fs");
    const dart = readFileSync(new URL("../../../lib/data/trainer_course.dart", import.meta.url), "utf8");
    const ids = [...dart.matchAll(/id: '([^']+)'/g)].map((m) => m[1]);
    expect(ids).toEqual([...LESSON_CATEGORY_IDS]);
  });
});
