import {
  ApiError,
  forbidden,
  invalid,
  notFound,
  precondition,
  unauthenticated,
  unavailable,
} from "./errors";
import { FirestoreAborted, type FirestoreApi, type FsFields } from "./firestore";
import { inspectMp4, Mp4Error, type Mp4Info } from "./mp4";

export const MAX_VIDEO_BYTES = 2 * 1024 * 1024 * 1024;
export const VIDEO_CONTENT_TYPE = "video/mp4";
export const UPLOAD_URL_TTL_SECONDS = 15 * 60;
export const UPLOAD_SESSION_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_TITLE_LENGTH = 120;
const MAX_DESCRIPTION_LENGTH = 1000;
const TRANSACTION_ATTEMPTS = 4;

/** Must match `kLessonCategories` in `lib/data/trainer_course.dart`. */
export const LESSON_CATEGORY_IDS = Object.freeze([
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

/** The parts of an R2 bucket binding the API needs (injectable for tests). */
export interface VideoBucket {
  head(key: string): Promise<{ size: number; contentType?: string } | null>;
  readRange(key: string, offset: number, length: number): Promise<Uint8Array>;
  delete(key: string): Promise<void>;
}

export interface UploadDeps {
  db: FirestoreApi;
  bucket: VideoBucket;
  presign: (objectKey: string, contentType: string, size: number) => Promise<string>;
  publicBaseUrl: string;
  now?: () => Date;
  randomId?: () => string;
}

export interface UploadRequest {
  categoryId: string;
  title: string;
  description: string;
  sizeBytes: number;
}

export function validateUploadRequest(data: unknown): UploadRequest {
  const input = (data && typeof data === "object" ? data : {}) as Record<
    string,
    unknown
  >;
  const categoryId = String(input.categoryId ?? "");
  if (!LESSON_CATEGORY_IDS.includes(categoryId)) {
    throw invalid("unknown-category", "Unknown lesson category");
  }
  const title = String(input.title ?? "").trim();
  if (title.length < 2 || title.length > MAX_TITLE_LENGTH) {
    throw invalid("invalid-title", "Title must be 2-120 characters");
  }
  const description = String(input.description ?? "").trim();
  if (description.length > MAX_DESCRIPTION_LENGTH) {
    throw invalid("invalid-description", "Description is too long");
  }
  const fileName = String(input.fileName ?? "");
  const contentType = String(input.contentType ?? "").toLowerCase();
  if (!/\.mp4$/i.test(fileName) || contentType !== VIDEO_CONTENT_TYPE) {
    throw invalid("unsupported-format", "Only MP4 videos are accepted");
  }
  const sizeBytes = input.sizeBytes;
  if (typeof sizeBytes !== "number" || !Number.isSafeInteger(sizeBytes) || sizeBytes <= 0) {
    throw invalid("empty-file", "Video file is empty");
  }
  if (sizeBytes > MAX_VIDEO_BYTES) {
    throw invalid("too-large", "Video is larger than 2 GB");
  }
  return { categoryId, title, description, sizeBytes };
}

export function buildObjectKey(categoryId: string, uuid: string, now: Date) {
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  return `lessons/${categoryId}/${now.getUTCFullYear()}/${month}/${uuid}.mp4`;
}

export function publicVideoUrl(baseUrl: string, objectKey: string) {
  const base = baseUrl.trim().replace(/\/+$/, "");
  if (!/^https:\/\/[^/\s]+/.test(base)) {
    throw new Error("R2_PUBLIC_BASE_URL must be an https URL");
  }
  return `${base}/${objectKey.split("/").map(encodeURIComponent).join("/")}`;
}

/** Firestore-style 20 character auto id. */
export function autoId(): string {
  const alphabet =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

export async function requireAdmin(db: FirestoreApi, uid: string | undefined) {
  if (!uid) throw unauthenticated("sign-in-required", "Sign in required");
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid) || !(await db.get(`admins/${uid}`))) {
    throw forbidden("not-admin", "Only admins can upload videos");
  }
}

const LESSON_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

function lessonRef(data: unknown) {
  const input = (data && typeof data === "object" ? data : {}) as Record<string, unknown>;
  const categoryId = String(input.categoryId ?? "");
  if (!LESSON_CATEGORY_IDS.includes(categoryId)) {
    throw invalid("unknown-category", "Unknown lesson category");
  }
  const lessonId = String(input.lessonId ?? "");
  if (!LESSON_ID_PATTERN.test(lessonId)) throw invalid("lesson-not-found", "Invalid lesson id");
  return { categoryId, lessonId, path: `courses/${categoryId}/lessons/${lessonId}` };
}

async function existingLesson(db: FirestoreApi, path: string, tx?: string) {
  const doc = await db.get(path, tx);
  if (!doc) throw notFound("lesson-not-found", "Lesson not found");
  return doc.fields;
}

/** Only objects created by the uploader under lessons/ are ever deleted. */
async function deleteLessonObject(bucket: VideoBucket, key: unknown) {
  if (typeof key !== "string" || !key.startsWith("lessons/")) return;
  try {
    await bucket.delete(key);
  } catch {
    console.error("R2 delete failed", key);
  }
}

/** POST /createVideoUpload (optional `replaceLessonId` swaps a lesson's video) */
export async function createUpload(deps: UploadDeps, uid: string, data: unknown) {
  await requireAdmin(deps.db, uid);
  const input = validateUploadRequest(data);
  const replaceRaw = (data as Record<string, unknown>).replaceLessonId;
  let replaceLessonId: string | null = null;
  if (replaceRaw !== undefined && replaceRaw !== null && replaceRaw !== "") {
    const ref = lessonRef({ categoryId: input.categoryId, lessonId: replaceRaw });
    await existingLesson(deps.db, ref.path);
    replaceLessonId = ref.lessonId;
  }
  const now = deps.now?.() ?? new Date();
  const objectKey = buildObjectKey(input.categoryId, crypto.randomUUID(), now);
  const uploadId = (deps.randomId ?? autoId)();
  const uploadUrl = await deps.presign(objectKey, VIDEO_CONTENT_TYPE, input.sizeBytes);
  await deps.db.commit([
    {
      kind: "create",
      path: `video_uploads/${uploadId}`,
      fields: {
        uid,
        categoryId: input.categoryId,
        title: input.title,
        description: input.description,
        objectKey,
        sizeBytes: input.sizeBytes,
        contentType: VIDEO_CONTENT_TYPE,
        status: "pending",
        createdAt: now,
        expiresAt: new Date(now.getTime() + UPLOAD_SESSION_TTL_MS),
        ...(replaceLessonId ? { replaceLessonId } : {}),
      },
    },
  ]);
  return {
    uploadId,
    uploadUrl,
    objectKey,
    method: "PUT",
    headers: { "Content-Type": VIDEO_CONTENT_TYPE },
    expiresInSeconds: UPLOAD_URL_TTL_SECONDS,
    maxBytes: MAX_VIDEO_BYTES,
  };
}

const completed = (session: FsFields) => ({
  lessonId: String(session.lessonId),
  categoryId: String(session.categoryId),
  videoUrl: String(session.videoUrl),
});

/** POST /finalizeVideoUpload */
export async function finalizeUpload(deps: UploadDeps, uid: string, data: unknown) {
  await requireAdmin(deps.db, uid);
  const now = () => deps.now?.() ?? new Date();
  const uploadId = String((data as Record<string, unknown> | null)?.uploadId ?? "");
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(uploadId)) {
    throw invalid("upload-not-found", "Invalid upload id");
  }
  const sessionPath = `video_uploads/${uploadId}`;
  const sessionDoc = await deps.db.get(sessionPath);
  if (!sessionDoc) throw notFound("upload-not-found", "Upload session not found");
  const session = sessionDoc.fields;
  if (session.uid !== uid) {
    throw forbidden("not-owner", "Upload belongs to another user");
  }
  if (session.status === "completed") return completed(session);
  if (session.status !== "pending") {
    throw precondition("upload-rejected", "Upload was rejected");
  }
  const expiresAt = session.expiresAt;
  if (expiresAt instanceof Date && expiresAt.getTime() < now().getTime()) {
    throw precondition("upload-expired", "Upload session expired");
  }

  const objectKey = String(session.objectKey);
  const categoryId = String(session.categoryId);
  if (!LESSON_CATEGORY_IDS.includes(categoryId) || !objectKey.startsWith(`lessons/${categoryId}/`)) {
    throw new ApiError(500, "internal", "Corrupt upload session");
  }

  let head;
  try {
    head = await deps.bucket.head(objectKey);
  } catch {
    throw unavailable("storage-unavailable", "Video storage is unavailable");
  }
  if (!head) throw precondition("object-missing", "Uploaded video was not found");
  const contentType = (head.contentType ?? "").toLowerCase().split(";")[0]!.trim();

  let reason: string | null = null;
  let media: Mp4Info | null = null;
  if (head.size > MAX_VIDEO_BYTES) {
    reason = "too-large";
  } else if (head.size !== session.sizeBytes) {
    reason = "size-mismatch";
  } else if (contentType !== VIDEO_CONTENT_TYPE) {
    reason = "unsupported-format";
  } else {
    try {
      media = await inspectMp4(
        (offset, length) => deps.bucket.readRange(objectKey, offset, length),
        head.size,
      );
    } catch (error) {
      if (!(error instanceof Mp4Error)) {
        throw unavailable("storage-unavailable", "Video storage is unavailable");
      }
      reason = error.reason;
    }
  }

  if (reason || !media) {
    // Only the object created for this rejected session is removed.
    try {
      await deps.bucket.delete(objectKey);
    } catch {
      console.error("R2 cleanup failed", objectKey);
    }
    await deps.db.commit([
      {
        kind: "update",
        path: sessionPath,
        fields: { status: "rejected", reason: reason ?? "unsupported-format", rejectedAt: now() },
      },
    ]);
    throw invalid(reason ?? "unsupported-format", `Video rejected: ${reason}`);
  }

  const videoUrl = publicVideoUrl(deps.publicBaseUrl, objectKey);
  const seconds = media.durationSeconds;
  for (let attempt = 1; ; attempt++) {
    const tx = await deps.db.beginTransaction();
    try {
      const fresh = await deps.db.get(sessionPath, tx);
      if (fresh?.fields.status === "completed") {
        await deps.db.rollback(tx);
        return completed(fresh.fields);
      }
      if (fresh?.fields.status !== "pending") {
        await deps.db.rollback(tx);
        throw precondition("upload-rejected", "Upload was rejected");
      }
      const videoFields = {
        durationMinutes: seconds ? Math.max(1, Math.ceil(seconds / 60)) : null,
        durationSeconds: seconds ? Math.round(seconds) : null,
        videoUrl,
        storageProvider: "r2",
        objectKey,
        sizeBytes: head.size,
        contentType: VIDEO_CONTENT_TYPE,
        videoCodec: media.videoCodec,
        uploadId,
      };
      const replaceLessonId = typeof session.replaceLessonId === "string" ? session.replaceLessonId : null;
      if (replaceLessonId) {
        const lessonPath = `courses/${categoryId}/lessons/${replaceLessonId}`;
        const lesson = await deps.db.get(lessonPath, tx);
        if (!lesson) {
          await deps.db.rollback(tx);
          await deleteLessonObject(deps.bucket, objectKey);
          await deps.db.commit([
            { kind: "update", path: sessionPath, fields: { status: "rejected", reason: "lesson-not-found", rejectedAt: now() } },
          ]);
          throw notFound("lesson-not-found", "Lesson was deleted meanwhile");
        }
        const updatedAt = now();
        await deps.db.commit(
          [
            {
              kind: "update",
              path: lessonPath,
              fields: {
                ...videoFields,
                title: String(session.title),
                description: String(session.description ?? ""),
                updatedAt,
                updatedBy: uid,
              },
            },
            {
              kind: "update",
              path: sessionPath,
              fields: { status: "completed", lessonId: replaceLessonId, videoUrl, completedAt: updatedAt },
            },
          ],
          tx,
        );
        // The old video is removed only after the lesson points to the new one.
        if (lesson.fields.objectKey !== objectKey) {
          await deleteLessonObject(deps.bucket, lesson.fields.objectKey);
        }
        return { lessonId: replaceLessonId, categoryId, videoUrl };
      }
      const lastOrder = await deps.db.lastLessonOrder(categoryId, tx);
      const lessonId = (deps.randomId ?? autoId)();
      const createdAt = now();
      await deps.db.commit(
        [
          {
            kind: "create",
            path: `courses/${categoryId}/lessons/${lessonId}`,
            fields: {
              order: lastOrder + 1,
              title: String(session.title),
              description: String(session.description ?? ""),
              durationMinutes: seconds ? Math.max(1, Math.ceil(seconds / 60)) : null,
              durationSeconds: seconds ? Math.round(seconds) : null,
              videoUrl,
              thumbnailUrl: null,
              storageProvider: "r2",
              objectKey,
              sizeBytes: head.size,
              contentType: VIDEO_CONTENT_TYPE,
              videoCodec: media.videoCodec,
              uploadedBy: uid,
              uploadId,
              createdAt,
            },
          },
          {
            kind: "update",
            path: sessionPath,
            fields: { status: "completed", lessonId, videoUrl, completedAt: createdAt },
          },
        ],
        tx,
      );
      return { lessonId, categoryId, videoUrl };
    } catch (error) {
      if (error instanceof FirestoreAborted && attempt < TRANSACTION_ATTEMPTS) continue;
      if (!(error instanceof ApiError)) await deps.db.rollback(tx);
      if (error instanceof FirestoreAborted) {
        throw unavailable("database-unavailable", "Firestore is busy, retry");
      }
      throw error;
    }
  }
}

