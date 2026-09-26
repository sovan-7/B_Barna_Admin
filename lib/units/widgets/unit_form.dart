import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_form.dart' show UpperCaseTextFormatter;
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The whole Add/Edit Unit page. [existing] null means Add.
///
/// Add and Edit were two 841 and 904 line screens that each contained the
/// same form written out twice — once for wide windows and once for narrow
/// — so every field existed in four places. There is one responsive form
/// here, and the two screens in `screen/` just choose the mode.
class UnitForm extends StatefulWidget {
  final UnitModel? existing;
  const UnitForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<UnitForm> createState() => _UnitFormState();
}

/// The fields that can carry an inline error.
enum _Field { course, subject, code, name, priority, image }

class _UnitFormState extends State<UnitForm> {
  final GlobalKey<ScaffoldState> key = GlobalKey();

  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();

  String? _selectedCourseName;
  String _selectedCourseCode = "";
  String? _selectedSubjectName;
  String _selectedSubjectCode = "";

  /// Subject codes this unit also appears under. The primary subject's own
  /// code is not repeated here.
  final List<TextEditingController> _extraCodeControllers = [];

  Uint8List? selectedImageBytes;
  String imageName = "";
  bool willShow = false;
  bool isLocked = false;
  bool _isSaving = false;

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

  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (_selectedCourseCode.isEmpty) {
      errors[_Field.course] = "Choose the course this belongs to";
    }
    if (_selectedSubjectCode.isEmpty) {
      errors[_Field.subject] = "Choose the subject this belongs to";
    }
    if (codeController.text.trim().isEmpty) {
      // These messages used to say "topic code" and "topic name" — copied
      // from the topic module and never corrected.
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

  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

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
    final double width = MediaQuery.of(context).size.width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return Scaffold(
      key: key,
      backgroundColor: AppTokens.canvas,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Column(
          children: [
            AppHeader(
              onTapIcon: () => key.currentState?.openDrawer(),
              title: "Units",
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isCompact)
                    const Expanded(child: ExtraSideBar(sidebarIndex: 3)),
                  Expanded(
                    flex: 5,
                    child: Consumer2<UnitViewModel, CourseViewModel>(
                      builder: (context, unitViewModel, courseViewModel,
                              child) =>
                          _page(unitViewModel, courseViewModel, width),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer:
          isCompact ? const Drawer(child: ExtraSideBar(sidebarIndex: 3)) : null,
    );
  }

  Widget _page(UnitViewModel unitViewModel, CourseViewModel courseViewModel,
      double width) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: width < 700 ? 16 : 32, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: AppTokens.gapLg),
                    _section(title: "WHERE IT BELONGS", children: [
                      _twoUp(
                        width,
                        _courseField(unitViewModel, courseViewModel),
                        _subjectField(unitViewModel),
                      ),
                      const SizedBox(height: AppTokens.gapMd),
                      _extraCodesField(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "UNIT DETAILS", children: [
                      _twoUp(
                        width,
                        _textField(
                          label: "Unit code",
                          hint: "e.g. MECH-01",
                          controller: codeController,
                          error: _errors[_Field.code],
                          onChanged: _revalidate,
                          uppercase: true,
                        ),
                        _textField(
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
                    _section(title: "UNIT IMAGE", children: [_imageField()]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "AVAILABILITY", children: [
                      _toggleRow(
                        title: "Show in the app",
                        subtitle:
                            "Hidden units stay in the catalogue but students never see them.",
                        value: willShow,
                        onChanged: (v) => setState(() => willShow = v),
                      ),
                      const Divider(
                          height: AppTokens.gapLg,
                          thickness: 1,
                          color: AppTokens.hairline),
                      _toggleRow(
                        title: "Locked",
                        subtitle:
                            "Students can see a locked unit but cannot open its topics.",
                        value: isLocked,
                        onChanged: (v) => setState(() => isLocked = v),
                      ),
                    ]),
                    const SizedBox(height: AppTokens.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(unitViewModel, width),
      ],
    );
  }

  Widget _twoUp(double width, Widget left, Widget right) {
    if (width < 700) {
      return Column(children: [
        left,
        const SizedBox(height: AppTokens.gapMd),
        right,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(child: right),
      ],
    );
  }

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isEdit ? "Edit unit" : "Add a unit",
                  style: AppTokens.pageTitle),
              const SizedBox(height: 3),
              Text(
                widget.isEdit
                    ? "Update this unit's details and availability."
                    : "Units sit under a subject, and topics hang off them.",
                style: AppTokens.pageSubtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: _isSaving ? null : () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: AppTokens.ink),
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTokens.sectionTitle),
          const SizedBox(height: AppTokens.gapMd),
          ...children,
        ],
      ),
    );
  }

  // ---- Fields ---------------------------------------------------------

  static const TextStyle _labelStyle = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));

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
    final List<String> names = subjects
        .map((s) => s.name)
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

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

