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
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/screen/topic_details.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Topic page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: where it belongs (course, subject, unit), details (including
/// extra unit codes) and, when editing, a link to the content screen.
class TopicForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final TopicModel? existing;
  const TopicForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<TopicForm> createState() => _TopicFormState();
}

/// The fields that can carry an inline error.
enum _Field { course, subject, unit, code, name, priority }

class _TopicFormState extends State<TopicForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

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

  /// Unit chosen in the dropdown (by name).
  String? _selectedUnitName;

  /// Code of the chosen unit.
  String _selectedUnitCode = "";

  /// Unit codes this topic also appears under. The primary unit's own code
  /// is not repeated here.
  final List<TextEditingController> _extraCodeControllers = [];

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final TopicModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      nameController.text = existing.name;
      priorityController.text = existing.displayPriority.toString();
      _selectedCourseName =
          existing.courseName == stringDefault ? null : existing.courseName;
      _selectedCourseCode = existing.courseCode;
      _selectedSubjectName =
          existing.subjectName == stringDefault ? null : existing.subjectName;
      _selectedSubjectCode = existing.subjectCode;
      _selectedUnitName =
          existing.unitName == stringDefault ? null : existing.unitName;
      _selectedUnitCode = existing.unitCode;
      for (final String code in existing.unitCodeList) {
        if (code == existing.unitCode) continue;
        _extraCodeControllers.add(TextEditingController(text: code));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final CourseViewModel courseViewModel =
          Provider.of<CourseViewModel>(context, listen: false);
      if (courseViewModel.allCourses.isEmpty) courseViewModel.getCourseList();
      // Editing starts with a course and subject already chosen, so the
      // two levels below have to be fetched before their pickers can show
      // anything.
      final TopicViewModel topicViewModel =
          Provider.of<TopicViewModel>(context, listen: false);
      if (_selectedCourseCode.isNotEmpty) {
        topicViewModel.getSubjectList(courseCode: _selectedCourseCode);
      }
      if (_selectedSubjectCode.isNotEmpty) {
        topicViewModel.getUnitList(subjectCode: _selectedSubjectCode);
      }
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
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
    if (_selectedUnitCode.isEmpty) {
      errors[_Field.unit] = "Choose the unit this belongs to";
    }
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the topic a code";
    }
    if (nameController.text.trim().isEmpty) {
      errors[_Field.name] = "Give the topic a name";
    }
    final String priority = priorityController.text.trim();
    if (priority.isEmpty) {
      errors[_Field.priority] = "Set a display priority";
    } else if (int.tryParse(priority) == null) {
      errors[_Field.priority] = "Priority must be a whole number";
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

  /// The primary unit code first, then any extra ones — de-duplicated and
  /// with blanks dropped. The primary code is always included, so the topic
  /// can be found under its own unit.
  List<String> _unitCodes() {
    final List<String> codes = [_selectedUnitCode];
    for (final TextEditingController controller in _extraCodeControllers) {
      final String value = controller.text.trim().toUpperCase();
      if (value.isNotEmpty && !codes.contains(value)) codes.add(value);
    }
    return codes.where((code) => code.isNotEmpty).toList();
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(TopicViewModel topicViewModel) async {
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

    final TopicModel model = TopicModel(
      codeController.text.trim().toUpperCase(),
      nameController.text.trim(),
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      _selectedCourseName ?? stringDefault,
      _selectedCourseCode,
      _selectedSubjectName ?? stringDefault,
      _selectedSubjectCode,
      _selectedUnitName ?? stringDefault,
      _selectedUnitCode,
      int.parse(priorityController.text.trim()),
      _unitCodes(),
    );

    final bool success = widget.isEdit
        ? await topicViewModel.updateTopic(model, widget.existing!.docId)
        : await topicViewModel.createTopic(model);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Topic updated successfully"
              : "Topic added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
  void _onDelete(TopicViewModel topicViewModel) {
    final TopicModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await topicViewModel.deleteTopic(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Topic deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Topics",
      sidebarIndex: 4,
      body: (context, width) => Consumer2<TopicViewModel, CourseViewModel>(
        builder: (context, topicViewModel, courseViewModel, child) =>
            _page(topicViewModel, courseViewModel, width),
      ),
    );
  }

  /// The scrolling form (header and sections) with the action bar below.
  Widget _page(TopicViewModel topicViewModel, CourseViewModel courseViewModel,
      double width) {
    return FormPageBody(
      width: width,
      actionBar: _actionBar(topicViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "WHERE IT BELONGS", children: [
          FormTwoUp(
              width: width,
              left: _courseField(topicViewModel, courseViewModel),
              right: _subjectField(topicViewModel)),
          const SizedBox(height: AppTokens.gapMd),
          _unitField(topicViewModel),
          const SizedBox(height: AppTokens.gapMd),
          _extraCodesField(),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "TOPIC DETAILS", children: [
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Topic code",
                hint: "e.g. NEWT-01",
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
            label: "Topic name",
            hint: "e.g. Newton's First Law",
            controller: nameController,
            error: _errors[_Field.name],
            onChanged: _revalidate,
          ),
        ]),
        if (widget.isEdit) ...[
          const SizedBox(height: AppTokens.gapMd),
          FormSection(title: "CONTENT", children: [_contentRow()]),
        ],
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit topic" : "Add a topic",
      subtitle: widget.isEdit
          ? "Update where this topic sits and how it is labelled."
          : "Topics sit under a unit, and content hangs off them.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  // ---- Fields ---------------------------------------------------------

  /// Course dropdown.
  Widget _courseField(
      TopicViewModel topicViewModel, CourseViewModel courseViewModel) {
    final List<CourseModel> courses = courseViewModel.allCourses;
    final List<String> names =
        courses.map((c) => c.name).where((n) => n.isNotEmpty).toSet().toList();

    // A topic may name a course that has since been renamed or removed —
    // keep that value selectable so editing doesn't silently drop it.
    final String? current = _selectedCourseName;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    return _dropdownField(
      key: const Key('topic_course_dropdown'),
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
          // Changing course invalidates both levels beneath it.
          _selectedSubjectName = null;
          _selectedSubjectCode = "";
          _selectedUnitName = null;
          _selectedUnitCode = "";
        });
        if (_selectedCourseCode.isNotEmpty) {
          topicViewModel.getSubjectList(courseCode: _selectedCourseCode);
        }
        _revalidate();
      },
    );
  }

  /// Subjects are fetched for the chosen course, so this picker stays
  /// disabled until there is a course to fetch them for.
  Widget _subjectField(TopicViewModel topicViewModel) {
    final List<SubjectModel> subjects = topicViewModel.subjectList;
    final List<String> names =
        subjects.map((s) => s.name).where((n) => n.isNotEmpty).toSet().toList();

    final String? current = _selectedSubjectName;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    final bool enabled = _selectedCourseCode.isNotEmpty;

    return _dropdownField(
      key: const Key('topic_subject_dropdown'),
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
          // And changing subject invalidates the unit beneath it. The old
          // form left the previous unit selected, so a topic could be
          // saved pointing at a unit from a different subject.
          _selectedUnitName = null;
          _selectedUnitCode = "";
        });
        if (_selectedSubjectCode.isNotEmpty) {
          topicViewModel.getUnitList(subjectCode: _selectedSubjectCode);
        }
        _revalidate();
      },
    );
  }

  /// Unit dropdown (enabled once a subject is chosen).
  Widget _unitField(TopicViewModel topicViewModel) {
    final List<UnitModel> units = topicViewModel.unitList;
    final List<String> names =
        units.map((u) => u.name).where((n) => n.isNotEmpty).toSet().toList();

    final String? current = _selectedUnitName;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    final bool enabled = _selectedSubjectCode.isNotEmpty;

    return _dropdownField(
      key: const Key('topic_unit_dropdown'),
      label: "Unit",
      hint: !enabled
          ? "Choose a subject first"
          : names.isEmpty
              ? "No units in this subject"
              : "Select a unit",
      value: _selectedUnitName,
      items: names,
      error: _errors[_Field.unit],
      icon: Icons.layers_outlined,
      enabled: enabled,
      onChanged: (value) {
        setState(() {
          _selectedUnitName = value;
          _selectedUnitCode = units
                  .where((u) => u.name == value)
                  .map((u) => u.code)
                  .firstOrNull ??
              "";
        });
        _revalidate();
      },
    );
  }

  /// Extra unit codes, for a topic that is shared across units.
  Widget _extraCodesField() {
    return ExtraCodesField(
      controllers: _extraCodeControllers,
      description:
          "Extra unit codes this topic should show under. The unit chosen "
          "above is included automatically.",
      hint: "Unit code",
      addLabel: "Add a unit code",
      keyPrefix: "topic",
      enabled: !_isSaving,
      onAdd: () =>
          setState(() => _extraCodeControllers.add(TextEditingController())),
      onRemove: (i) => setState(() {
        _extraCodeControllers[i].dispose();
        _extraCodeControllers.removeAt(i);
      }),
    );
  }

  /// Edit mode only: a summary of the attached content and a button to the
  /// screen that manages it.
  Widget _contentRow() {
    final TopicModel existing = widget.existing!;
    final List<String> parts = <String>[];
    for (final ContentKind kind in ContentKind.values) {
      final int count = existing.contentCodes(kind).length;
      if (count > 0) parts.add("$count ${kind.inlineLabel}");
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            parts.isEmpty ? "Nothing attached yet" : parts.join(" · "),
            style: const TextStyle(fontSize: 13, color: AppTokens.inkMuted),
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        OutlinedButton.icon(
          key: const Key('topic_manage_content'),
          onPressed: _isSaving
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            TopicDetails(topicData: existing)),
                  ),
          icon: const Icon(Icons.playlist_add, size: 16),
          label: const Text("Manage content", style: TextStyle(fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTokens.ink,
            side: const BorderSide(color: AppTokens.hairline),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          ),
        ),
      ],
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

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(TopicViewModel topicViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(topicViewModel) : null,
      deleteTooltip: "Delete topic",
      saveKey: const Key('topic_save_button'),
      saveLabel: widget.isEdit ? "Update topic" : "Save topic",
      onSave: () => _onSubmit(topicViewModel),
      saveMinWidth: 130,
    );
  }
}
