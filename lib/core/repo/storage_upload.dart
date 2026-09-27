import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Content type used for every uploaded picture.
const String jpegContentType = "image/jpeg";

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
  await reference.putData(data, SettableMetadata(contentType: contentType));
  return reference.getDownloadURL();
}
