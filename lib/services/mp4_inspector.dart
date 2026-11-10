import 'dart:typed_data';

/// Random-access read of [length] bytes starting at [offset].
typedef Mp4ReadAt = Future<Uint8List> Function(int offset, int length);

/// Result of [inspectMp4].
class Mp4Info {
  const Mp4Info({
    required this.majorBrand,
    required this.videoCodec,
    this.durationSeconds,
  });

  final String majorBrand;

  /// Sample entry type of the video track, e.g. `avc1` (H.264).
  final String videoCodec;
  final double? durationSeconds;
}

/// The file is not an H.264 MP4. [reason] is `unsupported-format` or
/// `not-h264` (the same reasons the backend returns).
class Mp4Exception implements Exception {
  const Mp4Exception(this.reason, this.message);

  final String reason;
  final String message;

  @override
  String toString() => 'Mp4Exception($reason): $message';
}

/// H.264 sample entry types.
const kH264Codecs = {'avc1', 'avc3'};

const _quickTimeBrand = 'qt  ';
const _maxMoovBytes = 64 * 1024 * 1024;
const _maxTopLevelBoxes = 64;

/// Checks that a file is an MP4 with an H.264 video track.
///
/// Only box headers and the `moov` box are read, so large videos are never
/// loaded into memory. Mirrors `functions/mp4_inspect.js`, which re-checks the
/// uploaded object on the server.
Future<Mp4Info> inspectMp4(Mp4ReadAt readAt, int fileSize) async {
  var offset = 0;
  String? majorBrand;
  Uint8List? moov;
  for (
    var index = 0;
    index < _maxTopLevelBoxes && offset + 8 <= fileSize;
    index++
  ) {
    final header = await readAt(offset, _min(16, fileSize - offset));
    if (header.length < 8) break;
    var size = _uint32(header, 0);
    final type = _fourcc(header, 4);
    var headerSize = 8;
    if (size == 1) {
      if (header.length < 16) break;
      size = _uint64(header, 8);
      headerSize = 16;
    } else if (size == 0) {
      size = fileSize - offset;
    }
    if (size < headerSize || offset + size > fileSize) {
      throw Mp4Exception('unsupported-format', 'Broken box $type at $offset');
    }

    if (index == 0) {
      if (type != 'ftyp' || size < headerSize + 4) {
        throw const Mp4Exception(
          'unsupported-format',
          'File does not start with ftyp',
        );
      }
      final ftyp = await readAt(offset + headerSize, 4);
      if (ftyp.length < 4) {
        throw const Mp4Exception('unsupported-format', 'Short ftyp box');
      }
      majorBrand = _fourcc(ftyp, 0);
      if (majorBrand == _quickTimeBrand) {
        throw const Mp4Exception(
          'unsupported-format',
          'QuickTime files are not MP4',
        );
      }
    } else if (type == 'moov') {
      final length = size - headerSize;
      if (length > _maxMoovBytes) {
        throw const Mp4Exception('unsupported-format', 'moov box is too large');
      }
      moov = await readAt(offset + headerSize, length);
      break;
    }
    offset += size;
  }

  if (majorBrand == null) {
    throw const Mp4Exception('unsupported-format', 'No ftyp box');
  }
  if (moov == null) {
    throw const Mp4Exception('unsupported-format', 'No moov box');
  }
  final (codec, duration) = _parseMoov(moov);
  if (codec == null) {
    throw const Mp4Exception('unsupported-format', 'No video track');
  }
  if (!kH264Codecs.contains(codec)) {
    throw Mp4Exception('not-h264', 'Video codec $codec is not H.264');
  }
  return Mp4Info(
    majorBrand: majorBrand,
    videoCodec: codec,
    durationSeconds: duration,
  );
}

typedef _Box = ({String type, int start, int end});

(String?, double?) _parseMoov(Uint8List bytes) {
  double? duration;
  final mvhd = _find(bytes, 0, bytes.length, 'mvhd');
  if (mvhd != null && mvhd.end - mvhd.start >= 20) {
    final version = bytes[mvhd.start];
    final base = mvhd.start + 4;
    final timescale = version == 1
        ? _uint32(bytes, base + 16)
        : _uint32(bytes, base + 8);
    final length = version == 1
        ? _uint64(bytes, base + 20)
        : _uint32(bytes, base + 12);
    if (timescale > 0 && length > 0) duration = length / timescale;
  }

  for (final trak in _children(bytes, 0, bytes.length)) {
    if (trak.type != 'trak') continue;
    final mdia = _find(bytes, trak.start, trak.end, 'mdia');
    if (mdia == null) continue;
    final hdlr = _find(bytes, mdia.start, mdia.end, 'hdlr');
    if (hdlr == null || hdlr.end - hdlr.start < 12) continue;
    if (_fourcc(bytes, hdlr.start + 8) != 'vide') continue;
    final minf = _find(bytes, mdia.start, mdia.end, 'minf');
    final stbl = minf == null
        ? null
        : _find(bytes, minf.start, minf.end, 'stbl');
    final stsd = stbl == null
        ? null
        : _find(bytes, stbl.start, stbl.end, 'stsd');
    if (stsd == null || stsd.end - stsd.start < 16) continue;
    // FullBox header (4) + entry_count (4), then the first sample entry.
    return (_fourcc(bytes, stsd.start + 12), duration);
  }
  return (null, duration);
}

List<_Box> _children(Uint8List bytes, int start, int end) {
  final boxes = <_Box>[];
  var offset = start;
  while (offset + 8 <= end) {
    var size = _uint32(bytes, offset);
    final type = _fourcc(bytes, offset + 4);
    var header = 8;
    if (size == 1) {
      if (offset + 16 > end) break;
      size = _uint64(bytes, offset + 8);
      header = 16;
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < header || offset + size > end) break;
    boxes.add((type: type, start: offset + header, end: offset + size));
    offset += size;
  }
  return boxes;
}

_Box? _find(Uint8List bytes, int start, int end, String type) {
  for (final box in _children(bytes, start, end)) {
    if (box.type == type) return box;
  }
  return null;
}

String _fourcc(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));

int _uint32(Uint8List bytes, int offset) =>
    bytes[offset] * 0x1000000 +
    ((bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3]);

int _uint64(Uint8List bytes, int offset) =>
    _uint32(bytes, offset) * 0x100000000 + _uint32(bytes, offset + 4);

int _min(int a, int b) => a < b ? a : b;
