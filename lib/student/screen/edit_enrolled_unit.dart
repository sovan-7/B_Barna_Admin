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
          // Both were force-unwrapped, so a dialog opened before the
          // subject had loaded took the app down.
          if (subjectCode == null || studentId == null) {
            Navigator.pop(context);
            return;
          }

          await studentVM.updateEditUnitCourse(subjectCode);
          await studentVM.getEnrolledCourseList(studentId);
          if (context.mounted) Navigator.pop(context);
        },
      );
    });
  }
}
