"use strict";

/**
 * Lesson video uploads to Cloudflare R2.
 *
 * Flow: `createUploadSession` (admin only) returns a presigned PUT URL, the
 * app uploads the file straight to R2, then `finalizeUpload` verifies the
 * object with HeadObject + MP4 inspection and only then writes the lesson to
 * Firestore (`courses/{categoryId}/lessons/{lessonId}`).
 *
 * Dependencies (Firestore, S3 client, presigner, clock) are injected so the
 * logic is testable without network access.
 */

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  S3Client,
  PutObjectCommand,
  HeadObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
} = require("@aws-sdk/client-s3");
const {getSignedUrl} = require("@aws-sdk/s3-request-presigner");
const {inspectMp4, Mp4Error} = require("./mp4_inspect");

const MAX_VIDEO_BYTES = 2 * 1024 * 1024 * 1024;
const VIDEO_CONTENT_TYPE = "video/mp4";
const UPLOAD_URL_TTL_SECONDS = 15 * 60;
const UPLOAD_SESSION_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_TITLE_LENGTH = 120;
const MAX_DESCRIPTION_LENGTH = 1000;

/** Must match `kLessonCategories` in `lib/data/trainer_course.dart`. */
const LESSON_CATEGORY_IDS = Object.freeze([
  "nutrition",
  "diet-cooking",
  "fullbody",
  "split-3",
  "split-4",
  "split-5",
  "superset",
  "dropset",
  "sportpit",
  "women-gym",
  "women-workouts",
  "women-nutrition",
  "cardio",
]);

/** Error with a machine-readable `details.reason` for the app. */
function fail(code, reason, message) {
  return new HttpsError(code, message, {reason});
}

function validateUploadRequest(data) {
  const input = data ?? {};
  const categoryId = String(input.categoryId ?? "");
  if (!LESSON_CATEGORY_IDS.includes(categoryId)) {
    throw fail("invalid-argument", "unknown-category", "Unknown lesson category");
  }
  const title = String(input.title ?? "").trim();
  if (title.length < 2 || title.length > MAX_TITLE_LENGTH) {
    throw fail("invalid-argument", "invalid-title", "Title must be 2-120 characters");
  }
  const description = String(input.description ?? "").trim();
  if (description.length > MAX_DESCRIPTION_LENGTH) {
    throw fail("invalid-argument", "invalid-description", "Description is too long");
  }
  const fileName = String(input.fileName ?? "");
  const contentType = String(input.contentType ?? "").toLowerCase();
  if (!/\.mp4$/i.test(fileName) || contentType !== VIDEO_CONTENT_TYPE) {
    throw fail("invalid-argument", "unsupported-format", "Only MP4 videos are accepted");
  }
  const sizeBytes = input.sizeBytes;
  if (!Number.isSafeInteger(sizeBytes) || sizeBytes <= 0) {
    throw fail("invalid-argument", "empty-file", "Video file is empty");
  }
  if (sizeBytes > MAX_VIDEO_BYTES) {
    throw fail("invalid-argument", "too-large", "Video is larger than 2 GB");
  }
  return {categoryId, title, description, sizeBytes};
}

function buildObjectKey(categoryId, uuid = crypto.randomUUID(), now = new Date()) {
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `lessons/${categoryId}/${year}/${month}/${uuid}.mp4`;
}

/** Public URL of an object; the base stays configurable (r2.dev or a custom domain). */
function publicVideoUrl(baseUrl, objectKey) {
  const base = String(baseUrl ?? "").trim().replace(/\/+$/, "");
  if (!/^https:\/\/[^/\s]+/.test(base)) {
    throw new Error("R2_PUBLIC_BASE_URL must be an https URL");
  }
  const path = objectKey.split("/").map(encodeURIComponent).join("/");
  return `${base}/${path}`;
}

