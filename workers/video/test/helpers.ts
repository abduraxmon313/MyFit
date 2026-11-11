import type { FirestoreApi, FsDocument, FsFields, FsWrite } from "../src/firestore";
import { FirestoreAborted } from "../src/firestore";
import type { VideoBucket } from "../src/uploads";

// ------------------------------------------------------------ MP4 builder

const u32 = (value: number) => {
  const b = new Uint8Array(4);
  new DataView(b.buffer).setUint32(0, value);
  return b;
};
const ascii = (text: string) => new TextEncoder().encode(text);
const concat = (...parts: Uint8Array[]) => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
};
export const box = (type: string, ...payload: Uint8Array[]) => {
  const body = concat(...payload);
  return concat(u32(8 + body.length), ascii(type), body);
};
const fullBox = () => new Uint8Array(4);

const trak = (handler: string, codec: string, tableBytes = 0) =>
  box(
    "trak",
    box("tkhd", fullBox(), new Uint8Array(80)),
    box(
      "mdia",
      box("mdhd", fullBox(), new Uint8Array(20)),
      box("hdlr", fullBox(), u32(0), ascii(handler), new Uint8Array(13)),
      box(
        "minf",
        box(
          "stbl",
          box("stsd", fullBox(), u32(1), box(codec, new Uint8Array(78))),
          // Large sample tables follow stsd in real files.
          box("stsz", new Uint8Array(tableBytes)),
        ),
      ),
    ),
  );

export interface Mp4Options {
  brand?: string;
  codec?: string;
  moovFirst?: boolean;
  seconds?: number;
  largeMdat?: boolean;
  tableBytes?: number;
}

export function moovBox({ codec = "avc1", seconds = 90.5, tableBytes = 0 }: Mp4Options = {}) {
  const mvhd = box(
    "mvhd",
    fullBox(),
    u32(0),
    u32(0),
    u32(1000),
    u32(Math.round(seconds * 1000)),
    new Uint8Array(80),
  );
  return box("moov", mvhd, trak("soun", "mp4a", tableBytes), trak("vide", codec, tableBytes));
}

export const ftypBox = (brand = "isom") =>
  box("ftyp", ascii(brand), u32(0), ascii("isommp41"));

export function mp4(options: Mp4Options = {}): Uint8Array {
  const ftyp = ftypBox(options.brand);
  const moov = moovBox(options);
  const media = new Uint8Array(2048).fill(7);
  let mdat: Uint8Array;
  if (options.largeMdat) {
    const size = new Uint8Array(8);
    new DataView(size.buffer).setBigUint64(0, BigInt(16 + media.length));
    mdat = concat(u32(1), ascii("mdat"), size, media);
  } else {
    mdat = box("mdat", media);
  }
  return options.moovFirst ? concat(ftyp, moov, mdat) : concat(ftyp, mdat, moov);
}

export const readerFor = (bytes: Uint8Array) => async (offset: number, length: number) =>
  bytes.slice(offset, offset + length);

// ------------------------------------------------------------ Firestore fake

export class FakeDb implements FirestoreApi {
  docs = new Map<string, FsFields>();
  transactions = 0;
  rollbacks = 0;
  /** Number of upcoming transactional commits that fail with ABORTED. */
  abortCommits = 0;

  async get(path: string): Promise<FsDocument | null> {
    const fields = this.docs.get(path);
    return fields ? { id: path.split("/").pop()!, fields: { ...fields } } : null;
  }

  async lastLessonOrder(courseId: string) {
    let max = 0;
    for (const [path, fields] of this.docs) {
      const parts = path.split("/");
      if (parts.length === 4 && parts[0] === "courses" && parts[1] === courseId && parts[2] === "lessons") {
        max = Math.max(max, Number(fields.order) || 0);
      }
    }
    return max;
  }

  async beginTransaction() {
    this.transactions += 1;
    return `tx${this.transactions}`;
  }

  async rollback() {
    this.rollbacks += 1;
  }

  async commit(writes: FsWrite[], transaction?: string) {
    if (transaction && this.abortCommits > 0) {
      this.abortCommits -= 1;
      throw new FirestoreAborted("contention");
    }
    for (const write of writes) {
      const exists = this.docs.has(write.path);
      if (write.kind === "create" && exists) throw new Error(`exists ${write.path}`);
      if (write.kind === "update" && !exists) throw new Error(`missing ${write.path}`);
    }
    for (const write of writes) {
      this.docs.set(
        write.path,
        write.kind === "set" ? { ...write.fields } : { ...(this.docs.get(write.path) ?? {}), ...write.fields },
      );
    }
  }
}

// ------------------------------------------------------------- bucket fake

export class FakeBucket implements VideoBucket {
  objects = new Map<string, { bytes: Uint8Array; contentType: string }>();
  deleted: string[] = [];
  rangeReads = 0;

  put(key: string, bytes: Uint8Array, contentType = "video/mp4") {
    this.objects.set(key, { bytes, contentType });
  }

  async head(key: string) {
    const object = this.objects.get(key);
    return object ? { size: object.bytes.length, contentType: object.contentType } : null;
  }

  async readRange(key: string, offset: number, length: number) {
    this.rangeReads += 1;
    const object = this.objects.get(key);
    if (!object) throw new Error("missing");
    return object.bytes.slice(offset, offset + length);
  }

  async delete(key: string) {
    this.deleted.push(key);
    this.objects.delete(key);
  }
}
