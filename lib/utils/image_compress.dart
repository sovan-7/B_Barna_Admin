import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Longest side, in pixels, that pictures are stored at.
class ImageSizes {
  const ImageSizes._();

  /// Course / subject / unit / teacher pictures (shown as thumbnails).
  static const int thumbnail = 800;

  /// Home-carousel banners (shown full width).
  static const int banner = 1920;
}

/// An image ready to upload, with the content type that matches its bytes.
class PreparedImage {
  final Uint8List bytes;

  /// e.g. `image/jpeg`, `image/png`.
  final String contentType;

  const PreparedImage(this.bytes, this.contentType);
}

/// Above this size the work runs on a background isolate so the window
/// stays responsive (on web it always runs inline).
const int _isolateThreshold = 200 * 1024;

/// Shrinks a picked image before upload: scales it down so its longest side
/// is at most [maxSide] and re-encodes it — JPEG at [quality], or PNG when
/// the image has transparency (JPEG would turn it black).
///
/// The original bytes are kept when they cannot be decoded, or when the
/// result would not be smaller.
Future<PreparedImage> prepareImageForUpload(
  Uint8List bytes, {
  required int maxSide,
  int quality = 85,
}) async {
  final _Job job = _Job(bytes, maxSide, quality);
  if (kIsWeb || bytes.lengthInBytes < _isolateThreshold) return _prepare(job);
  return compute(_prepare, job);
}

/// Input for [_prepare] (one object, so it can cross to an isolate).
class _Job {
  final Uint8List bytes;
  final int maxSide;
  final int quality;

  const _Job(this.bytes, this.maxSide, this.quality);
}

PreparedImage _prepare(_Job job) {
  final PreparedImage original =
      PreparedImage(job.bytes, sniffImageContentType(job.bytes));

  // The decoder throws on some malformed input rather than returning null.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(job.bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) return original;

  img.Image image = decoded;
  final int longest = math.max(image.width, image.height);
  if (longest > job.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image,
            width: job.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image,
            height: job.maxSide, interpolation: img.Interpolation.average);
  }

  final bool transparent = image.hasAlpha && _hasTransparentPixel(image);
  final PreparedImage encoded = transparent
      ? PreparedImage(Uint8List.fromList(img.encodePng(image)), "image/png")
      : PreparedImage(
          Uint8List.fromList(img.encodeJpg(image, quality: job.quality)),
          "image/jpeg");

  return encoded.bytes.lengthInBytes < job.bytes.lengthInBytes
      ? encoded
      : original;
}

/// Whether any pixel is not fully opaque (an alpha channel alone does not
/// mean the picture uses it).
bool _hasTransparentPixel(img.Image image) {
  for (final img.Pixel pixel in image) {
    if (pixel.a < pixel.maxChannelValue) return true;
  }
  return false;
}

/// Content type from the file's first bytes (defaults to JPEG).
String sniffImageContentType(Uint8List bytes) {
  bool starts(List<int> sig) =>
      bytes.length >= sig.length &&
      List<int>.generate(sig.length, (i) => bytes[i]).join(',') ==
          sig.join(',');
  if (starts(const [0x89, 0x50, 0x4E, 0x47])) return "image/png";
  if (starts(const [0x47, 0x49, 0x46])) return "image/gif";
  if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == "WEBP") {
    return "image/webp";
  }
  return "image/jpeg";
}
