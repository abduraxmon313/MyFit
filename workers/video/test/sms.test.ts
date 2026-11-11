import { describe, expect, it } from "vitest";
import { handle, type Env } from "../src/index";
import type { IdentityApi } from "../src/identity";
import {
  DevSmsSender,
  hmacKeyFromSecret,
  MAX_ATTEMPTS,
  normalizeUzPhone,
  randomSixDigits,
  type SmsDeps,
} from "../src/sms";
import { FakeDb } from "./helpers";

const env = { FIREBASE_PROJECT_ID: "myfit-d6275", ALLOWED_ORIGINS: "" } as Env;

class FakeIdentity implements IdentityApi {
  users = new Map<string, string>([["+998901234567", "existing-uid"]]);
  async uidForPhone(phone: string) {
    if (!this.users.has(phone)) this.users.set(phone, `new-${this.users.size}`);
    return this.users.get(phone)!;
  }
  async customToken(uid: string) {
    return `custom-token-for-${uid}`;
  }
}

function harness() {
  const db = new FakeDb();
  const identity = new FakeIdentity();
  const sent: { phone: string; code: string }[] = [];
  let now = Date.UTC(2026, 10, 10, 9, 0, 0);
  let nextCode = "123456";
  const key = hmacKeyFromSecret("test-secret");
  const sms: SmsDeps = {
    db,
    identity,
    sender: { sendCode: async (phone, code) => void sent.push({ phone, code }) },
    hmacKey: () => key,
    now: () => new Date(now),
    randomCode: () => nextCode,
  };
  const call = async (path: string, body: unknown, ip = "203.0.113.7") => {
    const response = await handle(
      new Request(`https://w.example${path}`, {
        method: "POST",
        headers: { "content-type": "application/json", "cf-connecting-ip": ip },
        body: JSON.stringify(body),
      }),
      env,
      { sms },
    );
    const json = (await response.json()) as any;
    return { status: response.status, reason: json.error?.reason, json, retry: response.headers.get("retry-after") };
  };
  return {
    db,
    identity,
    sent,
    call,
    advance: (ms: number) => (now += ms),
    setCode: (code: string) => (nextCode = code),
  };
}

