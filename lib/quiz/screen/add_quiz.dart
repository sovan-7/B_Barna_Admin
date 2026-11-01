import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/widgets/quiz_form.dart';
import 'package:flutter/material.dart';

/// Add Quiz screen — the shared [QuizForm] in "add" mode, optionally
/// prefilled from [copyOf] (Duplicate).
class AddQuiz extends StatelessWidget {
  /// The quiz to duplicate, or null for a blank form.
  final QuizModel? copyOf;
  const AddQuiz({this.copyOf, super.key});

  @override
  Widget build(BuildContext context) => QuizForm(copyOf: copyOf);
}
