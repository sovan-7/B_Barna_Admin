import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/widgets/teacher_form.dart';
import 'package:flutter/material.dart';

/// Edit Teacher screen — the shared [TeacherForm] pre-populated with
/// [teacherData].
class EditTeacher extends StatelessWidget {
  /// The item being edited.
  final TeacherModel teacherData;
  const EditTeacher({required this.teacherData, super.key});

  @override
  Widget build(BuildContext context) => TeacherForm(existing: teacherData);
}
