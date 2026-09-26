import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_form.dart'
    show UpperCaseTextFormatter;
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/screen/topic_details.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The whole Add/Edit Topic page. [existing] null means Add.
///
/// Add and Edit were 764 and 748 line screens holding the same form written
/// out twice — once for wide windows and once for narrow — so every field
/// existed in four places. There is one responsive form here, and the two
/// screens in `screen/` just choose the mode.
class TopicForm extends StatefulWidget {
  final TopicModel? existing;
  const TopicForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<TopicForm> createState() => _TopicFormState();
}

/// The fields that can carry an inline error.
enum _Field { course, subject, unit, code, name, priority }

class _TopicFormState extends State<TopicForm> {
  final GlobalKey<ScaffoldState> key = GlobalKey();

  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();

  String? _selectedCourseName;
  String _selectedCourseCode = "";
  String? _selectedSubjectName;
  String _selectedSubjectCode = "";
  String? _selectedUnitName;
  String _selectedUnitCode = "";

  /// Unit codes this topic also appears under. The primary unit's own code
  /// is not repeated here.
  final List<TextEditingController> _extraCodeControllers = [];

  bool _isSaving = false;
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
      // The old form went straight to `int.parse` on save, so a priority
      // with anything but digits in it threw out of the button's callback.
      errors[_Field.priority] = "Priority must be a whole number";
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

  /// The primary unit code first, then any extra ones — de-duplicated and
  /// with blanks dropped, so an empty extra field cannot write an empty
  /// string into the array.
  ///
  /// The old form left the primary code out entirely: a topic with no
  /// extras saved `unitCodeList: []`, so nothing reading that array could
  /// find the topic under its own unit.
  List<String> _unitCodes() {
    final List<String> codes = [_selectedUnitCode];
    for (final TextEditingController controller in _extraCodeControllers) {
      final String value = controller.text.trim().toUpperCase();
      if (value.isNotEmpty && !codes.contains(value)) codes.add(value);
    }
    return codes.where((code) => code.isNotEmpty).toList();
  }

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
              title: "Topics",
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isCompact)
                    const Expanded(child: ExtraSideBar(sidebarIndex: 4)),
                  Expanded(
                    flex: 5,
                    child: Consumer2<TopicViewModel, CourseViewModel>(
                      builder:
                          (context, topicViewModel, courseViewModel, child) =>
                              _page(topicViewModel, courseViewModel, width),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer:
          isCompact ? const Drawer(child: ExtraSideBar(sidebarIndex: 4)) : null,
    );
  }

  Widget _page(TopicViewModel topicViewModel, CourseViewModel courseViewModel,
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
                        _courseField(topicViewModel, courseViewModel),
                        _subjectField(topicViewModel),
                      ),
                      const SizedBox(height: AppTokens.gapMd),
                      _unitField(topicViewModel),
                      const SizedBox(height: AppTokens.gapMd),
                      _extraCodesField(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "TOPIC DETAILS", children: [
                      _twoUp(
                        width,
                        _textField(
                          label: "Topic code",
                          hint: "e.g. NEWT-01",
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
                        label: "Topic name",
                        hint: "e.g. Newton's First Law",
                        controller: nameController,
                        error: _errors[_Field.name],
                        onChanged: _revalidate,
                      ),
                    ]),
                    if (widget.isEdit) ...[
                      const SizedBox(height: AppTokens.gapMd),
                      _section(title: "CONTENT", children: [_contentRow()]),
                    ],
                    const SizedBox(height: AppTokens.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(topicViewModel, width),
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
              Text(widget.isEdit ? "Edit topic" : "Add a topic",
                  style: AppTokens.pageTitle),
              const SizedBox(height: 3),
              Text(
                widget.isEdit
                    ? "Update where this topic sits and how it is labelled."
                    : "Topics sit under a unit, and content hangs off them.",
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

  /// Extra unit codes, for a topic that is shared across units. The old
  /// form offered these as an unlabelled row of boxes with + and − buttons
  /// and no explanation of what they were.
  Widget _extraCodesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Also appears in", style: _labelStyle),
        const SizedBox(height: 2),
        const Text(
          "Extra unit codes this topic should show under. The unit chosen "
          "above is included automatically.",
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
                      style:
                          const TextStyle(fontSize: 13.5, color: AppTokens.ink),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: "Unit code",
                        hintStyle:
                            TextStyle(fontSize: 13, color: AppTokens.inkFaint),
                        contentPadding: EdgeInsets.fromLTRB(14, 13, 14, 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.gapSm),
                IconButton(
                  key: Key('topic_extra_code_remove_$i'),
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
          key: const Key('topic_extra_code_add'),
          onPressed: _isSaving
              ? null
              : () => setState(
                  () => _extraCodeControllers.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 16),
          label:
              const Text("Add a unit code", style: TextStyle(fontSize: 12.5)),
          style: TextButton.styleFrom(
            foregroundColor: AppTokens.inkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }

  /// A summary of what is attached, with a way through to the screen that
  /// manages it. Editing a topic and attaching content to it were two
  /// pages reached from two adjacent icons on the row, with nothing on
  /// either saying the other existed.
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
          label: const Text("Manage content",
              style: TextStyle(fontSize: 12.5)),
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
                  style:
                      const TextStyle(fontSize: 13, color: AppTokens.inkFaint)),
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

  Widget _actionBar(TopicViewModel topicViewModel, double width) {
    final bool narrow = width < 560;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: width < 700 ? 16 : 32, vertical: 14),
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
                            _isSaving ? null : () => _onDelete(topicViewModel),
                        tooltip: "Delete topic",
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppTokens.danger,
                      )
                    : TextButton.icon(
                        onPressed:
                            _isSaving ? null : () => _onDelete(topicViewModel),
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
              _saveButton(topicViewModel, expand: narrow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton(TopicViewModel topicViewModel, {required bool expand}) {
    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, minHeight: 42),
      child: ElevatedButton(
        key: const Key('topic_save_button'),
        onPressed: _isSaving ? null : () => _onSubmit(topicViewModel),
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
            : Text(widget.isEdit ? "Update topic" : "Save topic",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }
}
