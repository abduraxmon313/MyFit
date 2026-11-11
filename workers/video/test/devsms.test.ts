import { beforeEach, describe, expect, it } from "vitest";
import {
  DevSmsClient,
  normalizeTemplate,
  renderTemplate,
  templatePlaceholders,
} from "../src/devsms";
import { clearTemplateCache, DevSmsSender, parseOtpTemplateConfig } from "../src/sms";

interface Call {
  url: string;
  method: string;
  headers: Record<string, string>;
  body?: any;
}

function api(handler: (call: Call) => Response) {
  const calls: Call[] = [];
  const fetcher = (async (url: RequestInfo | URL, init: RequestInit = {}) => {
    const call: Call = {
      url: String(url),
      method: init.method ?? "GET",
      headers: (init.headers ?? {}) as Record<string, string>,
      body: init.body ? JSON.parse(String(init.body)) : undefined,
    };
    calls.push(call);
    return handler(call);
  }) as typeof fetch;
  return { calls, fetcher };
}

const TEMPLATES = [
  { id: 11, name: "Kirish kodi", text: "MyFit: kirish kodingiz {code}. Hech kimga bermang.", status: "approved" },
  { id: 12, name: "Aksiya", text: "MyFit: {name}, sizga {percent} chegirma!", status: "moderation" },
];

beforeEach(() => clearTemplateCache());

describe("templates:read", () => {
  it("reads all pages with the Bearer token and normalizes records", async () => {
    const g = api((call) =>
      call.url.includes("cursor=p2")
        ? Response.json({ success: true, data: [TEMPLATES[1]], meta: { next_cursor: null } })
        : Response.json({ success: true, data: [TEMPLATES[0]], meta: { next_cursor: "p2" } }),
    );
    const list = await new DevSmsClient("tok", g.fetcher).listTemplates();
    expect(list).toEqual([
      { id: 11, name: "Kirish kodi", text: TEMPLATES[0]!.text, status: "approved", placeholders: ["{code}"] },
      { id: 12, name: "Aksiya", text: TEMPLATES[1]!.text, status: "moderation", placeholders: ["{name}", "{percent}"] },
    ]);
    expect(g.calls.map((c) => c.url)).toEqual([
      "https://devsms.uz/api/v1/templates",
      "https://devsms.uz/api/v1/templates?cursor=p2",
    ]);
    expect(g.calls.every((c) => c.method === "GET" && c.headers.authorization === "Bearer tok")).toBe(true);
  });

  it("accepts other response shapes and field names", () => {
    expect(normalizeTemplate({ template_id: "7", title: "OTP", template: "Kod: %d", state: "active" })).toEqual({
      id: "7",
      name: "OTP",
      text: "Kod: %d",
      status: "active",
      placeholders: ["%d"],
    });
    expect(normalizeTemplate({ name: "no id" })).toBeNull();
    expect(templatePlaceholders("A {{ code }} #code# {x} %s {x}")).toEqual(["{{ code }}", "#code#", "{x}", "%s"]);
  });

  it("reports missing permission and bad tokens", async () => {
    const forbidden = api(() => Response.json({ success: false, error_code: "forbidden" }, { status: 403 }));
    await expect(new DevSmsClient("tok", forbidden.fetcher).listTemplates()).rejects.toMatchObject({
      reason: "sms-misconfigured",
      message: expect.stringContaining("templates:read"),
    });
    const bad = api(() => Response.json({ success: false }, { status: 401 }));
    await expect(new DevSmsClient("tok", bad.fetcher).listTemplates()).rejects.toMatchObject({
      reason: "sms-misconfigured",
    });
    await expect(new DevSmsClient("").listTemplates()).rejects.toMatchObject({ reason: "sms-misconfigured" });
  });

  it("never modifies templates (GET only)", async () => {
    const g = api(() => Response.json({ data: TEMPLATES }));
    await new DevSmsClient("tok", g.fetcher).listTemplates();
    expect(g.calls.every((c) => c.method === "GET")).toBe(true);
  });
});

