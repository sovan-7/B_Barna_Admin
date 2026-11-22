import 'dart:math';
import 'dart:typed_data';

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// The access types a Topic1 PDF or video can have (`pdf_type` /
/// `video_type`), the same two the PDFs and Videos modules use.
const List<String> topic1AccessTypes = ["FREE", "PAID"];

/// Upper bound of the random part of an item id: 2^31 − 1, an exact
/// integer on web and on the VM alike. (A shift such as `1 << 32` would be
/// 0 on web, where shifts are 32-bit, and `nextInt(0)` throws.)
const int _idSuffixRange = 0x7fffffff;

/// Source of the random part of item ids.
final Random _idRandom = Random();

/// A new, practically unique id for a PDF/video row or an uploaded file:
/// the current time plus a random suffix, so two rows added in the same
/// instant still differ.
String newTopic1ItemId() =>
    "${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}"
    "${_idRandom.nextInt(_idSuffixRange).toRadixString(36)}";

/// Reads a string from a Firestore map, or [fallback] when it is missing or
/// not a string.
String _string(Map<String, dynamic> map, String key, [String fallback = ""]) {
  final Object? value = map[key];
  return value is String ? value : fallback;
}

/// Reads a bool from a Firestore map, or false.
bool _bool(Map<String, dynamic> map, String key) => map[key] == true;

/// One PDF uploaded straight onto a Topic1 (an entry of `pdf_list`). Unlike
/// the PDFs module there is no code: the file lives on the topic.
class Topic1Pdf {
  /// Stable id of this entry (`id`), used to key its row on screen.
  final String id;

  /// Display title (`pdf_title`).
  final String title;

  /// Name of the uploaded file, shown to the admin (`pdf_name`).
  final String fileName;

  /// Download URL of the uploaded file (`pdf_link`).
  final String link;

  /// Where the file sits in Firebase Storage (`pdf_path`), so it can be
  /// removed when the entry is removed or its file replaced.
  final String storagePath;

  /// "FREE" or "PAID" (`pdf_type`).
  final String type;

  /// Whether students may save a copy (`is_downloadable`).
  final bool isDownloadable;

  const Topic1Pdf({
    required this.id,
    required this.title,
    required this.fileName,
    required this.link,
    required this.storagePath,
    required this.type,
    required this.isDownloadable,
  });

  /// The entry as stored inside `pdf_list`. Field names match the `pdf`
  /// collection's, so the student app can read either the same way.
  Map<String, dynamic> toMap() => {
        "id": id,
        "pdf_title": title,
        "pdf_name": fileName,
        "pdf_link": link,
        "pdf_path": storagePath,
        "pdf_type": type,
        "is_downloadable": isDownloadable,
      };

  /// Reads one `pdf_list` entry. [fallbackId] is used when the entry has
  /// no id of its own.
  factory Topic1Pdf.fromMap(Map<String, dynamic> map, String fallbackId) =>
      Topic1Pdf(
        id: _string(map, "id", fallbackId),
        title: _string(map, "pdf_title"),
        fileName: _string(map, "pdf_name"),
        link: _string(map, "pdf_link"),
        storagePath: _string(map, "pdf_path"),
        type: _string(map, "pdf_type", stringDefault),
        isDownloadable: _bool(map, "is_downloadable"),
      );
}

/// One YouTube video linked straight onto a Topic1 (an entry of
/// `video_list`). Unlike the Videos module there is no code.
class Topic1Video {
  /// Stable id of this entry (`id`), used to key its row on screen.
  final String id;

  /// Display title (`video_title`).
  final String title;

  /// The YouTube link, saved as `https://www.youtube.com/watch?v=<id>`
  /// (`video_link`).
  final String link;

  /// "FREE" or "PAID" (`video_type`).
  final String type;

  const Topic1Video({
    required this.id,
    required this.title,
    required this.link,
    required this.type,
  });

  /// The entry as stored inside `video_list`. Field names match the
  /// `video` collection's.
  Map<String, dynamic> toMap() => {
        "id": id,
        "video_title": title,
        "video_link": link,
        "video_type": type,
      };

  /// Reads one `video_list` entry. [fallbackId] is used when the entry has
  /// no id of its own.
  factory Topic1Video.fromMap(Map<String, dynamic> map, String fallbackId) =>
      Topic1Video(
        id: _string(map, "id", fallbackId),
        title: _string(map, "video_title"),
        link: _string(map, "video_link"),
        type: _string(map, "video_type", stringDefault),
      );
}

/// One row of the PDF editor as it stands when Save is pressed: the
/// entry's details, the file it already has (if any) and a newly picked
/// file (if any). `Topic1ViewModel.savePdfs` uploads [newBytes] and turns
/// the row into a [Topic1Pdf].
class Topic1PdfDraft {
  /// The entry's id ([Topic1Pdf.id]); new rows get a fresh one.
  final String id;

  /// Title typed in.
  final String title;

  /// "FREE" or "PAID".
  final String type;

  /// Downloadable toggle.
  final bool isDownloadable;

  /// The saved entry this row edits, or null for a new row.
  final Topic1Pdf? existing;

  /// A newly picked file, replacing [existing]'s file if there is one.
  final Uint8List? newBytes;

  /// Name of the newly picked file.
  final String? newFileName;

  const Topic1PdfDraft({
    required this.id,
    required this.title,
    required this.type,
    required this.isDownloadable,
    this.existing,
    this.newBytes,
    this.newFileName,
  });
}

