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

  /// "LIVE", "UPCOMING" or "PENDING" (`quiz_status`).
  String status = stringDefault;

  /// "FREE" or "PAID" (`quiz_type`).
  String type = stringDefault;

  /// Time limit in minutes (`total_time`).
  int totalTime = intDefault;

  /// Maximum marks (`total_marks`).
  int totalMarks = intDefault;

  /// Marks deducted per wrong answer (`number_deduction`).
  int numberDeduction = intDefault;

  /// Stored counter (`total_wrong_answer`); not edited in the admin.
  int totalWrongAnswer = intDefault;

  /// Number of questions (`total_question`).
  int totalQuestion = intDefault;

  /// Codes of the questions on the quiz, in order (`question_code_list`).
  List<String> questionCodeList = [];

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
      this.questionCodeList);

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
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
      "question_code_list": questionCodeList
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
                doc.data()!["question_code_list"].map((x) => x));
}
