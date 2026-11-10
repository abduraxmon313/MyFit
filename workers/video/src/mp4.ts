/**
 * ISO-BMFF (MP4) check for uploaded lesson videos: the file must be an MP4
 * (not QuickTime) whose video track uses H.264 (`avc1`/`avc3`).
 *
 * Only box headers and a few small boxes are read, through a block cache, so
 * a 2 GB file costs a handful of ranged reads and very little memory/CPU
 * (Workers Free: 10 ms CPU, 50 subrequests, 128 MB). Mirrors
 * `lib/services/mp4_inspector.dart` in the app.
 */

export type ReadAt = (offset: number, length: number) => Promise<Uint8Array>;

export const H264_CODECS = new Set(["avc1", "avc3"]);
const QUICKTIME_BRAND = "qt  ";
const MAX_TOP_LEVEL_BOXES = 64;
const MAX_CHILD_BOXES = 256;

export class Mp4Error extends Error {
  constructor(
    readonly reason: "unsupported-format" | "not-h264",
    message: string,
  ) {
    super(message);
  }
}

export interface Mp4Info {
  majorBrand: string;
  videoCodec: string;
  durationSeconds: number | null;
}

interface Box {
  type: string;
  /** Payload start (after the header). */
  start: number;
  end: number;
}

const fourcc = (b: Uint8Array, o: number) =>
  String.fromCharCode(b[o]!, b[o + 1]!, b[o + 2]!, b[o + 3]!);
const u32 = (b: Uint8Array, o: number) =>
  b[o]! * 0x1000000 + ((b[o + 1]! << 16) | (b[o + 2]! << 8) | b[o + 3]!);
const u64 = (b: Uint8Array, o: number) => u32(b, o) * 0x100000000 + u32(b, o + 4);

/** Caches aligned blocks so nearby header reads share one request. */
export class BlockReader {
  private readonly blocks = new Map<number, Promise<Uint8Array>>();
  reads = 0;

  constructor(
    private readonly source: ReadAt,
    private readonly size: number,
    private readonly blockSize = 256 * 1024,
    private readonly maxReads = 24,
  ) {}

  private block(index: number): Promise<Uint8Array> {
    let cached = this.blocks.get(index);
    if (!cached) {
      if (this.reads >= this.maxReads) {
        throw new Mp4Error("unsupported-format", "MP4 structure too complex");
      }
      this.reads += 1;
      const offset = index * this.blockSize;
      cached = this.source(offset, Math.min(this.blockSize, this.size - offset));
      this.blocks.set(index, cached);
    }
    return cached;
  }

  async read(offset: number, length: number): Promise<Uint8Array> {
    const end = Math.min(offset + length, this.size);
    if (offset < 0 || offset >= end) return new Uint8Array(0);
    const out = new Uint8Array(end - offset);
    let position = offset;
    while (position < end) {
      const index = Math.floor(position / this.blockSize);
      const data = await this.block(index);
      const blockStart = index * this.blockSize;
      const from = position - blockStart;
      const to = Math.min(data.length, end - blockStart);
      if (to <= from) break;
      out.set(data.subarray(from, to), position - offset);
      position = blockStart + to;
    }
    return out;
  }
}

async function boxAt(
  reader: BlockReader,
  offset: number,
  limit: number,
): Promise<Box | null> {
  if (offset + 8 > limit) return null;
  const header = await reader.read(offset, Math.min(16, limit - offset));
  if (header.length < 8) return null;
  let size = u32(header, 0);
  const type = fourcc(header, 4);
  let headerSize = 8;
  if (size === 1) {
    if (header.length < 16) return null;
    size = u64(header, 8);
    headerSize = 16;
  } else if (size === 0) {
    size = limit - offset;
  }
  if (size < headerSize || offset + size > limit) {
    throw new Mp4Error("unsupported-format", `Broken box ${type} at ${offset}`);
  }
  return { type, start: offset + headerSize, end: offset + size };
}

async function findChild(
  reader: BlockReader,
  parent: Box,
  type: string,
  skip = 0,
): Promise<Box | null> {
  let offset = parent.start + skip;
  for (let i = 0; i < MAX_CHILD_BOXES; i++) {
    const box = await boxAt(reader, offset, parent.end);
    if (!box) return null;
    if (box.type === type) return box;
    offset = box.end;
  }
  return null;
}

async function* children(reader: BlockReader, parent: Box) {
  let offset = parent.start;
  for (let i = 0; i < MAX_CHILD_BOXES; i++) {
    const box = await boxAt(reader, offset, parent.end);
    if (!box) return;
    yield box;
    offset = box.end;
  }
}

async function videoCodecOf(reader: BlockReader, trak: Box) {
  const mdia = await findChild(reader, trak, "mdia");
  if (!mdia) return null;
  const hdlr = await findChild(reader, mdia, "hdlr");
  if (!hdlr || hdlr.end - hdlr.start < 12) return null;
  const handler = await reader.read(hdlr.start + 8, 4);
  if (fourcc(handler, 0) !== "vide") return null;
  const minf = await findChild(reader, mdia, "minf");
  const stbl = minf && (await findChild(reader, minf, "stbl"));
  const stsd = stbl && (await findChild(reader, stbl, "stsd"));
  if (!stsd || stsd.end - stsd.start < 16) return null;
  // FullBox (4) + entry_count (4), then the first sample entry header.
  const entry = await reader.read(stsd.start + 8, 8);
  return entry.length === 8 ? fourcc(entry, 4) : null;
}

export async function inspectMp4(readAt: ReadAt, fileSize: number): Promise<Mp4Info> {
  const reader = new BlockReader(readAt, fileSize);
  let offset = 0;
  let majorBrand: string | null = null;
  let moov: Box | null = null;
  for (let i = 0; i < MAX_TOP_LEVEL_BOXES; i++) {
    const box = await boxAt(reader, offset, fileSize);
    if (!box) break;
    if (i === 0) {
      if (box.type !== "ftyp" || box.end - box.start < 4) {
        throw new Mp4Error("unsupported-format", "File does not start with ftyp");
      }
      majorBrand = fourcc(await reader.read(box.start, 4), 0);
      if (majorBrand === QUICKTIME_BRAND) {
        throw new Mp4Error("unsupported-format", "QuickTime files are not MP4");
      }
    } else if (box.type === "moov") {
      moov = box;
      break;
    }
    offset = box.end;
  }
  if (!majorBrand) throw new Mp4Error("unsupported-format", "No ftyp box");
  if (!moov) throw new Mp4Error("unsupported-format", "No moov box");

  let durationSeconds: number | null = null;
  let videoCodec: string | null = null;
  for await (const box of children(reader, moov)) {
    if (box.type === "mvhd" && box.end - box.start >= 20) {
      const mvhd = await reader.read(box.start, 32);
      const version = mvhd[0];
      const timescale = version === 1 ? u32(mvhd, 20) : u32(mvhd, 12);
      const duration = version === 1 ? u64(mvhd, 24) : u32(mvhd, 16);
      if (timescale > 0 && duration > 0) durationSeconds = duration / timescale;
    } else if (box.type === "trak") {
      videoCodec = await videoCodecOf(reader, box);
      if (videoCodec) break;
    }
  }
  if (!videoCodec) throw new Mp4Error("unsupported-format", "No video track");
  if (!H264_CODECS.has(videoCodec)) {
    throw new Mp4Error("not-h264", `Video codec ${videoCodec} is not H.264`);
  }
  return { majorBrand, videoCodec, durationSeconds };
}
