import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Course page (one responsive form for both; the screens in
/// `course/screen/` just choose the mode).
///
/// Sections: details (code, priority, name, description), image, and
/// availability (shown in app / locked).
class CourseForm extends StatefulWidget {
  /// The course being edited; null means "Add".
  final CourseModel? existing;
  const CourseForm({this.existing, super.key});

  /// True when editing an existing course.
  bool get isEdit => existing != null;

  @override
  State<CourseForm> createState() => _CourseFormState();
}

/// The fields that can carry an inline error.
enum _Field { code, name, priority, image }

class _CourseFormState extends State<CourseForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// Text of the description field.
  final TextEditingController descriptionController = TextEditingController();

  /// Text of the display priority field.
  final TextEditingController priorityController = TextEditingController();

  /// Newly picked image (null until one is chosen) and its file name.
  Uint8List? selectedImageBytes;

  /// File name of the newly picked file.
  String imageName = "";

  /// "Show in the app" switch.
  bool willDisplay = false;

  /// "Locked" switch.
  bool isLocked = false;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field. Filled on a failed submit, then refreshed on
  /// every change so each message disappears as its field is fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final CourseModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      nameController.text = existing.name;
      descriptionController.text =
          existing.description == stringDefault ? "" : existing.description;
      priorityController.text = existing.displayPriority.toString();
      willDisplay = existing.willDisplay;
      isLocked = existing.isLocked;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    priorityController.dispose();
    super.dispose();
  }

  // ---- Validation -----------------------------------------------------

  /// Checks every field and returns the problems (empty when valid).
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the course a code";
    }
    if (nameController.text.trim().isEmpty) {
      errors[_Field.name] = "Give the course a name";
    }
    final String priority = priorityController.text.trim();
    if (priority.isEmpty) {
      errors[_Field.priority] = "Set a display priority";
    } else if (int.tryParse(priority) == null) {
      errors[_Field.priority] = "Priority must be a whole number";
    }
    // An image is only mandatory when creating: an edit keeps the one the
    // course already has.
    if (!widget.isEdit && selectedImageBytes == null) {
      errors[_Field.image] = "Choose a course image";
    }
    return errors;
  }

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the user is still filling the form).
  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  /// Opens the file picker for an image.
  Future<void> _pickImage() async {
    final FilePickerResult? picked =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || !mounted) return;
    setState(() {
      selectedImageBytes = picked.files.first.bytes;
      imageName = picked.files.first.name;
    });
    _revalidate();
  }

  /// Validates, then creates or updates the course. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(CourseViewModel courseViewModel) async {
    final Map<_Field, String> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      Helper.showSnackBarMessage(
          msg: errors.length == 1
              ? "Check the highlighted field"
              : "Check the ${errors.length} highlighted fields",
          isSuccess: false);
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });

    final CourseModel model = CourseModel(
      codeController.text.trim().toUpperCase(),
      descriptionController.text.trim(),
      nameController.text.trim(),
      widget.existing?.image ?? "",
      int.parse(priorityController.text.trim()),
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      willDisplay,
      isLocked,
    );

    final bool success = widget.isEdit
        ? await courseViewModel.updateCourse(model, widget.existing!.docId,
            image: selectedImageBytes)
        : await courseViewModel.createCourse(model, selectedImageBytes!);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Course updated successfully"
              : "Course added successfully",
          isSuccess: true);
      Navigator.pop(context, true);
    }
  }

  /// Asks for confirmation, deletes the course and closes the page.
  void _onDelete(CourseViewModel courseViewModel) {
    final CourseModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await courseViewModel.deleteCourse(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Course deleted successfully");
          Navigator.pop(context, true);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Courses",
      sidebarIndex: 1,
      body: (context, width) => Consumer<CourseViewModel>(
        builder: (context, courseViewModel, child) =>
            _page(courseViewModel, width),
      ),
    );
  }

  /// The scrolling form (header + three sections) and the action bar.
  Widget _page(CourseViewModel courseViewModel, double width) {
    return FormPageBody(
      width: width,
      actionBar: FormActionBar(
        width: width,
        isSaving: _isSaving,
        onDelete: widget.isEdit ? () => _onDelete(courseViewModel) : null,
        deleteTooltip: "Delete course",
        saveKey: const Key('course_save_button'),
        saveLabel: widget.isEdit ? "Update course" : "Save course",
        onSave: () => _onSubmit(courseViewModel),
      ),
      children: [
        FormPageHeader(
          title: widget.isEdit ? "Edit course" : "Add a course",
          subtitle: widget.isEdit
              ? "Update this course's details and availability."
              : "Courses are the top level of the catalogue.",
          onBack: _isSaving ? null : () => Navigator.pop(context),
        ),
        const SizedBox(height: AppTokens.gapLg),
        _detailsSection(width),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "COURSE IMAGE", children: [
          FormImagePickerField(
            bytes: selectedImageBytes,
            fileName: imageName,
            existingUrl: widget.existing?.image ?? "",
            error: _errors[_Field.image],
            enabled: !_isSaving,
            onPick: _pickImage,
            onRemove: () => setState(() {
              selectedImageBytes = null;
              imageName = "";
            }),
          ),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        _availabilitySection(),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Code, display priority, name and description.
  Widget _detailsSection(double width) {
    return FormSection(title: "COURSE DETAILS", children: [
      FormTwoUp(
        width: width,
        left: _textField(
          label: "Course code",
          hint: "e.g. PHY-11",
          controller: codeController,
          error: _errors[_Field.code],
          onChanged: _revalidate,
          uppercase: true,
        ),
        right: _textField(
          label: "Display priority",
          hint: "Lower numbers come first",
          controller: priorityController,
          error: _errors[_Field.priority],
          onChanged: _revalidate,
          numeric: true,
        ),
      ),
      const SizedBox(height: AppTokens.gapMd),
      _textField(
        label: "Course name",
        hint: "e.g. Physics — Class 11",
        controller: nameController,
        error: _errors[_Field.name],
        onChanged: _revalidate,
      ),
      const SizedBox(height: AppTokens.gapMd),
      _textField(
        label: "Description",
        hint: "What does this course cover? (optional)",
        controller: descriptionController,
        maxLines: 4,
      ),
    ]);
  }

  /// "Show in the app" and "Locked" switches.
  Widget _availabilitySection() {
    return FormSection(title: "AVAILABILITY", children: [
      FormToggleRow(
        title: "Show in the app",
        subtitle:
            "Hidden courses stay in the catalogue but students never see them.",
        value: willDisplay,
        onChanged:
            _isSaving ? null : (value) => setState(() => willDisplay = value),
      ),
      const FormToggleDivider(),
      FormToggleRow(
        title: "Locked",
        subtitle:
            "Students can see a locked course but cannot open its content.",
        value: isLocked,
        onChanged:
            _isSaving ? null : (value) => setState(() => isLocked = value),
      ),
    ]);
  }

  /// A [FormTextField] configured the way this form's fields need:
  /// [numeric] allows digits only, [uppercase] upper-cases as you type.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? error,
    VoidCallback? onChanged,
    bool numeric = false,
    bool uppercase = false,
  }) {
    return FormTextField(
      label: label,
      hint: hint,
      controller: controller,
      maxLines: maxLines,
      error: error,
      onChanged: onChanged,
      // This form's labels use the bolder navigation style.
      labelStyle: AppTokens.navItemSelected.copyWith(fontSize: 12.5),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.digitsOnly,
        if (uppercase) UpperCaseTextFormatter(),
      ],
    );
  }
}