function createR2Client({endpoint, accessKeyId, secretAccessKey}) {
  return new S3Client({
    region: "auto",
    endpoint,
    forcePathStyle: true,
    credentials: {accessKeyId, secretAccessKey},
    // R2 rejects the default CRC32 checksum parameters in presigned URLs.
    requestChecksumCalculation: "WHEN_REQUIRED",
    responseChecksumValidation: "WHEN_REQUIRED",
  });
}

async function requireAdmin(db, auth) {
  if (!auth?.uid) {
    throw fail("unauthenticated", "sign-in-required", "Sign in required");
  }
  const admin = await db.doc(`admins/${auth.uid}`).get();
  if (!admin.exists) {
    throw fail("permission-denied", "not-admin", "Only admins can upload videos");
  }
}

/** Callable #1: validates the request and returns a presigned PUT URL. */
async function createUploadSession({
  db,
  s3,
  bucket,
  auth,
  data,
  now = () => new Date(),
  uuid = () => crypto.randomUUID(),
  presign = getSignedUrl,
}) {
  await requireAdmin(db, auth);
  const input = validateUploadRequest(data);
  const createdAt = now();
  const objectKey = buildObjectKey(input.categoryId, uuid(), createdAt);
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: objectKey,
    ContentType: VIDEO_CONTENT_TYPE,
    ContentLength: input.sizeBytes,
  });
  const uploadUrl = await presign(s3, command, {
    expiresIn: UPLOAD_URL_TTL_SECONDS,
    signableHeaders: new Set(["content-type", "content-length"]),
  });

  const session = db.collection("video_uploads").doc();
  await session.set({
    uid: auth.uid,
    categoryId: input.categoryId,
    title: input.title,
    description: input.description,
    objectKey,
    sizeBytes: input.sizeBytes,
    contentType: VIDEO_CONTENT_TYPE,
    status: "pending",
    createdAt,
    expiresAt: new Date(createdAt.getTime() + UPLOAD_SESSION_TTL_MS),
  });

  return {
    uploadId: session.id,
    uploadUrl,
    objectKey,
    method: "PUT",
    headers: {"Content-Type": VIDEO_CONTENT_TYPE},
    expiresInSeconds: UPLOAD_URL_TTL_SECONDS,
    maxBytes: MAX_VIDEO_BYTES,
  };
}

function toDate(value) {
  if (value instanceof Date) return value;
  if (value && typeof value.toDate === "function") return value.toDate();
  return null;
}

async function headObject(s3, bucket, objectKey) {
  try {
    return await s3.send(new HeadObjectCommand({Bucket: bucket, Key: objectKey}));
  } catch (error) {
    const status = error?.$metadata?.httpStatusCode;
    if (status === 404 || error?.name === "NotFound" || error?.name === "NoSuchKey") {
      throw fail("failed-precondition", "object-missing", "Uploaded video was not found");
    }
    console.error("R2 HeadObject failed", error?.name, error?.message);
    throw fail("unavailable", "storage-unavailable", "Video storage is unavailable");
  }
}

function rangeReader(s3, bucket, objectKey) {
  return async (offset, length) => {
    const response = await s3.send(new GetObjectCommand({
      Bucket: bucket,
      Key: objectKey,
      Range: `bytes=${offset}-${offset + length - 1}`,
    }));
    return response.Body.transformToByteArray();
  };
}

