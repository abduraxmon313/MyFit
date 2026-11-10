import { describe, expect, it } from "vitest";
import { presignPut } from "../src/presign";

const config = {
  endpoint: "https://7d6c72f2d7ccf971e52c251086f2bfa1.r2.cloudflarestorage.com",
  bucket: "myfit-videos",
  accessKeyId: "AKIDEXAMPLE",
  secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
};
const NOW = new Date(Date.UTC(2026, 10, 10, 12, 0, 0));

describe("presignPut", () => {
  it("binds key, content type, length and a 15 minute expiry", async () => {
    const url = new URL(
      await presignPut(config, "lessons/cardio/2026/11/a b.mp4", "video/mp4", 2147483648, 900, NOW),
    );
    expect(url.origin).toBe(config.endpoint);
    expect(url.pathname).toBe("/myfit-videos/lessons/cardio/2026/11/a%20b.mp4");
    const params = url.searchParams;
    expect(params.get("X-Amz-Algorithm")).toBe("AWS4-HMAC-SHA256");
    expect(params.get("X-Amz-Expires")).toBe("900");
    expect(params.get("X-Amz-Date")).toBe("20261110T120000Z");
    expect(params.get("X-Amz-Credential")).toBe("AKIDEXAMPLE/20261110/auto/s3/aws4_request");
    expect(params.get("X-Amz-SignedHeaders")).toBe("content-length;content-type;host");
    // Presigned S3 URLs imply UNSIGNED-PAYLOAD; no body hash is required.
    expect(params.get("X-Amz-Content-Sha256")).toBeNull();
    expect(params.get("X-Amz-Signature")).toMatch(/^[0-9a-f]{64}$/);
    // R2 rejects SDK checksum parameters in presigned URLs.
    expect([...params.keys()].some((k) => k.toLowerCase().includes("checksum"))).toBe(false);
    // The secret never appears in the URL.
    expect(url.toString()).not.toContain(config.secretAccessKey);
  });

  it("produces different signatures for a different size or type", async () => {
    const sig = async (size: number, type = "video/mp4") =>
      new URL(await presignPut(config, "k.mp4", type, size, 900, NOW)).searchParams.get("X-Amz-Signature");
    expect(await sig(100)).not.toBe(await sig(101));
    expect(await sig(100)).not.toBe(await sig(100, "video/quicktime"));
  });

  it("rejects a non-https endpoint", async () => {
    await expect(
      presignPut({ ...config, endpoint: "http://insecure.example" }, "k.mp4", "video/mp4", 1, 900, NOW),
    ).rejects.toThrow();
  });
});
