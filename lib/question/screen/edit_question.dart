import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/widgets/question_form.dart';
import 'package:flutter/material.dart';

/// Edit Question screen — the shared [QuestionForm] pre-populated with
/// [questionData]; also offers Delete.
class EditQuestion extends StatelessWidget {
  /// The item being edited.
  final Question questionData;
  const EditQuestion({required this.questionData, super.key});

  @override
  Widget build(BuildContext context) => QuestionForm(existing: questionData);
}