/// A Topic1 (`topic1` collection): placed exactly like a topic (course ›
/// subject › unit, plus extra unit codes), with audio and quizzes attached
/// by code as on a topic — but its PDFs are uploaded onto it ([pdfList])
/// and its videos are YouTube links on it ([videoList]).
class Topic1Model {
  /// The kinds of content still attached by code.
  static const List<ContentKind> codeKinds = [
    ContentKind.audio,
    ContentKind.quiz
  ];

  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Topic code, stored upper-case (`topic_code`).
  String code = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`).
  int timeStamp = intDefault;

  /// Display name (`topic_name`).
  String name = stringDefault;

  /// Course name, copied for display (`course_name`).
  String courseName = stringDefault;

  /// Course code (`course_code`).
  String courseCode = stringDefault;

  /// Subject name, copied for display (`subject_name`).
  String subjectName = stringDefault;

  /// Subject code (`subject_code`).
  String subjectCode = stringDefault;

  /// Main unit name, copied for display (`unit_name`).
  String unitName = stringDefault;

  /// Main unit code (`unit_code`).
  String unitCode = stringDefault;

  /// Sort order in the app; lower comes first (`display_priority`).
  int displayPriority = intDefault;

  /// Attached audio codes (`audio_code_list`).
  List<String> audioCodeList = [];

  /// Attached quiz codes (`quiz_code_list`).
  List<String> quizCodeList = [];

  /// Uploaded PDFs, in display order (`pdf_list`).
  List<Topic1Pdf> pdfList = [];

  /// YouTube videos, in display order (`video_list`).
  List<Topic1Video> videoList = [];

  /// Every unit code the topic appears under, including its main one
  /// (`unitCodeList`).
  List<String> unitCodeList = [];

  /// Creates a Topic1 from the Add/Edit form values (no content).
  Topic1Model(
      this.code,
      this.name,
      this.timeStamp,
      this.courseName,
      this.courseCode,
      this.subjectName,
      this.subjectCode,
      this.unitName,
      this.unitCode,
      this.displayPriority,
      this.unitCodeList);

  /// The codes attached for audio or quizzes (the [codeKinds]).
  List<String> contentCodes(ContentKind kind) => switch (kind) {
        ContentKind.audio => audioCodeList,
        ContentKind.quiz => quizCodeList,
        ContentKind.video ||
        ContentKind.pdf =>
          throw ArgumentError("Topic1 has no ${kind.name} codes"),
      };

  /// Replaces the in-memory codes for audio or quizzes.
  void setContentCodes(ContentKind kind, List<String> codes) {
    switch (kind) {
      case ContentKind.audio:
        audioCodeList = codes;
      case ContentKind.quiz:
        quizCodeList = codes;
      case ContentKind.video:
      case ContentKind.pdf:
        throw ArgumentError("Topic1 has no ${kind.name} codes");
    }
  }

  /// How many items of each kind it holds, in the order the screens list
  /// them: PDFs, videos, audio, quizzes.
  List<(ContentKind, int)> get contentCounts => [
        (ContentKind.pdf, pdfList.length),
        (ContentKind.video, videoList.length),
        (ContentKind.audio, audioCodeList.length),
        (ContentKind.quiz, quizCodeList.length),
      ];

  /// How many pieces of content of any kind it holds.
  int get contentCount =>
      pdfList.length +
      videoList.length +
      audioCodeList.length +
      quizCodeList.length;

  /// The topic's own details — deliberately *not* its content.
  ///
  /// Editing builds a fresh model from the form, which knows nothing about
  /// the content; writing the content fields from here would wipe every
  /// PDF, video, audio and quiz. Content is written one kind at a time by
  /// the content screen, and this map is applied with `update()`, which
  /// merges — so the fields it omits are left as they are.
  Map<String, dynamic> toMap() {
    return {
      "topic_code": code.trim(),
      "topic_name": name,
      "timeStamp": timeStamp,
      "course_name": courseName,
      "course_code": courseCode,
      "subject_name": subjectName,
      "subject_code": subjectCode,
      "unit_name": unitName,
      "unit_code": unitCode,
      "display_priority": displayPriority,
      "unitCodeList": unitCodeList
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  Topic1Model.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : this.fromMap(doc.id, doc.data()!);

  /// Reads a document's [data] (split out so tests need no Firestore).
  Topic1Model.fromMap(this.docId, Map<String, dynamic> data)
      : code = data["topic_code"] ?? stringDefault,
        name = data["topic_name"] ?? stringDefault,
        timeStamp = data["timeStamp"] ?? intDefault,
        courseName = data["course_name"] ?? stringDefault,
        courseCode = data["course_code"] ?? stringDefault,
        subjectName = data["subject_name"] ?? stringDefault,
        subjectCode = data["subject_code"] ?? stringDefault,
        unitName = data["unit_name"] ?? stringDefault,
        unitCode = data["unit_code"] ?? stringDefault,
        displayPriority = data["display_priority"] ?? intDefault,
        audioCodeList = _strings(data["audio_code_list"]),
        quizCodeList = _strings(data["quiz_code_list"]),
        unitCodeList = _strings(data["unitCodeList"]),
        pdfList = [
          for (final (int i, Map<String, dynamic> entry)
              in _maps(data["pdf_list"]).indexed)
            Topic1Pdf.fromMap(entry, "pdf_$i"),
        ],
        videoList = [
          for (final (int i, Map<String, dynamic> entry)
              in _maps(data["video_list"]).indexed)
            Topic1Video.fromMap(entry, "video_$i"),
        ];

  /// A Firestore array of strings; anything else reads as empty.
  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : <String>[];

  /// A Firestore array of maps; non-map entries are skipped.
  static List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? [
          for (final Object? entry in value)
            if (entry is Map) Map<String, dynamic>.from(entry),
        ]
      : <Map<String, dynamic>>[];
}