  /// Extra subject codes, for a unit that is shared across subjects. The
  /// old form offered these as an unlabelled row of boxes with + and −
  /// buttons and no explanation of what they were.
  Widget _extraCodesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Also appears in", style: _labelStyle),
        const SizedBox(height: 2),
        const Text(
          "Extra subject codes this unit should show under. Leave empty "
          "unless the unit is shared.",
          style: TextStyle(
              fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _extraCodeControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.gapSm),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(color: AppTokens.hairline),
                    ),
                    child: TextField(
                      controller: _extraCodeControllers[i],
                      inputFormatters: [UpperCaseTextFormatter()],
                      style: const TextStyle(
                          fontSize: 13.5, color: AppTokens.ink),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "Subject code",
                        hintStyle: TextStyle(
                            fontSize: 13, color: AppTokens.inkFaint),
                        contentPadding: EdgeInsets.fromLTRB(14, 13, 14, 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.gapSm),
                IconButton(
                  key: Key('unit_extra_code_remove_$i'),
                  tooltip: "Remove this code",
                  onPressed: _isSaving
                      ? null
                      : () => setState(() {
                            _extraCodeControllers[i].dispose();
                            _extraCodeControllers.removeAt(i);
                          }),
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTokens.inkMuted,
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: const Key('unit_extra_code_add'),
          onPressed: _isSaving
              ? null
              : () => setState(
                  () => _extraCodeControllers.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("Add a subject code",
              style: TextStyle(fontSize: 12.5)),
          style: TextButton.styleFrom(
            foregroundColor: AppTokens.inkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            inputFormatters: [
              if (numeric) FilteringTextInputFormatter.digitsOnly,
              if (uppercase) UpperCaseTextFormatter(),
            ],
            onChanged: onChanged == null ? null : (_) => onChanged(),
            style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? AppTokens.surface : AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: key,
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: AppTokens.inkFaint),
              hint: Text(hint,
                  style: const TextStyle(
                      fontSize: 13, color: AppTokens.inkFaint)),
              // Built from the theme with the decoration pinned off:
              // DropdownButton uses `style` verbatim instead of merging it,
              // and this State's context sits above the Scaffold's
              // Material — inheriting DefaultTextStyle there picks up
              // WidgetsApp's yellow double-underline error style.
              style: (Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle())
                  .copyWith(
                fontSize: 13.5,
                color: AppTokens.ink,
                decoration: TextDecoration.none,
              ),
              onChanged: (_isSaving || !enabled) ? null : onChanged,
              items: items
                  .map((String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Row(
                          children: [
                            Icon(icon, size: 15, color: AppTokens.inkFaint),
                            const SizedBox(width: 8),
                            Expanded(
                              child:
                                  Text(item, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  Widget _imageField() {
    final String? error = _errors[_Field.image];
    final bool hasNew = selectedImageBytes != null;
    final String existingUrl = widget.existing?.image ?? "";
    final bool hasExisting = existingUrl.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          width: 108,
          child: Material(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: InkWell(
              onTap: _isSaving ? null : _pickImage,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: error != null
                        ? AppTokens.danger
                        : AppTokens.inkFaint.withValues(alpha: .4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd - 1),
                  child: hasNew
                      ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                      : hasExisting
                          ? Image.network(existingUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => _imagePlaceholder())
                          : _imagePlaceholder(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNew
                    ? (imageName.isEmpty ? "Selected image" : imageName)
                    : hasExisting
                        ? "Using the current image"
                        : "No image chosen",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              const SizedBox(height: 3),
              Text(
                hasNew
                    ? _readableSize(selectedImageBytes!.lengthInBytes)
                    : "Square images work best — it is shown as a thumbnail.",
                style: const TextStyle(
                    fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : _pickImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.ink,
                      side: const BorderSide(color: AppTokens.hairline),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusSm)),
                    ),
                    child: Text(
                        hasNew || hasExisting ? "Replace" : "Choose image",
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  if (hasNew) ...[
                    const SizedBox(width: AppTokens.gapSm),
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => setState(() {
                                selectedImageBytes = null;
                                imageName = "";
                              }),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Text("Remove",
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error, style: AppTokens.errorText),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.add_photo_alternate_outlined,
            size: 26, color: AppTokens.inkFaint),
      );

  static String _readableSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  /// A labelled switch with the consequence spelled out. These were two
  /// unlabelled `ToggleSwitch` widgets whose states were "position 0" and
  /// "position 1" — nothing on screen said which meant what.
  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppTokens.inkFaint)),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        Switch(
          value: value,
          onChanged: _isSaving ? null : onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppTokens.ink,
        ),
      ],
    );
  }

  Widget _actionBar(UnitViewModel unitViewModel, double width) {
    final bool narrow = width < 560;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: width < 700 ? 16 : 32, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            children: [
              if (widget.isEdit)
                narrow
                    ? IconButton(
                        onPressed:
                            _isSaving ? null : () => _onDelete(unitViewModel),
                        tooltip: "Delete unit",
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppTokens.danger,
                      )
                    : TextButton.icon(
                        onPressed:
                            _isSaving ? null : () => _onDelete(unitViewModel),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text("Delete"),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
              if (!narrow) const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 12 : 18, vertical: 14),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: AppTokens.gapSm),
              _saveButton(unitViewModel, expand: narrow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton(UnitViewModel unitViewModel, {required bool expand}) {
    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, minHeight: 42),
      child: ElevatedButton(
        key: const Key('unit_save_button'),
        onPressed: _isSaving ? null : () => _onSubmit(unitViewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.ink,
          disabledBackgroundColor: AppTokens.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Text(widget.isEdit ? "Update unit" : "Save unit",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }
}
