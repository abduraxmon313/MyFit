"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {inspectMp4, Mp4Error} = require("../mp4_inspect");
const r2 = require("../r2_video");

// ---------------------------------------------------------------- MP4 builder

function u32(value) {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32BE(value);
  return buffer;
}

function box(type, ...payloads) {
  const body = Buffer.concat(payloads);
  return Buffer.concat([u32(8 + body.length), Buffer.from(type, "latin1"), body]);
}

function largeBox(type, payload) {
  const size = Buffer.alloc(8);
  size.writeBigUInt64BE(BigInt(16 + payload.length));
  return Buffer.concat([u32(1), Buffer.from(type, "latin1"), size, payload]);
}

const fullBox = () => Buffer.from([0, 0, 0, 0]);

function trak(handler, codec) {
  return box(
    "trak",
    box("tkhd", fullBox(), Buffer.alloc(80)),
    box(
      "mdia",
      box("mdhd", fullBox(), Buffer.alloc(20)),
      box("hdlr", fullBox(), u32(0), Buffer.from(handler, "latin1"), Buffer.alloc(13)),
      box("minf", box("stbl", box("stsd", fullBox(), u32(1), box(codec, Buffer.alloc(78))))),
    ),
  );
}

function mp4({brand = "isom", codec = "avc1", moovFirst = false, seconds = 90.5, largeMdat = false} = {}) {
  const ftyp = box("ftyp", Buffer.from(brand, "latin1"), u32(0), Buffer.from("isommp41"));
  const mvhd = box("mvhd", fullBox(), u32(0), u32(0), u32(1000), u32(Math.round(seconds * 1000)), Buffer.alloc(80));
  const moov = box("moov", mvhd, trak("soun", "mp4a"), trak("vide", codec));
  const media = Buffer.alloc(2048, 7);
  const mdat = largeMdat ? largeBox("mdat", media) : box("mdat", media);
  return moovFirst ? Buffer.concat([ftyp, moov, mdat]) : Buffer.concat([ftyp, mdat, moov]);
}

const readerFor = (bytes) => async (offset, length) =>
  new Uint8Array(bytes.subarray(offset, offset + length));

// ------------------------------------------------------------ Firestore fake

class FakeDb {
  constructor() {
    this.docs = new Map();
    this.counter = 0;
  }
  doc(path) {
    return new FakeDoc(this, path);
  }
  collection(path) {
    return new FakeQuery(this, path);
  }
  async runTransaction(run) {
    return run({
      get: (target) => target.get(),
      set: (ref, data) => ref.set(data),
      update: (ref, data) => ref.update(data),
    });
  }
}

class FakeDoc {
  constructor(db, path) {
    this.db = db;
    this.path = path;
    this.id = path.split("/").pop();
  }
  async get() {
    const data = this.db.docs.get(this.path);
    return {
      id: this.id,
      exists: data !== undefined,
      data: () => (data ? {...data} : undefined),
      get: (field) => data?.[field],
    };
  }
  async set(data) {
    this.db.docs.set(this.path, {...data});
  }
  async update(data) {
    if (!this.db.docs.has(this.path)) throw new Error(`No document ${this.path}`);
    this.db.docs.set(this.path, {...this.db.docs.get(this.path), ...data});
  }
}

class FakeQuery {
  constructor(db, path, order = null, max = Infinity) {
    this.db = db;
    this.path = path;
    this.order = order;
    this.max = max;
  }
  doc() {
    this.db.counter += 1;
    return new FakeDoc(this.db, `${this.path}/auto${this.db.counter}`);
  }
  orderBy(field, direction = "asc") {
    return new FakeQuery(this.db, this.path, {field, direction}, this.max);
  }
  limit(max) {
    return new FakeQuery(this.db, this.path, this.order, max);
  }
  async get() {
    let docs = [...this.db.docs.entries()]
      .filter(([path]) => path.startsWith(`${this.path}/`) && !path.slice(this.path.length + 1).includes("/"))
      .map(([path, data]) => ({id: path.split("/").pop(), data: () => ({...data}), get: (field) => data[field]}));
    if (this.order) {
      const {field, direction} = this.order;
      docs.sort((a, b) => (a.get(field) - b.get(field)) * (direction === "desc" ? -1 : 1));
    }
    docs = docs.slice(0, this.max);
    return {empty: docs.length === 0, docs};
  }
}

// ------------------------------------------------------------------- S3 fake

class FakeS3 {
  constructor() {
    this.objects = new Map();
    this.deleted = [];
  }
  put(key, bytes, contentType = "video/mp4") {
    this.objects.set(key, {bytes, contentType});
  }
  async send(command) {
    const {Key} = command.input;
    const name = command.constructor.name;
    if (name === "DeleteObjectCommand") {
      this.deleted.push(Key);
      this.objects.delete(Key);
      return {};
    }
    const object = this.objects.get(Key);
    if (!object) {
      throw Object.assign(new Error("Not Found"), {name: "NotFound", $metadata: {httpStatusCode: 404}});
    }
    if (name === "HeadObjectCommand") {
      return {ContentLength: object.bytes.length, ContentType: object.contentType};
    }
    if (name === "GetObjectCommand") {
      const [, start, end] = /bytes=(\d+)-(\d+)/.exec(command.input.Range);
      const slice = object.bytes.subarray(Number(start), Number(end) + 1);
      return {Body: {transformToByteArray: async () => new Uint8Array(slice)}};
    }
    throw new Error(`Unexpected command ${name}`);
  }
}

