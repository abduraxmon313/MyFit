"use strict";

/**
 * Minimal ISO-BMFF (MP4) reader used to verify uploaded lesson videos.
 *
 * It reads only box headers and the `moov` box (via `readAt`), so a 2 GB
 * file is never loaded into memory. Keep the logic in sync with
 * `lib/services/mp4_inspector.dart`.
 */

/** H.264 sample entry types. */
const H264_CODECS = new Set(["avc1", "avc3"]);
/** QuickTime (.mov) major brand; not accepted as MP4. */
const QUICKTIME_BRAND = "qt  ";
/** The movie header of a normal lesson is far smaller than this. */
const MAX_MOOV_BYTES = 64 * 1024 * 1024;
/** Safety limit for walking top-level boxes. */
const MAX_TOP_LEVEL_BOXES = 64;

class Mp4Error extends Error {
  /**
   * @param {string} reason Machine-readable reason sent to the app.
   * @param {string} message Developer message.
   */
  constructor(reason, message) {
    super(message);
    this.reason = reason;
  }
}

function fourcc(bytes, offset) {
  return String.fromCharCode(
    bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3],
  );
}

function uint32(bytes, offset) {
  return (
    bytes[offset] * 0x1000000 +
    ((bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3])
  );
}

function uint64(bytes, offset) {
  return uint32(bytes, offset) * 0x100000000 + uint32(bytes, offset + 4);
}

/**
 * Reads the boxes inside [bytes] between [start] and [end].
 * @return {{type: string, start: number, end: number}[]} payload ranges.
 */
function childBoxes(bytes, start, end) {
  const boxes = [];
  let offset = start;
  while (offset + 8 <= end) {
    let size = uint32(bytes, offset);
    const type = fourcc(bytes, offset + 4);
    let header = 8;
    if (size === 1) {
      if (offset + 16 > end) break;
      size = uint64(bytes, offset + 8);
      header = 16;
    } else if (size === 0) {
      size = end - offset;
    }
    if (size < header || offset + size > end) break;
    boxes.push({type, start: offset + header, end: offset + size});
    offset += size;
  }
  return boxes;
}

function find(bytes, start, end, type) {
  return childBoxes(bytes, start, end).find((box) => box.type === type);
}

/**
 * Parses a `moov` payload.
 * @return {{videoCodec: string|null, durationSeconds: number|null}}
 */
function parseMoov(bytes) {
  let durationSeconds = null;
  const mvhd = find(bytes, 0, bytes.length, "mvhd");
  if (mvhd && mvhd.end - mvhd.start >= 20) {
    const version = bytes[mvhd.start];
    const base = mvhd.start + 4;
    const timescale = version === 1 ? uint32(bytes, base + 16) : uint32(bytes, base + 8);
    const duration = version === 1 ? uint64(bytes, base + 20) : uint32(bytes, base + 12);
    if (timescale > 0 && duration > 0) durationSeconds = duration / timescale;
  }

  let videoCodec = null;
  for (const trak of childBoxes(bytes, 0, bytes.length)) {
    if (trak.type !== "trak") continue;
    const mdia = find(bytes, trak.start, trak.end, "mdia");
    if (!mdia) continue;
    const hdlr = find(bytes, mdia.start, mdia.end, "hdlr");
    if (!hdlr || hdlr.end - hdlr.start < 12) continue;
    if (fourcc(bytes, hdlr.start + 8) !== "vide") continue;
    const minf = find(bytes, mdia.start, mdia.end, "minf");
    const stbl = minf && find(bytes, minf.start, minf.end, "stbl");
    const stsd = stbl && find(bytes, stbl.start, stbl.end, "stsd");
    if (!stsd || stsd.end - stsd.start < 16) continue;
    // FullBox header (4) + entry_count (4), then the first sample entry.
    videoCodec = fourcc(bytes, stsd.start + 12);
    break;
  }
  return {videoCodec, durationSeconds};
}

/**
 * Inspects an MP4 file through random-access reads.
 *
 * @param {(offset: number, length: number) => Promise<Uint8Array>} readAt
 * @param {number} fileSize total size in bytes.
 * @return {Promise<{majorBrand: string, videoCodec: string,
 *   durationSeconds: number|null}>}
 * @throws {Mp4Error} when the file is not an H.264 MP4.
 */
async function inspectMp4(readAt, fileSize) {
  let offset = 0;
  let majorBrand = null;
  let moov = null;
  for (let index = 0; index < MAX_TOP_LEVEL_BOXES && offset + 8 <= fileSize; index++) {
    const header = await readAt(offset, Math.min(16, fileSize - offset));
    if (header.length < 8) break;
    let size = uint32(header, 0);
    const type = fourcc(header, 4);
    let headerSize = 8;
    if (size === 1) {
      if (header.length < 16) break;
      size = uint64(header, 8);
      headerSize = 16;
    } else if (size === 0) {
      size = fileSize - offset;
    }
    if (size < headerSize || offset + size > fileSize) {
      throw new Mp4Error("unsupported-format", `Broken box ${type} at ${offset}`);
    }

    if (index === 0) {
      if (type !== "ftyp" || size < headerSize + 4) {
        throw new Mp4Error("unsupported-format", "File does not start with ftyp");
      }
      const ftyp = await readAt(offset + headerSize, 4);
      majorBrand = fourcc(ftyp, 0);
      if (majorBrand === QUICKTIME_BRAND) {
        throw new Mp4Error("unsupported-format", "QuickTime files are not MP4");
      }
    } else if (type === "moov") {
      const length = size - headerSize;
      if (length > MAX_MOOV_BYTES) {
        throw new Mp4Error("unsupported-format", "moov box is too large");
      }
      moov = await readAt(offset + headerSize, length);
      break;
    }
    offset += size;
  }

  if (!majorBrand) throw new Mp4Error("unsupported-format", "No ftyp box");
  if (!moov) throw new Mp4Error("unsupported-format", "No moov box");
  const {videoCodec, durationSeconds} = parseMoov(moov);
  if (!videoCodec) throw new Mp4Error("unsupported-format", "No video track");
  if (!H264_CODECS.has(videoCodec)) {
    throw new Mp4Error("not-h264", `Video codec ${videoCodec} is not H.264`);
  }
  return {majorBrand, videoCodec, durationSeconds};
}

module.exports = {inspectMp4, parseMoov, Mp4Error, H264_CODECS, MAX_MOOV_BYTES};
