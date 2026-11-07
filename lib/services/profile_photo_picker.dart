import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';

class ProfilePhotoPicker {
  ProfilePhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<Uint8List?> pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    if (await image.length() > 10 * 1024 * 1024) {
      throw const FormatException('photo-too-large');
    }
    return prepare(await image.readAsBytes());
  }

  /// Decode actual pixels and normalize the format without EXIF metadata.
  static Future<Uint8List> prepare(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('invalid-photo');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          final longest = width > height ? width : height;
          if (longest <= 1024) {
            return ui.TargetImageSize(width: width, height: height);
          }
          final scale = 1024 / longest;
          return ui.TargetImageSize(
            width: (width * scale).round().clamp(1, 1024),
            height: (height * scale).round().clamp(1, 1024),
          );
        },
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null || png.lengthInBytes >= 5 * 1024 * 1024) {
        throw const FormatException('photo-too-large');
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      // instantiateImageCodecWithSize disposes the input buffer.
    }
  }
}