// ------------------------------------------------------------------- helpers

const ADMIN = {uid: "admin1"};
const PUBLIC_BASE = "https://pub-test.r2.dev/";

function setup() {
  const db = new FakeDb();
  db.docs.set("admins/admin1", {role: "admin"});
  const s3 = new FakeS3();
  const presigned = [];
  const presign = async (client, command, options) => {
    presigned.push({command, options});
    return `https://r2.example/${command.input.Key}?X-Amz-Signature=test`;
  };
  return {db, s3, presigned, presign};
}

function request(overrides = {}) {
  return {
    categoryId: "fullbody",
    title: "1-dars: Isinish",
    description: "Mashg‘ulotdan oldin",
    fileName: "lesson.mp4",
    contentType: "video/mp4",
    sizeBytes: 1000,
    ...overrides,
  };
}

async function startUpload(env, bytes, overrides = {}) {
  const result = await r2.createUploadSession({
    db: env.db,
    s3: env.s3,
    bucket: "myfit-videos",
    auth: ADMIN,
    data: request({sizeBytes: bytes.length, ...overrides}),
    presign: env.presign,
  });
  return result;
}

function finalize(env, uploadId, auth = ADMIN) {
  return r2.finalizeUpload({
    db: env.db,
    s3: env.s3,
    bucket: "myfit-videos",
    publicBaseUrl: PUBLIC_BASE,
    auth,
    data: {uploadId},
  });
}

async function rejectsWith(promise, code, reason) {
  await assert.rejects(promise, (error) => {
    assert.equal(error.code, code);
    assert.equal(error.details?.reason, reason);
    return true;
  });
}

// --------------------------------------------------------------------- tests

test("inspectMp4 reads H.264 with moov at the end or the start", async () => {
  for (const moovFirst of [false, true]) {
    const bytes = mp4({moovFirst});
    const info = await inspectMp4(readerFor(bytes), bytes.length);
    assert.equal(info.videoCodec, "avc1");
    assert.equal(info.majorBrand, "isom");
    assert.equal(info.durationSeconds, 90.5);
  }
});

test("inspectMp4 handles 64-bit box sizes and avc3", async () => {
  const bytes = mp4({largeMdat: true, codec: "avc3"});
  const info = await inspectMp4(readerFor(bytes), bytes.length);
  assert.equal(info.videoCodec, "avc3");
});

test("inspectMp4 rejects HEVC, QuickTime and non-MP4 files", async () => {
  const hevc = mp4({codec: "hvc1"});
  await assert.rejects(inspectMp4(readerFor(hevc), hevc.length), (e) => e instanceof Mp4Error && e.reason === "not-h264");
  const mov = mp4({brand: "qt  "});
  await assert.rejects(inspectMp4(readerFor(mov), mov.length), (e) => e.reason === "unsupported-format");
  const text = Buffer.from("this is not a video at all");
  await assert.rejects(inspectMp4(readerFor(text), text.length), (e) => e.reason === "unsupported-format");
});

test("validateUploadRequest enforces category, MP4 and the 2 GB limit", () => {
  assert.equal(r2.validateUploadRequest(request({sizeBytes: r2.MAX_VIDEO_BYTES})).sizeBytes, r2.MAX_VIDEO_BYTES);
  assert.throws(() => r2.validateUploadRequest(request({sizeBytes: r2.MAX_VIDEO_BYTES + 1})), (e) => e.details.reason === "too-large");
  assert.throws(() => r2.validateUploadRequest(request({sizeBytes: 0})), (e) => e.details.reason === "empty-file");
  assert.throws(() => r2.validateUploadRequest(request({fileName: "clip.mov"})), (e) => e.details.reason === "unsupported-format");
  assert.throws(() => r2.validateUploadRequest(request({contentType: "video/quicktime"})), (e) => e.details.reason === "unsupported-format");
  assert.throws(() => r2.validateUploadRequest(request({categoryId: "unknown"})), (e) => e.details.reason === "unknown-category");
  assert.throws(() => r2.validateUploadRequest(request({title: " "})), (e) => e.details.reason === "invalid-title");
});

test("object keys and public URLs", () => {
  const key = r2.buildObjectKey("split-3", "abc-123", new Date(Date.UTC(2026, 10, 7)));
  assert.equal(key, "lessons/split-3/2026/11/abc-123.mp4");
  assert.equal(r2.publicVideoUrl(PUBLIC_BASE, key), "https://pub-test.r2.dev/lessons/split-3/2026/11/abc-123.mp4");
  assert.equal(r2.publicVideoUrl("https://video.myfit.uz", "a b/c.mp4"), "https://video.myfit.uz/a%20b/c.mp4");
  assert.throws(() => r2.publicVideoUrl("http://insecure.example", key));
});

