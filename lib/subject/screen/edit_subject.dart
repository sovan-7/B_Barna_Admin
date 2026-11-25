import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/widgets/subject_form.dart';
import 'package:flutter/material.dart';

/// Edit Subject screen — the shared [SubjectForm] pre-populated with
/// [subjectData]; also offers Delete.
class EditSubject extends StatelessWidget {
  /// The item being edited.
  final SubjectModel subjectData;
  const EditSubject({required this.subjectData, super.key});

  @override
  Widget build(BuildContext context) => SubjectForm(existing: subjectData);
}
