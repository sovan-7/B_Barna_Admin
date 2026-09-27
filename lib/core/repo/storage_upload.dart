import 'dart:typed_data';

import 'package:bbarna/utils/image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Content type used when the file type is not detected.
const String jpegContentType = "image/jpeg";

/// Browser / CDN cache lifetime for uploaded files. Each stored file keeps
/// its path, but a replaced file gets a new download token (a new URL), so
/// a long cache never serves an outdated picture.
const String _cacheControl = "public, max-age=31536000";

/// Uploads [data] to [reference] in Firebase Storage and returns its public
/// download URL.
///
/// Throws on failure (it never swallows errors), so the caller can roll
/// back and tell the admin the save did not work.
Future<String> uploadToStorage(
  Reference reference,
  Uint8List data, {
  required String contentType,
}) async {
  await reference.putData(
    data,
    SettableMetadata(contentType: contentType, cacheControl: _cacheControl),
  );
  return reference.getDownloadURL();
}

/// Shrinks a picture to at most [maxSide] pixels on its longest side (see
/// [prepareImageForUpload]) and uploads it with the matching content type.
/// Returns the download URL.
Future<String> uploadImageToStorage(
  Reference reference,
  Uint8List data, {
  required int maxSide,
}) async {
  final PreparedImage image =
      await prepareImageForUpload(data, maxSide: maxSide);
  return uploadToStorage(reference, image.bytes,
      contentType: image.contentType);
}