describe("rendering", () => {
  it("fills every token and refuses missing values", () => {
    expect(renderTemplate("Kod {code}, {code}!", { "{code}": "123456" })).toBe("Kod 123456, 123456!");
    expect(() => renderTemplate("{name}: {code}", { "{code}": "1" })).toThrow(/\{name\}/);
  });
});

describe("OTP sender with a chosen template", () => {
  it("sends the filled template text with template_id", async () => {
    const g = api((call) =>
      call.method === "GET" ? Response.json({ data: TEMPLATES }) : Response.json({ success: true }),
    );
    const sender = new DevSmsSender("tok", g.fetcher, "MyFit", { templateId: "11", from: "MyFit" });
    await sender.sendCode("998901234567", "482615");
    await sender.sendCode("998901234567", "111222");
    const posts = g.calls.filter((c) => c.method === "POST");
    expect(posts[0]!.url).toBe("https://devsms.uz/api/v1/sms");
    expect(posts[0]!.body).toEqual({
      phone: "998901234567",
      message: "MyFit: kirish kodingiz 482615. Hech kimga bermang.",
      template_id: 11,
      from: "MyFit",
    });
    expect(posts[0]!.headers["idempotency-key"]).toMatch(/^[0-9a-f-]{36}$/);
    // Template is cached: one GET for two SMS.
    expect(g.calls.filter((c) => c.method === "GET")).toHaveLength(1);
  });

  it("uses explicit placeholder and fixed values for multi-token templates", async () => {
    const g = api((call) =>
      call.method === "GET"
        ? Response.json({ data: [{ id: 30, name: "Kod", text: "{app}: kod {code}" }] })
        : Response.json({ success: true }),
    );
    const config = parseOtpTemplateConfig({
      DEVSMS_OTP_TEMPLATE_ID: "30",
      DEVSMS_OTP_CODE_PLACEHOLDER: "{code}",
      DEVSMS_OTP_TEMPLATE_VALUES: '{"{app}":"MyFit"}',
    });
    await new DevSmsSender("tok", g.fetcher, "MyFit", config).sendCode("998901234567", "999000");
    expect(g.calls.find((c) => c.method === "POST")!.body.message).toBe("MyFit: kod 999000");
  });

  it("refuses unknown templates or templates without a code token, before sending", async () => {
    const g = api((call) =>
      call.method === "GET"
        ? Response.json({ data: [...TEMPLATES, { id: 40, name: "Matn", text: "Salom" }] })
        : Response.json({ success: true }),
    );
    const send = (templateId: string) =>
      new DevSmsSender("tok", g.fetcher, "MyFit", { templateId })
        .sendCode("998901234567", "1")
        .then(() => "ok", (e) => e.reason);
    expect(await send("99")).toBe("sms-misconfigured");
    expect(await send("40")).toBe("sms-misconfigured");
    expect(await send("12")).toBe("sms-misconfigured"); // two tokens, none chosen
    expect(g.calls.some((c) => c.method === "POST")).toBe(false);
  });

  it("without a configured template keeps the universal OTP", async () => {
    expect(parseOtpTemplateConfig({})).toBeUndefined();
    const g = api(() => Response.json({ success: true }));
    await new DevSmsSender("tok", g.fetcher).sendCode("998901234567", "123123");
    expect(g.calls).toHaveLength(1);
    expect(g.calls[0]!.body).toEqual({
      phone: "998901234567",
      otp: { template_type: 4, service_name: "MyFit", code: "123123" },
    });
  });

  it("rejects bad JSON config", () => {
    expect(() =>
      parseOtpTemplateConfig({ DEVSMS_OTP_TEMPLATE_ID: "1", DEVSMS_OTP_TEMPLATE_VALUES: "{bad" }),
    ).toThrow();
  });
});
