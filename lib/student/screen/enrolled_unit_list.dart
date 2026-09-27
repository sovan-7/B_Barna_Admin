import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/student/widgets/unit_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Picks which units of a subject a student gets when enrolling them.
///
/// The selection is read back by the settings screen when it saves the
/// enrolment, so this dialog only closes — there is nothing to write yet.
class EnrolledUnitList extends StatelessWidget {
  const EnrolledUnitList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentViewModel>(builder: (context, studentVM, child) {
      return UnitPickerDialog(
        title: "Choose units",
        subtitle: "They are saved with the enrolment.",
        units: studentVM.unitList,
        selection: studentVM.selectedUnitList,
        onToggle: studentVM.updateCheckList,
        onToggleAll: studentVM.setAllCheckList,
        saveLabel: "Done",
        isLoading: studentVM.unitOptions.isLoading,
        loadError: studentVM.unitOptions.error,
        onRetry: studentVM.unitOptions.retry,
        onSave: () => Navigator.pop(context),
      );
    });
  }
}
