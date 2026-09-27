import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/widgets/course_form.dart';
import 'package:flutter/material.dart';

/// Edit Course screen — the shared [CourseForm] pre-populated with
/// [courseData]; also offers Delete.
class EditCourse extends StatelessWidget {
  /// The item being edited.
  final CourseModel courseData;
  const EditCourse({required this.courseData, super.key});

  @override
  Widget build(BuildContext context) => CourseForm(existing: courseData);
}
