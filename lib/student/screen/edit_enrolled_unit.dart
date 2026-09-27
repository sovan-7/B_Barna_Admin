import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/student/widgets/unit_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Edits which units of an already-enrolled subject a student can reach.
class EditEnrolledUnit extends StatelessWidget {
  const EditEnrolledUnit({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentViewModel>(builder: (context, studentVM, child) {
      return UnitPickerDialog(
        title: "Edit units",
        subtitle: studentVM.selectedSubjectModel?.subjectName,
        units: studentVM.selectedEditUnitList,
        selection: studentVM.editedUnitList,
        // This read `selectedUnitList` — the *add* flow's list — to decide
        // between "Select All" and "Remove All", so the label described a
        // different screen's state.
        onToggle: studentVM.updateEditedCheckList,
        onToggleAll: studentVM.updateEditedUnitList,
        saveLabel: "Save units",
        onSave: () async {
          final String? subjectCode =
              studentVM.selectedSubjectModel?.subjectCode;
          final String? studentId =
              studentVM.enrolledCourseBaseModel?.studentId;
          // The subject or student may not have loaded yet; close instead of
          // crashing.
          if (subjectCode == null || studentId == null) {
            Navigator.pop(context);
            return;
          }

          // The enrolment is updated in place; reload only if the save
          // failed, to put back what is actually stored.
          final bool saved = await studentVM.updateEditUnitCourse(subjectCode);
          if (!saved) await studentVM.getEnrolledCourseList(studentId);
          if (context.mounted) Navigator.pop(context);
        },
      );
    });
  }
}
