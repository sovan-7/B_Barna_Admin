import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/extra_codes_field.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Unit page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: where it belongs (course, subject), details (including extra
/// subject codes), image and availability.
class UnitForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final UnitModel? existing;
  const UnitForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<UnitForm> createState() => _UnitFormState();
}

/// The fields that can carry an inline error.
enum _Field { course, subject, code, name, priority, image }

class _UnitFormState extends State<UnitForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// Text of the description field.
  final TextEditingController descriptionController = TextEditingController();

  /// Text of the display priority field.
  final TextEditingController priorityController = TextEditingController();

  /// Course chosen in the dropdown (by name).
  String? _selectedCourseName;

  /// Code of the chosen course.
  String _selectedCourseCode = "";

  /// Subject chosen in the dropdown (by name).
  String? _selectedSubjectName;

  /// Code of the chosen subject.
  String _selectedSubjectCode = "";

  /// Subject codes this unit also appears under. The primary subject's own
  /// code is not repeated here.
  final List<TextEditingController> _extraCodeControllers = [];

  /// Newly picked file, not uploaded yet (null until one is chosen).
  Uint8List? selectedImageBytes;

  /// File name of the newly picked file.
  String imageName = "";

  /// "Show in the app" switch.
  bool willShow = false;

  /// "Locked" switch.
  bool isLocked = false;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final UnitModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      nameController.text = existing.name;
      descriptionController.text =
          existing.description == stringDefault ? "" : existing.description;
      priorityController.text = existing.displayPriority.toString();
      _selectedCourseName =
          existing.courseName == stringDefault ? null : existing.courseName;
      _selectedCourseCode = existing.courseCode;
      _selectedSubjectName =
          existing.subjectName == stringDefault ? null : existing.subjectName;
      _selectedSubjectCode = existing.subjectCode;
      willShow = existing.willShow;
      isLocked = existing.lockStatus;
      for (final String code in existing.subjectCodeList) {
        if (code == existing.subjectCode) continue;
        _extraCodeControllers.add(TextEditingController(text: code));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final CourseViewModel courseViewModel =
          Provider.of<CourseViewModel>(context, listen: false);
      if (courseViewModel.allCourses.isEmpty) courseViewModel.getCourseList();
      // Editing starts with a course already chosen, so its subjects have
      // to be fetched before the subject picker can show anything.
      if (_selectedCourseCode.isNotEmpty) {
        Provider.of<UnitViewModel>(context, listen: false)
            .getSubjectListByCourseCode(_selectedCourseCode);
      }
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    descriptionController.dispose();
    priorityController.dispose();
    for (final TextEditingController controller in _extraCodeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // ---- Validation -----------------------------------------------------

  /// Checks every field and returns the problems (empty when valid).
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (_selectedCourseCode.isEmpty) {
      errors[_Field.course] = "Choose the course this belongs to";
    }
    if (_selectedSubjectCode.isEmpty) {
      errors[_Field.subject] = "Choose the subject this belongs to";
    }
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the unit a code";
    }
    if (nameController.text.trim().isEmpty) {
      errors[_Field.name] = "Give the unit a name";
    }
    final String priority = priorityController.text.trim();
    if (priority.isEmpty) {
      errors[_Field.priority] = "Set a display priority";
    } else if (int.tryParse(priority) == null) {
      errors[_Field.priority] = "Priority must be a whole number";
    }
    if (!widget.isEdit && selectedImageBytes == null) {
      errors[_Field.image] = "Choose a unit image";
    }
    return errors;
  }

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the form is still being filled in).
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

  /// The primary subject code first, then any extra ones — de-duplicated
  /// and with blanks dropped, so an empty extra field cannot write an
  /// empty string into the array.
  List<String> _subjectCodes() {
    final List<String> codes = [_selectedSubjectCode];
    for (final TextEditingController controller in _extraCodeControllers) {
      final String value = controller.text.trim().toUpperCase();
      if (value.isNotEmpty && !codes.contains(value)) codes.add(value);
    }
    return codes.where((code) => code.isNotEmpty).toList();
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(UnitViewModel unitViewModel) async {
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

    final UnitModel model = UnitModel(
      _selectedCourseCode,
      _selectedCourseName ?? stringDefault,
      _selectedSubjectCode,
      _selectedSubjectName ?? stringDefault,
      isLocked,
      codeController.text.trim().toUpperCase(),
      descriptionController.text.trim(),
      nameController.text.trim(),
      widget.existing?.image ?? "",
      int.parse(priorityController.text.trim()),
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      willShow,
      _subjectCodes(),
    );

    final bool success = widget.isEdit
        ? await unitViewModel.updateUnit(model, widget.existing!.id,
            image: selectedImageBytes)
        : await unitViewModel.createUnit(model, selectedImageBytes!);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Unit updated successfully"
              : "Unit added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
  void _onDelete(UnitViewModel unitViewModel) {
    final UnitModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await unitViewModel.deleteUnit(existing.id);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Unit deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Units",
      sidebarIndex: 3,
      body: (context, width) => Consumer2<UnitViewModel, CourseViewModel>(
        builder: (context, unitViewModel, courseViewModel, child) =>
            _page(unitViewModel, courseViewModel, width),
      ),
    );
  }

  /// The scrolling form (header and sections) with the action bar below.
  Widget _page(UnitViewModel unitViewModel, CourseViewModel courseViewModel,
      double width) {
    return FormPageBody(
      width: width,
      actionBar: _actionBar(unitViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "WHERE IT BELONGS", children: [
          FormTwoUp(
              width: width,
              left: _courseField(unitViewModel, courseViewModel),
              right: _subjectField(unitViewModel)),
          const SizedBox(height: AppTokens.gapMd),
          _extraCodesField(),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "UNIT DETAILS", children: [
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Unit code",
                hint: "e.g. MECH-01",
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
              )),
          const SizedBox(height: AppTokens.gapMd),
          _textField(
            label: "Unit name",
            hint: "e.g. Laws of Motion",
            controller: nameController,
            error: _errors[_Field.name],
            onChanged: _revalidate,
          ),
          const SizedBox(height: AppTokens.gapMd),
          _textField(
            label: "Description",
            hint: "What does this unit cover? (optional)",
            controller: descriptionController,
            maxLines: 4,
          ),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "UNIT IMAGE", children: [_imageField()]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "AVAILABILITY", children: [
          FormToggleRow(
            title: "Show in the app",
            subtitle:
                "Hidden units stay in the catalogue but students never see them.",
            value: willShow,
            onChanged: _isSaving ? null : (v) => setState(() => willShow = v),
          ),
          const FormToggleDivider(),
          FormToggleRow(
            title: "Locked",
            subtitle:
                "Students can see a locked unit but cannot open its topics.",
            value: isLocked,
            onChanged: _isSaving ? null : (v) => setState(() => isLocked = v),
          ),
        ]),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit unit" : "Add a unit",
      subtitle: widget.isEdit
          ? "Update this unit's details and availability."
          : "Units sit under a subject, and topics hang off them.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  // ---- Fields ---------------------------------------------------------

  /// Course dropdown.
  Widget _courseField(
      UnitViewModel unitViewModel, CourseViewModel courseViewModel) {
    final List<CourseModel> courses = courseViewModel.allCourses;
    final List<String> names =
        courses.map((c) => c.name).where((n) => n.isNotEmpty).toSet().toList();

    // A unit may name a course that has since been renamed or removed —
    // keep that value selectable so editing doesn't silently drop it.
    final String? current = _selectedCourseName;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    return _dropdownField(
      key: const Key('unit_course_dropdown'),
      label: "Course",
      hint: courseViewModel.isLoading && names.isEmpty
          ? "Loading courses…"
          : "Select a course",
      value: _selectedCourseName,
      items: names,
      error: _errors[_Field.course],
      icon: Icons.menu_book_outlined,
      onChanged: (value) {
        setState(() {
          _selectedCourseName = value;
          _selectedCourseCode = courses
                  .where((c) => c.name == value)
                  .map((c) => c.code)
                  .firstOrNull ??
              "";
          // Changing course invalidates the subject beneath it.
          _selectedSubjectName = null;
          _selectedSubjectCode = "";
        });
        if (_selectedCourseCode.isNotEmpty) {
          unitViewModel.getSubjectListByCourseCode(_selectedCourseCode);
        }
        _revalidate();
      },
    );
  }

  /// Subjects are fetched for the chosen course, so this picker stays
  /// disabled until there is a course to fetch them for.
  Widget _subjectField(UnitViewModel unitViewModel) {
    final List<SubjectModel> subjects = unitViewModel.subjectListByCourseId;
    final List<String> names =
        subjects.map((s) => s.name).where((n) => n.isNotEmpty).toSet().toList();

    final String? current = _selectedSubjectName;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    final bool enabled = _selectedCourseCode.isNotEmpty;

    return _dropdownField(
      key: const Key('unit_subject_dropdown'),
      label: "Subject",
      hint: !enabled
          ? "Choose a course first"
          : names.isEmpty
              ? "No subjects in this course"
              : "Select a subject",
      value: _selectedSubjectName,
      items: names,
      error: _errors[_Field.subject],
      icon: Icons.library_books_outlined,
      enabled: enabled,
      onChanged: (value) {
        setState(() {
          _selectedSubjectName = value;
          _selectedSubjectCode = subjects
                  .where((s) => s.name == value)
                  .map((s) => s.code)
                  .firstOrNull ??
              "";
        });
        _revalidate();
      },
    );
  }

  /// Extra subject codes, for a unit that is shared across subjects.
  Widget _extraCodesField() {
    return ExtraCodesField(
      controllers: _extraCodeControllers,
      description:
          "Extra subject codes this unit should show under. Leave empty "
          "unless the unit is shared.",
      hint: "Subject code",
      addLabel: "Add a subject code",
      keyPrefix: "unit",
      enabled: !_isSaving,
      onAdd: () =>
          setState(() => _extraCodeControllers.add(TextEditingController())),
      onRemove: (i) => setState(() {
        _extraCodeControllers[i].dispose();
        _extraCodeControllers.removeAt(i);
      }),
    );
  }

  /// A [FormTextField] configured for this form.
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
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.digitsOnly,
        if (uppercase) UpperCaseTextFormatter(),
      ],
    );
  }

  /// A [FormDropdownField] wired to this form's saving state.
  Widget _dropdownField({
    required Key key,
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? error,
    bool enabled = true,
  }) {
    return FormDropdownField(
      dropdownKey: key,
      label: label,
      hint: hint,
      value: value,
      items: items,
      icon: icon,
      onChanged: (_isSaving || !enabled) ? null : onChanged,
      error: error,
      enabled: enabled,
    );
  }

  /// Square image well with Choose / Replace / Remove.
  Widget _imageField() {
    return FormImagePickerField(
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
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(UnitViewModel unitViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(unitViewModel) : null,
      deleteTooltip: "Delete unit",
      saveKey: const Key('unit_save_button'),
      saveLabel: widget.isEdit ? "Update unit" : "Save unit",
      onSave: () => _onSubmit(unitViewModel),
      saveMinWidth: 130,
    );
  }
}
