import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/widgets/quiz_form.dart';
import 'package:flutter/material.dart';

/// Edit Quiz screen — the shared [QuizForm] pre-populated with [quizData];
/// also offers Delete.
class EditQuiz extends StatelessWidget {
  /// The item being edited.
  final QuizModel quizData;
  const EditQuiz({required this.quizData, super.key});

  @override
  Widget build(BuildContext context) => QuizForm(existing: quizData);
}
