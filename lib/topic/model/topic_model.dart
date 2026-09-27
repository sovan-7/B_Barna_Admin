import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A kind of content a topic can have attached (video, audio, PDF, quiz),
/// with the Firestore names for each defined once in [ContentKindData] so
/// the screen, view model and repo always agree on them.
enum ContentKind { video, audio, pdf, quiz }

/// Firestore names and UI labels for each [ContentKind].
extension ContentKindData on ContentKind {
  /// The array field on the topic document.
  String get field => switch (this) {
        ContentKind.video => "video_code_list",
        ContentKind.audio => "audio_code_list",
        ContentKind.pdf => "pdf_code_list",
        ContentKind.quiz => "quiz_code_list",
      };

  /// The collection the codes point into.
  String get collection => switch (this) {
        ContentKind.video => video,
        ContentKind.audio => audio,
        ContentKind.pdf => pdf,
        ContentKind.quiz => quiz,
      };

  /// The code field on that collection's documents.
  String get codeField => switch (this) {
        ContentKind.video => "video_code",
        ContentKind.audio => "audio_code",
        ContentKind.pdf => "pdf_code",
        ContentKind.quiz => "quiz_code",
      };

  /// The human-readable field on that collection's documents. Quizzes call
  /// theirs `quiz_name`; the other three call theirs `*_title`.
  String get titleField => switch (this) {
        ContentKind.video => "video_title",
        ContentKind.audio => "audio_title",
        ContentKind.pdf => "pdf_title",
        ContentKind.quiz => "quiz_name",
      };

  /// Capitalised label, e.g. "Video".
  String get label => switch (this) {
        ContentKind.video => "Video",
        ContentKind.audio => "Audio",
        ContentKind.pdf => "PDF",
        ContentKind.quiz => "Quiz",
      };

  /// The label as it reads mid-sentence. PDF is an acronym, so it does not
  /// lowercase the way the other three do.
  String get inlineLabel =>
      this == ContentKind.pdf ? "PDF" : label.toLowerCase();
}

/// A topic (`topic` collection): sits under a unit (and optionally more,
/// see [unitCodeList]); videos, audio, PDFs and quizzes are attached to it
/// by code.
class TopicModel {
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

  /// Attached video codes (`video_code_list`).
  List<String> videoCodeList = [];

  /// Attached PDF codes (`pdf_code_list`).
  List<String> pdfCodeList = [];

  /// Every unit code the topic appears under, including its main one
  /// (`unitCodeList`).
  List<String> unitCodeList = [];

  /// Creates a topic from the Add/Edit form values (no attached content).
  TopicModel(
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

  /// The codes attached for one kind of content.
  List<String> contentCodes(ContentKind kind) => switch (kind) {
        ContentKind.video => videoCodeList,
        ContentKind.audio => audioCodeList,
        ContentKind.pdf => pdfCodeList,
        ContentKind.quiz => quizCodeList,
      };

  /// Replaces the in-memory codes for one kind of content.
  void setContentCodes(ContentKind kind, List<String> codes) {
    switch (kind) {
      case ContentKind.video:
        videoCodeList = codes;
      case ContentKind.audio:
        audioCodeList = codes;
      case ContentKind.pdf:
        pdfCodeList = codes;
      case ContentKind.quiz:
        quizCodeList = codes;
    }
  }

  /// How many pieces of content of any kind are attached.
  int get contentCount =>
      videoCodeList.length +
      audioCodeList.length +
      pdfCodeList.length +
      quizCodeList.length;

  /// The topic's own details — deliberately *not* the four content arrays.
  ///
  /// Editing a topic builds a fresh model from the form, which knows
  /// nothing about attached content; writing the arrays from here would
  /// send four empty lists and detach every video, audio, PDF and quiz on
  /// the topic. The content arrays are owned by the content screen and
  /// written one at a time through `TopicRepo.setContentCodes`, and this
  /// map is applied with `update()`, which merges — so the fields it omits
  /// are left exactly as they are.
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
  TopicModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        code = doc.data()!["topic_code"] ?? stringDefault,
        name = doc.data()!["topic_name"] ?? stringDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault,
        courseName = doc.data()!["course_name"] ?? stringDefault,
        courseCode = doc.data()!["course_code"] ?? stringDefault,
        subjectName = doc.data()!["subject_name"] ?? stringDefault,
        subjectCode = doc.data()!["subject_code"] ?? stringDefault,
        unitName = doc.data()!["unit_name"] ?? stringDefault,
        unitCode = doc.data()!["unit_code"] ?? stringDefault,
        displayPriority = doc.data()!["display_priority"] ?? intDefault,
        audioCodeList = doc.data()!["audio_code_list"] == null
            ? []
            : List<String>.from(doc.data()!["audio_code_list"].map((x) => x)),
        videoCodeList = doc.data()!["video_code_list"] == null
            ? []
            : List<String>.from(doc.data()!["video_code_list"].map((x) => x)),
        pdfCodeList = doc.data()!["pdf_code_list"] == null
            ? []
            : List<String>.from(doc.data()!["pdf_code_list"].map((x) => x)),
        quizCodeList = doc.data()!["quiz_code_list"] == null
            ? []
            : List<String>.from(doc.data()!["quiz_code_list"].map((x) => x)),
        unitCodeList = doc.data()!["unitCodeList"] == null
            ? []
            : List<String>.from(doc.data()!["unitCodeList"].map((x) => x));
}
