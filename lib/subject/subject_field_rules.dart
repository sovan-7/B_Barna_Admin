import 'package:bbarna/question/import/question_import_row.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/resources/constant.dart';

/// A saved description as the HTML the rich editor opens with. Subjects
/// saved before the editor existed hold plain text, whose line breaks would
/// otherwise collapse.
String subjectDescriptionToEditorHtml(String description) {
  if (description == stringDefault) return "";
  return description.contains(RegExp(r'<[a-zA-Z/][^>]*>'))
      ? description
      : cellToHtml(description);
}

/// What the editor's [html] saves as: a cleared editor leaves empty markup
/// behind, which must not count as a description in the app.
String subjectDescriptionToSave(String html) {
  final String trimmed = html.trim();
  final bool hasContent =
      QuestionDraft.plainText(trimmed).isNotEmpty || trimmed.contains("<img");
  return hasContent ? trimmed : "";
}

/// Reads the video id out of a YouTube link, and writes it back in the one
/// form the student app's player understands.
class SubjectVideoLink {
  const SubjectVideoLink._();

  static final RegExp _pattern = RegExp(
    r'^https?://(?:(?:www|m|music)\.)?'
    r'(?:youtu\.be/|youtube(?:-nocookie)?\.com/'
    r'(?:watch\?(?:[^#]*&)?v=|shorts/|embed/|live/))'
    r'([_\-a-zA-Z0-9]{11})(?:[?&#/].*)?$',
  );

  /// The 11-character video id, or null if [link] is not a YouTube video.
  static String? idOf(String link) =>
      _pattern.firstMatch(link.trim())?.group(1);

  /// [link] as `https://www.youtube.com/watch?v=<id>`, or null if it is not
  /// a YouTube video. Any way of copying a link saves the same value.
  static String? normalize(String link) {
    final String? id = idOf(link);
    return id == null ? null : "https://www.youtube.com/watch?v=$id";
  }
}