test("only admins get an upload URL", async () => {
  const env = setup();
  const base = {db: env.db, s3: env.s3, bucket: "b", data: request(), presign: env.presign};
  await rejectsWith(r2.createUploadSession({...base, auth: null}), "unauthenticated", "sign-in-required");
  await rejectsWith(r2.createUploadSession({...base, auth: {uid: "user1"}}), "permission-denied", "not-admin");
  assert.equal(env.presigned.length, 0);
});

test("upload URL signs content type and length and stores a pending session", async () => {
  const env = setup();
  const result = await startUpload(env, Buffer.alloc(1234));
  assert.equal(result.method, "PUT");
  assert.equal(result.headers["Content-Type"], "video/mp4");
  assert.match(result.uploadUrl, /^https:\/\/r2\.example\/lessons\/fullbody\//);
  const [{command, options}] = env.presigned;
  assert.equal(command.input.Bucket, "myfit-videos");
  assert.equal(command.input.ContentLength, 1234);
  assert.equal(command.input.ContentType, "video/mp4");
  assert.ok(options.signableHeaders.has("content-length"));
  assert.ok(options.expiresIn <= 15 * 60);
  const session = env.db.docs.get(`video_uploads/${result.uploadId}`);
  assert.equal(session.status, "pending");
  assert.equal(session.uid, "admin1");
  assert.equal(session.objectKey, result.objectKey);
});

test("finalize verifies the object, creates ordered lessons and is idempotent", async () => {
  const env = setup();
  const bytes = mp4({seconds: 90.5});
  const first = await startUpload(env, bytes);
  env.s3.put(first.objectKey, bytes);
  const done = await finalize(env, first.uploadId);
  assert.equal(done.videoUrl, `https://pub-test.r2.dev/${first.objectKey}`);
  const lesson = env.db.docs.get(`courses/fullbody/lessons/${done.lessonId}`);
  assert.equal(lesson.order, 1);
  assert.equal(lesson.title, "1-dars: Isinish");
  assert.equal(lesson.durationMinutes, 2);
  assert.equal(lesson.durationSeconds, 91);
  assert.equal(lesson.storageProvider, "r2");
  assert.equal(lesson.videoCodec, "avc1");
  assert.equal(lesson.sizeBytes, bytes.length);

  const again = await finalize(env, first.uploadId);
  assert.equal(again.lessonId, done.lessonId);

  const second = await startUpload(env, bytes, {title: "2-dars"});
  env.s3.put(second.objectKey, bytes);
  const next = await finalize(env, second.uploadId);
  assert.equal(env.db.docs.get(`courses/fullbody/lessons/${next.lessonId}`).order, 2);
  assert.equal(env.s3.deleted.length, 0);
});

test("finalize rejects HEVC and removes only that upload", async () => {
  const env = setup();
  const bytes = mp4({codec: "hvc1"});
  const upload = await startUpload(env, bytes);
  env.s3.put(upload.objectKey, bytes);
  await rejectsWith(finalize(env, upload.uploadId), "invalid-argument", "not-h264");
  assert.deepEqual(env.s3.deleted, [upload.objectKey]);
  assert.equal(env.db.docs.get(`video_uploads/${upload.uploadId}`).status, "rejected");
  assert.equal([...env.db.docs.keys()].some((path) => path.startsWith("courses/")), false);
  await rejectsWith(finalize(env, upload.uploadId), "failed-precondition", "upload-rejected");
});

test("finalize rejects size or type mismatches and missing objects", async () => {
  const env = setup();
  const bytes = mp4();
  const missing = await startUpload(env, bytes);
  await rejectsWith(finalize(env, missing.uploadId), "failed-precondition", "object-missing");

  const resized = await startUpload(env, bytes);
  env.s3.put(resized.objectKey, Buffer.concat([bytes, Buffer.alloc(10)]));
  await rejectsWith(finalize(env, resized.uploadId), "invalid-argument", "size-mismatch");

  const typed = await startUpload(env, bytes);
  env.s3.put(typed.objectKey, bytes, "video/quicktime");
  await rejectsWith(finalize(env, typed.uploadId), "invalid-argument", "unsupported-format");
});

test("finalize checks admin, ownership and expiry", async () => {
  const env = setup();
  const bytes = mp4();
  const upload = await startUpload(env, bytes);
  env.s3.put(upload.objectKey, bytes);
  await rejectsWith(finalize(env, upload.uploadId, {uid: "user1"}), "permission-denied", "not-admin");
  env.db.docs.set("admins/admin2", {});
  await rejectsWith(finalize(env, upload.uploadId, {uid: "admin2"}), "permission-denied", "not-owner");
  await rejectsWith(finalize(env, "missing"), "not-found", "upload-not-found");

  const session = env.db.docs.get(`video_uploads/${upload.uploadId}`);
  env.db.docs.set(`video_uploads/${upload.uploadId}`, {...session, expiresAt: new Date(0)});
  await rejectsWith(finalize(env, upload.uploadId), "failed-precondition", "upload-expired");
});
