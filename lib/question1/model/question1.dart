import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable rewrite of `lib/question/model/question.dart`. Kept on the SAME
/// Firestore field names/collection ([question] in constant.dart) so the
/// `quiz` module (which reads this collection directly) keeps working
/// unchanged. No `isSelected` flag here — that was quiz's own UI-picking
/// state grafted onto the old model, not part of a question's data.
class Question1 {
  const Question1({
    this.docId = "",
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
  });

  final String docId;
  final String questionCode;
  final String question;
  final String questionBody;
  final String hints;
  final String solution;
  final String answer;
  final String option1;
  final String option2;
  final String option3;
  final String option4;
  final int timeStamp;

  factory Question1.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Question1(
      docId: doc.id,
      questionCode: data['question_code'] ?? stringDefault,
      question: data['question'] ?? stringDefault,
      questionBody: data['question_body'] ?? stringDefault,
      hints: data['hints'] ?? stringDefault,
      solution: data['solution'] ?? stringDefault,
      answer: data['answer'] ?? stringDefault,
      option1: data['option1'] ?? stringDefault,
      option2: data['option2'] ?? stringDefault,
      option3: data['option3'] ?? stringDefault,
      option4: data['option4'] ?? stringDefault,
      timeStamp: data['timeStamp'] ?? intDefault,
    );
  }

  /// Single source of truth for the write shape — Add/Edit screens call this
  /// instead of each hand-building their own Firestore map.
  Map<String, dynamic> toMap() => {
        'question_code': questionCode,
        'question': question,
        'question_body': questionBody,
        'option1': option1,
        'option2': option2,
        'option3': option3,
        'option4': option4,
        'hints': hints,
        'answer': answer,
        'solution': solution,
        'timeStamp': timeStamp,
      };
}
