import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A quiz (`quiz` collection): a timed set of questions, referenced by
/// their codes in [questionCodeList].
class QuizModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Quiz code, stored upper-case (`quiz_code`).
  String code = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Display name (`quiz_name`).
  String name = stringDefault;

  /// "LIVE", "UPCOMING" or "PENDING" (`quiz_status`), as the admin set it.
  /// What students see can differ: see [statusAt].
  String status = stringDefault;

  /// "FREE" or "PAID" (`quiz_type`).
  String type = stringDefault;

  /// Time limit in minutes (`total_time`).
  int totalTime = intDefault;

  /// Marks for each question (`total_marks` — the stored name predates this
  /// meaning; the student app reads that key, so it stays).
  int totalMarks = intDefault;

  /// Marks deducted per wrong answer (`number_deduction`).
  int numberDeduction = intDefault;

  /// Stored counter (`total_wrong_answer`); not edited in the admin.
  int totalWrongAnswer = intDefault;

  /// Number of questions (`total_question`).
  int totalQuestion = intDefault;

  /// Codes of the questions on the quiz, in order (`question_code_list`).
  List<String> questionCodeList = [];

  /// [status] of a quiz that is scheduled to open at [availableAt].
  static const String statusUpcoming = "UPCOMING";

  /// [status] of a quiz students can take now.
  static const String statusLive = "LIVE";

  /// When students can start an [statusUpcoming] quiz (`available_at`,
  /// epoch milliseconds — the same shape as [timeStamp] and a live class's
  /// `startTime`).
  ///
  /// Once this time is reached the quiz counts as live (see [statusAt]):
  /// nothing rewrites [status], so it opens on time with no backend job.
  /// Null for every other status, and for upcoming quizzes saved before
  /// opening times existed — the student app keeps those open.
  DateTime? availableAt;

  /// Creates a quiz from the Add/Edit form values.
  QuizModel(
      this.code,
      this.name,
      this.status,
      this.type,
      this.totalTime,
      this.timeStamp,
      this.totalMarks,
      this.numberDeduction,
      this.totalWrongAnswer,
      this.totalQuestion,
      this.questionCodeList,
      {this.availableAt});

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  ///
  /// `available_at` is always written — null unless the quiz is upcoming —
  /// because `update()` merges: leaving it out would keep an old opening
  /// time on a quiz switched to LIVE or PENDING.
  Map<String, dynamic> toMap() {
    return {
      "quiz_code": code.trim(),
      "quiz_name": name,
      "timeStamp": timeStamp,
      "quiz_status": status,
      "quiz_type": type,
      "total_time": totalTime,
      "total_marks": totalMarks,
      "number_deduction": numberDeduction,
      "total_wrong_answer": totalWrongAnswer,
      "total_question": totalQuestion,
      "question_code_list": questionCodeList,
      "available_at": isUpcoming ? availableAt?.millisecondsSinceEpoch : null,
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  QuizModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        code = doc.data()!["quiz_code"] ?? stringDefault,
        name = doc.data()!["quiz_name"] ?? stringDefault,
        type = doc.data()!["quiz_type"] ?? stringDefault,
        status = doc.data()!["quiz_status"] ?? stringDefault,
        // These are ints. They defaulted to `stringDefault` ("NA"), so a
        // document missing any one of them threw a type error on read
        // rather than falling back.
        totalTime = doc.data()!["total_time"] ?? intDefault,
        totalMarks = doc.data()!["total_marks"] ?? intDefault,
        numberDeduction = doc.data()!["number_deduction"] ?? intDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault,
        totalWrongAnswer = doc.data()!["total_wrong_answer"] ?? intDefault,
        totalQuestion = doc.data()!["total_question"] ?? intDefault,
        questionCodeList = doc.data()!["question_code_list"] == null
            ? []
            : List<String>.from(
                doc.data()!["question_code_list"].map((x) => x)),
        availableAt = _toDateTime(doc.data()!["available_at"]);

  /// True when the stored status is [statusUpcoming] (whether or not its
  /// opening time has passed).
  bool get isUpcoming => status.toUpperCase() == statusUpcoming;

  /// The status students see at [now]: an upcoming quiz whose opening time
  /// has been reached is [statusLive] (inclusive, like
  /// `LiveClassModel.statusAt`, so it is never briefly neither). Every other
  /// quiz, an upcoming one without a time included, keeps its stored
  /// status.
  String statusAt(DateTime now) {
    final DateTime? opensAt = availableAt;
    if (isUpcoming && opensAt != null && !now.isBefore(opensAt)) {
      return statusLive;
    }
    return status;
  }

  /// [statusAt] for the current time.
  String get effectiveStatus => statusAt(DateTime.now());

  /// Epoch milliseconds (what this panel writes) or a [Timestamp] (a
  /// hand-edited document); anything else reads as no time.
  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