/** POST /updateLesson: title and description of an existing lesson. */
export async function updateLesson(deps: UploadDeps, uid: string, data: unknown) {
  await requireAdmin(deps.db, uid);
  const ref = lessonRef(data);
  const input = data as Record<string, unknown>;
  const title = String(input.title ?? "").trim();
  if (title.length < 2 || title.length > MAX_TITLE_LENGTH) {
    throw invalid("invalid-title", "Title must be 2-120 characters");
  }
  const description = String(input.description ?? "").trim();
  if (description.length > MAX_DESCRIPTION_LENGTH) {
    throw invalid("invalid-description", "Description is too long");
  }
  await existingLesson(deps.db, ref.path);
  await deps.db.commit([
    {
      kind: "update",
      path: ref.path,
      fields: { title, description, updatedAt: deps.now?.() ?? new Date(), updatedBy: uid },
    },
  ]);
  return { lessonId: ref.lessonId, categoryId: ref.categoryId };
}

/**
 * POST /deleteLesson: removes the lesson, renumbers the following lessons
 * (1, 2, 3 … without gaps) and deletes its video from R2.
 */
export async function deleteLesson(deps: UploadDeps, uid: string, data: unknown) {
  await requireAdmin(deps.db, uid);
  const ref = lessonRef(data);
  for (let attempt = 1; ; attempt++) {
    const tx = await deps.db.beginTransaction();
    try {
      const lesson = await deps.db.get(ref.path, tx);
      if (!lesson) {
        await deps.db.rollback(tx);
        throw notFound("lesson-not-found", "Lesson not found");
      }
      const others = (await deps.db.listLessons(ref.categoryId, tx)).filter((l) => l.id !== ref.lessonId);
      const renumber = others
        .map((l, index) => ({ ...l, next: index + 1 }))
        .filter((l) => l.order !== l.next)
        .map((l) => ({
          kind: "update" as const,
          path: `courses/${ref.categoryId}/lessons/${l.id}`,
          fields: { order: l.next },
        }));
      await deps.db.commit([{ kind: "delete", path: ref.path }, ...renumber], tx);
      await deleteLessonObject(deps.bucket, lesson.fields.objectKey);
      return { deleted: true, lessonId: ref.lessonId, categoryId: ref.categoryId };
    } catch (error) {
      if (error instanceof FirestoreAborted && attempt < TRANSACTION_ATTEMPTS) continue;
      if (!(error instanceof ApiError)) await deps.db.rollback(tx);
      if (error instanceof FirestoreAborted) {
        throw unavailable("database-unavailable", "Firestore is busy, retry");
      }
      throw error;
    }
  }
}
