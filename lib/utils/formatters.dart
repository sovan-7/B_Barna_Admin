import 'package:flutter/services.dart';

/// Upper-cases text as it is typed.
///
/// Codes (course, PDF, quiz, …) are stored upper-case, so code fields show
/// them that way while typing rather than changing them silently on save.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// A file size for people: "512 B", "84 KB", "2.4 MB".
String readableFileSize(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}
