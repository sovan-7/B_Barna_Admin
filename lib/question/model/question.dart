import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A quiz question (`question` collection). Text fields hold HTML from
/// the rich-text editors; quizzes reference questions by [questionCode].
class Question {
  /// Creates a question; every field defaults to empty.
  Question(
      {this.docId = "",
      this.questionCode = "",
      this.question = "",
      this.questionBody = "",
      this.hints = "",
      this.solution = "",
      this.answer = "",
      this.option1 = "",
      this.option2 = "",
      this.option3 = "",
      this.option4 = "",
      this.timeStamp = -1,
      this.isSelected = false});

  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Question code, stored upper-case (`question_code`).
  String questionCode = stringDefault;

  /// The question itself, as HTML (`question`).
  String question = stringDefault;

  /// Optional extra body (passage, figure) as HTML (`question_body`).
  String questionBody = stringDefault;

  /// Hint shown after answering, as HTML (`hints`).
  String hints = stringDefault;

  /// Worked solution, as HTML (`solution`).
  String solution = stringDefault;

  /// The correct option's HTML, copied from one of option1–4 (`answer`).
  String answer = stringDefault;

  /// Option A, as HTML (`option1`).
  String option1 = stringDefault;

  /// Option B, as HTML (`option2`).
  String option2 = stringDefault;

  /// Option C, as HTML (`option3`).
  String option3 = stringDefault;

  /// Option D, as HTML (`option4`).
  String option4 = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`).
  int timeStamp = intDefault;

  /// UI-only tick state for pickers; never stored.
  bool isSelected = false;

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  factory Question.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return Question(
        docId: doc.id,
        questionCode: doc.data()!['question_code'] ?? stringDefault,
        question: doc.data()!['question'] ?? stringDefault,
        questionBody: doc.data()!['question_body'] ?? stringDefault,
        hints: doc.data()!['hints'] ?? stringDefault,
        solution: doc.data()!['solution'] ?? stringDefault,
        answer: doc.data()!['answer'] ?? stringDefault,
        option1: doc.data()!['option1'] ?? stringDefault,
        option2: doc.data()!['option2'] ?? stringDefault,
        option3: doc.data()!['option3'] ?? stringDefault,
        option4: doc.data()!['option4'] ?? stringDefault,
        timeStamp: doc.data()!['timeStamp'] ?? intDefault,
        isSelected: false);
  }
}
