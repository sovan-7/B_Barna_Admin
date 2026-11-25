import 'package:bbarna/subject/subject_field_rules.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';

// Turning old topics (`topic` collection, the Topics module) into New
// Topics (`topics` collection), for the one-time copy in
// `Topic1Repo.copyFromTopics`. Kept free of Firestore so it can be tested
// on plain maps.

/// The fields an old topic shares with a New Topic, copied as they are:
/// its placement, order, and the audio/quiz codes (which New Topics still
/// attaches by code).
const List<String> _sharedFields = [
  "topic_code",
  "topic_name",
  "timeStamp",
  "course_name",
  "course_code",
  "subject_name",
  "subject_code",
  "unit_name",
  "unit_code",
  "display_priority",
  "unitCodeList",
  "audio_code_list",
  "quiz_code_list",
];

/// A topic code as the copy compares it: trimmed and upper-case, or "" when
/// there is none.
String topicCodeKey(Object? code) =>
    code is String ? code.trim().toUpperCase() : "";

/// The non-blank codes in a stored code list (`pdf_code_list`, …), trimmed,
/// in order. Anything that is not a list of strings reads as no codes.
List<String> storedCodes(Object? raw) => raw is List
    ? [
        for (final Object? code in raw)
          if (code is String && code.trim().isNotEmpty) code.trim(),
      ]
    : const [];

/// The ids of the [oldTopics] (`id -> data`, in their order) to copy.
///
/// An old topic is skipped when `topics` already has a document with its
/// id (it was copied before) or a topic with its code (made by hand, or an
/// earlier old topic with the same code in this run), so running the copy
/// again copies nothing twice and never overwrites what is in `topics`.
/// Topics without a code are matched on id only.
List<String> oldTopicIdsToCopy(
  Map<String, Map<String, dynamic>> oldTopics, {
  required Set<String> existingIds,
  required Set<String> existingCodes,
}) {
  final Set<String> codes = {...existingCodes}..remove("");
  final List<String> ids = [];
  oldTopics.forEach((String id, Map<String, dynamic> data) {
    if (existingIds.contains(id)) return;
    final String code = topicCodeKey(data["topic_code"]);
    if (code.isNotEmpty && !codes.add(code)) return;
    ids.add(id);
  });
  return ids;
}

/// One old topic as a New Topic, and how many of its PDFs and videos could
/// not come along.
typedef ConvertedTopic = ({Map<String, dynamic> data, int leftOut});

/// Converts the old topic [old] into a New Topic document.
///
/// The [_sharedFields] are copied as they are. The PDFs and videos it
/// attached by code are looked up in [pdfByCode] / [videoByCode] (`code ->`
/// that document's data) and stored on the topic, in the same order:
///
/// * a PDF keeps its title, link, access type and downloadable flag; its
///   file name shows its code, and it gets **no** Storage path: the file
///   still belongs to the PDFs module, and New Topics deletes only files
///   that have a path, so editing or deleting the New Topic never removes
///   it;
/// * a video keeps its title and access type, with its link saved in the
///   one YouTube form New Topics uses.
///
/// Left out (and counted in `leftOut`): codes with no document, PDFs with
/// no link, PDFs marked `is_locked` (New Topics cannot lock a PDF, so
/// copying it would let students open it), and videos whose link is not a
/// YouTube video (the only kind New Topics plays).
///
/// [newId] makes each entry's id; tests pass a predictable one.
ConvertedTopic newTopicFromOld(
  Map<String, dynamic> old, {
  required Map<String, Map<String, dynamic>> pdfByCode,
  required Map<String, Map<String, dynamic>> videoByCode,
  String Function() newId = newTopic1ItemId,
}) {
  int leftOut = 0;

  final List<Map<String, dynamic>> pdfs = [];
  for (final String code in storedCodes(old["pdf_code_list"])) {
    final Map<String, dynamic>? doc = pdfByCode[code];
    final Object? link = doc?["pdf_link"];
    if (doc == null ||
        doc["is_locked"] == true ||
        link is! String ||
        link.trim().isEmpty) {
      leftOut++;
      continue;
    }
    pdfs.add(Topic1Pdf.fromMap(
      {...doc, "id": newId(), "pdf_name": code, "pdf_path": ""},
      "",
    ).toMap());
  }

  final List<Map<String, dynamic>> videos = [];
  for (final String code in storedCodes(old["video_code_list"])) {
    final Map<String, dynamic>? doc = videoByCode[code];
    final Object? link = doc?["video_link"];
    final String? youtube =
        link is String ? SubjectVideoLink.normalize(link) : null;
    if (doc == null || youtube == null) {
      leftOut++;
      continue;
    }
    videos.add(Topic1Video.fromMap(
      {...doc, "id": newId(), "video_link": youtube},
      "",
    ).toMap());
  }

  return (
    data: {
      for (final String field in _sharedFields)
        if (old.containsKey(field)) field: old[field],
      "pdf_list": pdfs,
      "video_list": videos,
    },
    leftOut: leftOut,
  );
}