describe("SMS sign-in", () => {
  it("normalizes Uzbek numbers and rejects others", () => {
    expect(normalizeUzPhone("+998 90 123 45 67")).toBe("998901234567");
    expect(normalizeUzPhone("901234567")).toBe("998901234567");
    expect(() => normalizeUzPhone("+7 999 123 45 67")).toThrow();
    expect(() => normalizeUzPhone("")).toThrow();
    for (let i = 0; i < 50; i++) expect(randomSixDigits()).toMatch(/^\d{6}$/);
  });

  it("sends a code, verifies it and returns a custom token for the existing UID", async () => {
    const h = harness();
    const send = await h.call("/auth/sms/send", { phone: "+998 90 123 45 67" });
    expect(send.status).toBe(200);
    expect(send.json).toEqual({ sent: true, expiresInSeconds: 300, resendAfterSeconds: 60 });
    expect(h.sent).toEqual([{ phone: "998901234567", code: "123456" }]);
    // Only a hash is stored, never the code or the raw phone.
    const stored = [...h.db.docs.entries()].find(([path]) => path.startsWith("sms_codes/"))!;
    expect(stored[0]).not.toContain("998901234567");
    expect(JSON.stringify(stored[1])).not.toContain("123456");

    const ok = await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" });
    expect(ok.status).toBe(200);
    expect(ok.json).toEqual({ customToken: "custom-token-for-existing-uid" });
    // A code works once.
    const again = await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" });
    expect(again).toMatchObject({ status: 410, reason: "code-expired" });
  });

  it("keeps the code usable when Firebase sign-in fails", async () => {
    const h = harness();
    await h.call("/auth/sms/send", { phone: "998901234567" });
    const original = h.identity.uidForPhone.bind(h.identity);
    h.identity.uidForPhone = async () => {
      throw Object.assign(new (await import("../src/errors")).ApiError(500, "auth-misconfigured", "no role"));
    };
    expect(await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" })).toMatchObject({
      status: 500,
      reason: "auth-misconfigured",
    });
    h.identity.uidForPhone = original;
    const retry = await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" });
    expect(retry.status).toBe(200);
    expect(retry.json.customToken).toBe("custom-token-for-existing-uid");
  });

  it("creates a Firebase user for a new phone", async () => {
    const h = harness();
    await h.call("/auth/sms/send", { phone: "+998931112233" });
    const ok = await h.call("/auth/sms/verify", { phone: "+998931112233", code: "123456" });
    expect(ok.json.customToken).toBe("custom-token-for-new-1");
    expect(h.identity.users.get("+998931112233")).toBe("new-1");
  });

  it("rejects wrong codes and locks after the attempt limit", async () => {
    const h = harness();
    await h.call("/auth/sms/send", { phone: "998901234567" });
    for (let i = 1; i < MAX_ATTEMPTS; i++) {
      expect(await h.call("/auth/sms/verify", { phone: "998901234567", code: "000000" })).toMatchObject({
        status: 400,
        reason: "invalid-code",
      });
    }
    expect(await h.call("/auth/sms/verify", { phone: "998901234567", code: "000000" })).toMatchObject({
      status: 429,
      reason: "too-many-attempts",
    });
    // Even the right code is refused now.
    expect(await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" })).toMatchObject({
      status: 429,
      reason: "too-many-attempts",
    });
  });

  it("expires codes after 5 minutes and rejects malformed input", async () => {
    const h = harness();
    await h.call("/auth/sms/send", { phone: "998901234567" });
    h.advance(5 * 60 * 1000 + 1);
    expect(await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" })).toMatchObject({
      status: 410,
      reason: "code-expired",
    });
    expect((await h.call("/auth/sms/verify", { phone: "998901234567", code: "12ab" })).reason).toBe("invalid-code");
    expect((await h.call("/auth/sms/send", { phone: "123" })).reason).toBe("invalid-phone");
  });

  it("limits resends per phone (60 s, 5/day) and per IP (10/hour)", async () => {
    const h = harness();
    await h.call("/auth/sms/send", { phone: "998901234567" });
    const soon = await h.call("/auth/sms/send", { phone: "998901234567" });
    expect(soon).toMatchObject({ status: 429, reason: "resend-too-soon", retry: "60" });
    for (let i = 0; i < 4; i++) {
      h.advance(61_000);
      expect((await h.call("/auth/sms/send", { phone: "998901234567" })).status).toBe(200);
    }
    h.advance(61_000);
    expect((await h.call("/auth/sms/send", { phone: "998901234567" })).reason).toBe("too-many-requests");
    expect(h.sent).toHaveLength(5);

    const ip = harness();
    for (let i = 0; i < 10; i++) {
      expect((await ip.call("/auth/sms/send", { phone: `99890000000${i}` }, "198.51.100.1")).status).toBe(200);
    }
    expect((await ip.call("/auth/sms/send", { phone: "998911111111" }, "198.51.100.1")).reason).toBe(
      "too-many-requests",
    );
    expect((await ip.call("/auth/sms/send", { phone: "998911111111" }, "198.51.100.2")).status).toBe(200);
  });

  it("a new code replaces the old one", async () => {
    const h = harness();
    await h.call("/auth/sms/send", { phone: "998901234567" });
    h.advance(61_000);
    h.setCode("654321");
    await h.call("/auth/sms/send", { phone: "998901234567" });
    expect((await h.call("/auth/sms/verify", { phone: "998901234567", code: "123456" })).reason).toBe("invalid-code");
    expect((await h.call("/auth/sms/verify", { phone: "998901234567", code: "654321" })).status).toBe(200);
  });
});

describe("DevSmsSender", () => {
  it("uses universal OTP with an idempotency key and retries once on 502", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const responses = [
      new Response(JSON.stringify({ success: false, error_code: "provider_outcome_unknown" }), { status: 502 }),
      new Response(JSON.stringify({ success: true, data: { id: 1 } }), { status: 200 }),
    ];
    const sender = new DevSmsSender("tok", (async (url: RequestInfo | URL, init?: RequestInit) => {
      calls.push({ url: String(url), init: init! });
      return responses.shift()!;
    }) as typeof fetch);
    await sender.sendCode("998901234567", "482615");
    expect(calls).toHaveLength(2);
    expect(calls[0]!.url).toBe("https://devsms.uz/api/v1/sms");
    const headers = calls[0]!.init.headers as Record<string, string>;
    expect(headers.authorization).toBe("Bearer tok");
    expect(headers["idempotency-key"]).toMatch(/^[0-9a-f-]{36}$/);
    expect((calls[1]!.init.headers as Record<string, string>)["idempotency-key"]).toBe(headers["idempotency-key"]);
    expect(JSON.parse(String(calls[0]!.init.body))).toEqual({
      phone: "998901234567",
      otp: { template_type: 4, service_name: "MyFit", code: "482615" },
    });
  });

  it("maps provider failures", async () => {
    const send = (status: number, body: unknown = {}) =>
      new DevSmsSender("tok", (async () => new Response(JSON.stringify(body), { status })) as typeof fetch)
        .sendCode("998901234567", "111111")
        .then(() => "ok", (e) => e.reason);
    expect(await send(401)).toBe("sms-misconfigured");
    expect(await send(402)).toBe("sms-unavailable");
    expect(await send(422)).toBe("invalid-phone");
    expect(await send(500)).toBe("sms-unavailable");
    expect(await new DevSmsSender("").sendCode("998901234567", "1").catch((e) => e.reason)).toBe("sms-misconfigured");
  });
});
