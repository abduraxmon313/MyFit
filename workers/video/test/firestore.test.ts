import { describe, expect, it } from "vitest";
import { exportPKCS8, generateKeyPair, jwtVerify } from "jose";
import {
  decodeFields,
  encodeFields,
  FirestoreAborted,
  FirestoreRest,
  parseServiceAccount,
} from "../src/firestore";

const { publicKey, privateKey } = await generateKeyPair("RS256", { extractable: true });
const account = {
  client_email: "video-worker@myfit-d6275.iam.gserviceaccount.com",
  private_key: await exportPKCS8(privateKey),
};

interface Call {
  url: string;
  init: RequestInit;
}

function google(handler: (call: Call) => Response | undefined) {
  const calls: Call[] = [];
  const fetcher = (async (url: RequestInfo | URL, init: RequestInit = {}) => {
    const call = { url: String(url), init };
    calls.push(call);
    if (call.url === "https://oauth2.googleapis.com/token") {
      return Response.json({ access_token: "ya29.test", expires_in: 3599 });
    }
    return handler(call) ?? new Response("{}", { status: 200 });
  }) as typeof fetch;
  return { calls, fetcher };
}

const ROOT =
  "https://firestore.googleapis.com/v1/projects/myfit-d6275/databases/(default)/documents";

describe("Firestore REST", () => {
  it("parses the single JSON service-account secret", () => {
    expect(parseServiceAccount(JSON.stringify({ ...account, type: "service_account" })).client_email)
      .toBe(account.client_email);
    expect(() => parseServiceAccount("not json")).toThrow();
    expect(() => parseServiceAccount(JSON.stringify({ client_email: "x" }))).toThrow();
  });

  it("round-trips Firestore values used by lessons", () => {
    const fields = {
      order: 3,
      durationSeconds: null,
      ratio: 1.5,
      title: "1-dars",
      ok: true,
      createdAt: new Date("2026-11-10T12:00:00.000Z"),
      list: [1, "a"],
      nested: { a: 1 },
    };
    const encoded = encodeFields(fields);
    expect(encoded.order).toEqual({ integerValue: "3" });
    expect(encoded.ratio).toEqual({ doubleValue: 1.5 });
    expect(encoded.createdAt).toEqual({ timestampValue: "2026-11-10T12:00:00.000Z" });
    expect(decodeFields(encoded)).toEqual(fields);
  });

  it("signs a service-account OAuth assertion and caches the token", async () => {
    const { calls, fetcher } = google(() => undefined);
    const db = new FirestoreRest("myfit-d6275", account, fetcher, () => Date.UTC(2026, 10, 10));
    await db.get("admins/u1");
    await db.get("admins/u2");
    const oauth = calls.filter((c) => c.url.includes("oauth2"));
    expect(oauth).toHaveLength(1);
    const form = new URLSearchParams(String(oauth[0]!.init.body));
    expect(form.get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:jwt-bearer");
    const { payload } = await jwtVerify(form.get("assertion")!, publicKey, {
      issuer: account.client_email,
      audience: "https://oauth2.googleapis.com/token",
      currentDate: new Date(Date.UTC(2026, 10, 10)),
    });
    expect(payload.scope).toBe("https://www.googleapis.com/auth/datastore");
    const reads = calls.filter((c) => c.url.startsWith(ROOT));
    expect(reads.map((c) => c.url)).toEqual([`${ROOT}/admins/u1`, `${ROOT}/admins/u2`]);
    expect((reads[0]!.init.headers as Record<string, string>).authorization).toBe("Bearer ya29.test");
  });

  it("returns null for missing documents and decodes existing ones", async () => {
    const { fetcher } = google((call) =>
      call.url.endsWith("/admins/missing")
        ? new Response("{}", { status: 404 })
        : Response.json({
            name: "projects/p/databases/(default)/documents/admins/u1",
            fields: { role: { stringValue: "admin" } },
          }),
    );
    const db = new FirestoreRest("myfit-d6275", account, fetcher);
    expect(await db.get("admins/missing")).toBeNull();
    expect(await db.get("admins/u1")).toEqual({ id: "u1", fields: { role: "admin" } });
  });

  it("commits create (exists:false) and update (mask, exists:true) in a transaction", async () => {
    const { calls, fetcher } = google(() => undefined);
    const db = new FirestoreRest("myfit-d6275", account, fetcher);
    await db.commit(
      [
        { kind: "create", path: "courses/cardio/lessons/l1", fields: { order: 1 } },
        { kind: "update", path: "video_uploads/u1", fields: { status: "completed", lessonId: "l1" } },
      ],
      "tx-1",
    );
    const commit = calls.find((c) => c.url === `${ROOT}:commit`)!;
    const body = JSON.parse(String(commit.init.body));
    expect(body.transaction).toBe("tx-1");
    expect(body.writes[0]).toEqual({
      update: {
        name: "projects/myfit-d6275/databases/(default)/documents/courses/cardio/lessons/l1",
        fields: { order: { integerValue: "1" } },
      },
      currentDocument: { exists: false },
    });
    expect(body.writes[1].updateMask).toEqual({ fieldPaths: ["status", "lessonId"] });
    expect(body.writes[1].currentDocument).toEqual({ exists: true });
  });

  it("reads the last lesson order inside the transaction", async () => {
    const { calls, fetcher } = google((call) =>
      call.url.endsWith(":runQuery")
        ? Response.json([{ document: { fields: { order: { integerValue: "7" } } }, readTime: "t" }])
        : undefined,
    );
    const db = new FirestoreRest("myfit-d6275", account, fetcher);
    expect(await db.lastLessonOrder("cardio", "tx-9")).toBe(7);
    const query = calls.find((c) => c.url === `${ROOT}/courses/cardio:runQuery`)!;
    const body = JSON.parse(String(query.init.body));
    expect(body.transaction).toBe("tx-9");
    expect(body.structuredQuery.orderBy[0]).toEqual({ field: { fieldPath: "order" }, direction: "DESCENDING" });
  });

  it("maps contention and outages", async () => {
    const aborted = new FirestoreRest("p1234", account, google(() => new Response("{}", { status: 409 })).fetcher);
    await expect(aborted.commit([], "tx")).rejects.toBeInstanceOf(FirestoreAborted);
    const down = new FirestoreRest("p1234", account, google(() => new Response("{}", { status: 503 })).fetcher);
    await expect(down.get("admins/u")).rejects.toMatchObject({ reason: "database-unavailable" });
    const denied = new FirestoreRest("p1234", account, google(() => new Response("{}", { status: 403 })).fetcher);
    await expect(denied.get("admins/u")).rejects.toMatchObject({ status: 500, reason: "internal" });
  });
});
