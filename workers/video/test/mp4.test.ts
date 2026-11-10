import { describe, expect, it } from "vitest";
import { inspectMp4, Mp4Error } from "../src/mp4";
import { ftypBox, moovBox, mp4, readerFor } from "./helpers";

describe("inspectMp4", () => {
  it("accepts H.264 with moov at the end or the start", async () => {
    for (const moovFirst of [false, true]) {
      const bytes = mp4({ moovFirst });
      const info = await inspectMp4(readerFor(bytes), bytes.length);
      expect(info).toEqual({ majorBrand: "isom", videoCodec: "avc1", durationSeconds: 90.5 });
    }
  });

  it("handles 64-bit box sizes and avc3", async () => {
    const bytes = mp4({ largeMdat: true, codec: "avc3" });
    expect((await inspectMp4(readerFor(bytes), bytes.length)).videoCodec).toBe("avc3");
  });

  it("rejects HEVC, QuickTime and non-MP4 files", async () => {
    const reason = async (bytes: Uint8Array) =>
      inspectMp4(readerFor(bytes), bytes.length).then(
        () => "ok",
        (error) => (error instanceof Mp4Error ? error.reason : "other"),
      );
    expect(await reason(mp4({ codec: "hvc1" }))).toBe("not-h264");
    expect(await reason(mp4({ brand: "qt  " }))).toBe("unsupported-format");
    expect(await reason(new TextEncoder().encode("plain text, not a video"))).toBe("unsupported-format");
  });

  it("checks a ~2 GB file with a few small reads", async () => {
    // ftyp + huge mdat + moov with large sample tables, served virtually.
    const ftyp = ftypBox();
    const moov = moovBox({ tableBytes: 900_000 });
    const size = 2 * 1024 * 1024 * 1024 - 1;
    const mdatSize = size - ftyp.length - moov.length;
    const mdatHeader = new Uint8Array(8);
    new DataView(mdatHeader.buffer).setUint32(0, mdatSize);
    mdatHeader.set(new TextEncoder().encode("mdat"), 4);
    const moovStart = size - moov.length;
    let reads = 0;
    let bytesRead = 0;
    const readAt = async (offset: number, length: number) => {
      reads += 1;
      bytesRead += length;
      const out = new Uint8Array(length);
      for (let i = 0; i < length; i++) {
        const pos = offset + i;
        if (pos < ftyp.length) out[i] = ftyp[pos]!;
        else if (pos < ftyp.length + 8) out[i] = mdatHeader[pos - ftyp.length]!;
        else if (pos >= moovStart) out[i] = moov[pos - moovStart]!;
      }
      return out;
    };
    const info = await inspectMp4(readAt, size);
    expect(info.videoCodec).toBe("avc1");
    expect(reads).toBeLessThanOrEqual(8);
    expect(bytesRead).toBeLessThan(3 * 1024 * 1024);
  });
});