/** Callable #2: verifies the R2 object, then creates the lesson document. */
async function finalizeUpload({
  db,
  s3,
  bucket,
  publicBaseUrl,
  auth,
  data,
  now = () => new Date(),
}) {
  await requireAdmin(db, auth);
  const uploadId = String(data?.uploadId ?? "");
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(uploadId)) {
    throw fail("invalid-argument", "upload-not-found", "Invalid upload id");
  }
  const sessionRef = db.doc(`video_uploads/${uploadId}`);
  const snapshot = await sessionRef.get();
  if (!snapshot.exists) {
    throw fail("not-found", "upload-not-found", "Upload session not found");
  }
  const session = snapshot.data();
  if (session.uid !== auth.uid) {
    throw fail("permission-denied", "not-owner", "Upload belongs to another user");
  }
  if (session.status === "completed") {
    return {
      lessonId: session.lessonId,
      categoryId: session.categoryId,
      videoUrl: session.videoUrl,
    };
  }
  if (session.status !== "pending") {
    throw fail("failed-precondition", "upload-rejected", "Upload was rejected");
  }
  const expiresAt = toDate(session.expiresAt);
  if (expiresAt && expiresAt.getTime() < now().getTime()) {
    throw fail("failed-precondition", "upload-expired", "Upload session expired");
  }

  const {objectKey} = session;
  const head = await headObject(s3, bucket, objectKey);
  const size = Number(head.ContentLength);
  const contentType = String(head.ContentType ?? "").toLowerCase().split(";")[0].trim();

  let reason = null;
  let media = null;
  if (size > MAX_VIDEO_BYTES) {
    reason = "too-large";
  } else if (size !== session.sizeBytes) {
    reason = "size-mismatch";
  } else if (contentType !== VIDEO_CONTENT_TYPE) {
    reason = "unsupported-format";
  } else {
    try {
      media = await inspectMp4(rangeReader(s3, bucket, objectKey), size);
    } catch (error) {
      if (!(error instanceof Mp4Error)) {
        console.error("R2 video inspection failed", error?.name, error?.message);
        throw fail("unavailable", "storage-unavailable", "Video storage is unavailable");
      }
      reason = error.reason;
    }
  }

  if (reason) {
    // Only the object created by this rejected upload session is removed.
    try {
      await s3.send(new DeleteObjectCommand({Bucket: bucket, Key: objectKey}));
    } catch (error) {
      console.error("R2 cleanup failed", objectKey, error?.message);
    }
    await sessionRef.update({status: "rejected", reason, rejectedAt: now()});
    throw fail("invalid-argument", reason, `Video rejected: ${reason}`);
  }

  const videoUrl = publicVideoUrl(publicBaseUrl, objectKey);
  const lessons = db.collection(`courses/${session.categoryId}/lessons`);
  const seconds = media.durationSeconds;
  return db.runTransaction(async (tx) => {
    const fresh = await tx.get(sessionRef);
    const current = fresh.data();
    if (current.status === "completed") {
      return {
        lessonId: current.lessonId,
        categoryId: current.categoryId,
        videoUrl: current.videoUrl,
      };
    }
    const last = await tx.get(lessons.orderBy("order", "desc").limit(1));
    const lastOrder = last.empty ? 0 : Number(last.docs[0].get("order")) || 0;
    const lessonRef = lessons.doc();
    const createdAt = now();
    tx.set(lessonRef, {
      order: lastOrder + 1,
      title: session.title,
      description: session.description,
      durationMinutes: seconds ? Math.max(1, Math.ceil(seconds / 60)) : null,
      durationSeconds: seconds ? Math.round(seconds) : null,
      videoUrl,
      thumbnailUrl: null,
      storageProvider: "r2",
      objectKey,
      sizeBytes: size,
      contentType: VIDEO_CONTENT_TYPE,
      videoCodec: media.videoCodec,
      uploadedBy: auth.uid,
      uploadId,
      createdAt,
    });
    tx.update(sessionRef, {
      status: "completed",
      lessonId: lessonRef.id,
      videoUrl,
      completedAt: createdAt,
    });
    return {lessonId: lessonRef.id, categoryId: session.categoryId, videoUrl};
  });
}

module.exports = {
  MAX_VIDEO_BYTES,
  VIDEO_CONTENT_TYPE,
  UPLOAD_URL_TTL_SECONDS,
  LESSON_CATEGORY_IDS,
  validateUploadRequest,
  buildObjectKey,
  publicVideoUrl,
  createR2Client,
  createUploadSession,
  finalizeUpload,
};
