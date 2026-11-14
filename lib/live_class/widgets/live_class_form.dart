import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/class_time.dart';
import 'package:bbarna/live_class/widgets/live_class_form_fields.dart';
import 'package:bbarna/live_class/widgets/live_class_status_badge.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The whole Add/Edit Class page. [existing] null means Add; non-null means
/// Edit (fields pre-populated, Update + Delete instead of Save).
///
/// Add and Edit share one widget on purpose — the form is identical in both
/// modes, so the two thin screens in `screen/` just choose the mode.
///
/// The form is grouped into two sections (Details, Schedule) with a fixed
/// action bar at the bottom. Errors are shown inline under the offending
/// field rather than only as a snackbar, so a failed save points at what to
/// fix instead of making the admin re-read the whole form.
class LiveClassForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final LiveClassModel? existing;
  const LiveClassForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<LiveClassForm> createState() => _LiveClassFormState();
}

/// The fields that can carry an inline error.
enum _Field { title, subject, teacher, date, start, end }

class _LiveClassFormState extends State<LiveClassForm> {
  /// Text of the title field.
  final TextEditingController titleController = TextEditingController();

  /// Text of the description field.
  final TextEditingController descriptionController = TextEditingController();

  /// Text of the YouTube link field.
  final TextEditingController youtubeLinkController = TextEditingController();

  /// Text of the typed teacher name (used when no teacher list is available) field.
  final TextEditingController teacherNameController = TextEditingController();

  /// Lets the header's menu button open the drawer.
  final GlobalKey<ScaffoldState> key = GlobalKey();

  /// Teacher chosen in the dropdown (or typed), by name.
  String? _selectedTeacher;

  /// The picked teacher's document id, resolved from the name the dropdown
  /// is keyed on. Empty when the name was typed by hand, or belongs to a
  /// teacher who has since been removed — the student app then simply
  /// marks nobody as the teacher rather than marking the wrong person.
  String _selectedTeacherId = "";

  /// The picked teacher's phone number, resolved alongside [_selectedTeacherId]
  /// — same rule: empty when the name was typed by hand or belongs to a
  /// teacher who has since been removed.
  String _selectedTeacherPhone = "";

  /// Subject chosen in the dropdown, by name.
  String? _selectedSubject;

  /// Code of the chosen subject.
  String _selectedSubjectCode = "";

  /// A class runs within a single day, so the schedule is one date plus two
  /// times rather than two independent date-times. Holding it that way is
  /// what makes "the end is on another day" unrepresentable instead of
  /// merely rejected.
  DateTime? _classDate;

  /// Start time on [_classDate].
  TimeOfDay? _startTime;

  /// End time on [_classDate] (always after the start).
  TimeOfDay? _endTime;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// "Free" or "Paid"; a new class starts Paid, the student app's default.
  String _classType = LiveClassModel.liveClassPaid;

  /// Start as a full date-time (null until date and start time are set).
  DateTime? get _startDateTime => ClassTime.combine(_classDate, _startTime);

  /// End as a full date-time (null until date and end time are set).
  DateTime? get _endDateTime => ClassTime.combine(_classDate, _endTime);

  /// Populated on a failed submit and cleared per-field as it is corrected,
  /// so the form never scolds you about something you already fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final LiveClassModel? existing = widget.existing;
    if (existing != null) {
      titleController.text = existing.title;
      descriptionController.text = existing.description;
      youtubeLinkController.text = existing.youtubeLink;
      teacherNameController.text = existing.teacherName;
      _selectedTeacher = existing.teacherName;
      _selectedTeacherId = existing.teacherId;
      _selectedTeacherPhone = existing.teacherPhone;
      _selectedSubject = existing.subject.isEmpty ? null : existing.subject;
      _selectedSubjectCode = existing.subjectCode;
      _classType = existing.classType;
      _classDate = ClassTime.dateOnly(existing.startDateTime);
      _startTime = TimeOfDay.fromDateTime(existing.startDateTime);
      _endTime = TimeOfDay.fromDateTime(existing.endDateTime);
      // A class saved before the same-day rule can end on another date.
      // Collapsing it onto the start date silently would move the class, so
      // the mismatch is flagged up front rather than at the first save.
      if (!ClassTime.sameDay(existing.startDateTime, existing.endDateTime)) {
        _errors[_Field.end] =
            "This class used to end on a different day — pick an end time "
            "on the class date.";
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final LiveClassViewModel liveClassViewModel =
          Provider.of<LiveClassViewModel>(context, listen: false);
      liveClassViewModel.getTeachers();
      liveClassViewModel.getSubjects();
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    youtubeLinkController.dispose();
    teacherNameController.dispose();
    super.dispose();
  }

  // ---- Validation -----------------------------------------------------

  /// Returns the per-field errors for the current state. Empty means valid.
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (titleController.text.trim().isEmpty) {
      errors[_Field.title] = "Give the class a title";
    }
    if ((_selectedSubject ?? "").trim().isEmpty) {
      // Required, not optional: the app prints the subject on the class
      // card three times over, so a class saved without one reaches
      // students with blank lines where the subject belongs.
      errors[_Field.subject] = "Choose the subject this class is for";
    }
    if ((_selectedTeacher ?? teacherNameController.text).trim().isEmpty) {
      errors[_Field.teacher] = "Choose or type a teacher";
    }
    if (_classDate == null) {
      errors[_Field.date] = "Pick the class date";
    }
    if (_startTime == null) {
      errors[_Field.start] = "Pick a start time";
    }
    if (_endTime == null) {
      errors[_Field.end] = "Pick an end time";
    } else if (_startTime != null &&
        ClassTime.minutesOf(_endTime!) <= ClassTime.minutesOf(_startTime!)) {
      errors[_Field.end] = "The end time must be after the start time";
    }
    return errors;
  }

  /// Re-runs validation only once the admin has already seen errors — that
  /// is what makes a correction clear its message as you make it.
  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(LiveClassViewModel liveClassViewModel) async {
    final Map<_Field, String> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      // The inline messages already say what is wrong and where; the
      // snackbar only has to get the admin looking at them.
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

    final String teacherName =
        (_selectedTeacher ?? teacherNameController.text).trim();
    // The teacher's id and phone as the Teacher module has them now, so
    // re-saving an older class (blank phone) or one whose teacher changed
    // number fixes it. The app knows the teacher by this phone.
    final LiveClassTeacher? currentTeacher = liveClassViewModel.teacherFor(
        id: _selectedTeacherId, name: teacherName);

    final LiveClassModel model = LiveClassModel(
      docId: widget.existing?.docId ?? stringDefault,
      title: titleController.text,
      description: descriptionController.text,
      youtubeLink: youtubeLinkController.text,
      teacherName: teacherName,
      teacherId: currentTeacher?.id ?? _selectedTeacherId,
      teacherPhone: currentTeacher?.phoneNumber ?? _selectedTeacherPhone,
      subject: _selectedSubject ?? "",
      subjectCode: _selectedSubjectCode,
      classType: _classType,
      startDateTime: _startDateTime!,
      endDateTime: _endDateTime!,
    );

    final bool success = widget.isEdit
        ? await liveClassViewModel.updateLiveClass(model)
        : await liveClassViewModel.addLiveClass(model);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Class updated successfully"
              : "Class added successfully",
          isSuccess: true);
      Navigator.pop(context, true);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
  void _onDelete(LiveClassViewModel liveClassViewModel) {
    final LiveClassModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.title,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        // RemoveAlert never closes itself — every caller pops it. Popping it
        // first means the only route left to unwind on success is this form.
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success =
            await liveClassViewModel.deleteLiveClass(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Class deleted successfully");
          // Back to the list.
          Navigator.pop(context, true);
        }
      },
    );
  }

  /// Both pickers are shown under the module's own palette rather than
  /// Material's default purple, so the calendar and clock look like the
  /// rest of the page instead of a system dialog dropped on top of it.
  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime base = _classDate ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: "Class date",
      builder: (context, child) => Theme(
        data: LiveClassTheme.pickerTheme(context),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _classDate = ClassTime.dateOnly(picked));
    _revalidate();
  }

  /// Sets the class date from a quick-pick chip.
  void _setDate(DateTime date) {
    setState(() => _classDate = ClassTime.dateOnly(date));
    _revalidate();
  }

  /// Picks the start time; an existing end moves with it so the class
  /// keeps its length (dropped if it would pass midnight).
  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await _showTimePicker(
        _startTime ?? const TimeOfDay(hour: 18, minute: 0),
        "Select the start time");
    if (picked == null || !mounted) return;

    setState(() {
      final TimeOfDay? previousStart = _startTime;
      _startTime = picked;
      // Moving the start drags the end with it, keeping the length of the
      // class — re-picking the end every time you shift a class by ten
      // minutes is the sort of thing that makes a form tiring.
      if (previousStart != null && _endTime != null) {
        final int length =
            ClassTime.minutesOf(_endTime!) - ClassTime.minutesOf(previousStart);
        if (length > 0) {
          final int shifted = ClassTime.minutesOf(picked) + length;
          // A class cannot cross midnight any more, so an end that would
          // spill into the next day is dropped for the admin to re-pick.
          _endTime = shifted < 24 * 60
              ? TimeOfDay(hour: shifted ~/ 60, minute: shifted % 60)
              : null;
        }
      }
    });
    _revalidate();
  }

  /// Picks the end time (defaults to an hour after the start).
  Future<void> _pickEndTime() async {
    final TimeOfDay initial = _endTime ??
        (_startTime == null
            ? const TimeOfDay(hour: 19, minute: 0)
            : ClassTime.plus(_startTime!, 60) ??
                const TimeOfDay(hour: 23, minute: 59));
    final TimeOfDay? picked =
        await _showTimePicker(initial, "Select the end time");
    if (picked == null || !mounted) return;
    setState(() => _endTime = picked);
    _revalidate();
  }

  /// The themed time picker: typed entry on wide windows, dial on narrow.
  Future<TimeOfDay?> _showTimePicker(TimeOfDay initial, String helpText) {
    // Typed entry on a desktop with a keyboard — "0730 PM" is faster and
    // more precise than dragging a clock face with a mouse. Touch-sized
    // windows still get the dial, and either can be toggled from the
    // dialog itself.
    final bool hasKeyboard = MediaQuery.sizeOf(context).width >= 700;

    return showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
      initialEntryMode:
          hasKeyboard ? TimePickerEntryMode.input : TimePickerEntryMode.dial,
      builder: (context, child) => Theme(
        data: LiveClassTheme.pickerTheme(context),
        child: child!,
      ),
    );
  }

  /// Sets the end from the start — the common case is a class of a round
  /// length, and picking "1h 30m" beats spinning a clock face to 7:30.
  void _setDuration(int minutes) {
    final TimeOfDay? start = _startTime;
    if (start == null) return;
    final TimeOfDay? end = ClassTime.plus(start, minutes);
    if (end == null) {
      Helper.showSnackBarMessage(
          msg: "That would run past midnight — a class has to end on the "
              "same day.",
          isSuccess: false);
      return;
    }
    setState(() => _endTime = end);
    _revalidate();
  }

  /// The length currently set, in minutes, or null when it is not a clean
  /// pair — used to light up the matching duration chip.
  int? get _durationMinutes {
    if (_startTime == null || _endTime == null) return null;
    final int length =
        ClassTime.minutesOf(_endTime!) - ClassTime.minutesOf(_startTime!);
    return length > 0 ? length : null;
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      key: key,
      backgroundColor: LiveClassTheme.canvas,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Column(
          children: [
            AppHeader(onTapIcon: () => key.currentState?.openDrawer()),
            Expanded(
              child: Row(
                children: [
                  if (width > 900)
                    const Expanded(
                        child:
                            ExtraSideBar(sidebarIndex: liveClassModuleIndex)),
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: LiveClassTheme.canvas,
                      child: Consumer<LiveClassViewModel>(
                        builder: (context, liveClassViewModel, child) =>
                            _page(liveClassViewModel, width),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: width < 900
          ? const Drawer(
              child: ExtraSideBar(sidebarIndex: liveClassModuleIndex))
          : null,
    );
  }

  /// Scrolling body + a fixed action bar. The bar being pinned means Save is
  /// reachable without scrolling to the bottom of a long form.
  Widget _page(LiveClassViewModel liveClassViewModel, double width) {
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
                    const SizedBox(height: LiveClassTheme.gapLg),
                    _section(
                      title: "CLASS DETAILS",
                      children: [
                        _textField(
                          label: "Class title",
                          hint: "e.g. Trigonometry — Chapter 4 revision",
                          controller: titleController,
                          error: _errors[_Field.title],
                          onChanged: _revalidate,
                        ),
                        const SizedBox(height: LiveClassTheme.gapMd),
                        _subjectField(liveClassViewModel),
                        const SizedBox(height: LiveClassTheme.gapMd),
                        // Free: any student can open it. Paid: only those
                        // who bought the subject.
                        FormAccessTypeField(
                          label: "Class type",
                          types: const [
                            LiveClassModel.liveClassFree,
                            LiveClassModel.liveClassPaid,
                          ],
                          selected: _classType,
                          keyPrefix: 'live_class',
                          error: null,
                          enabled: !_isSaving,
                          onSelect: (type) =>
                              setState(() => _classType = type),
                        ),
                        const SizedBox(height: LiveClassTheme.gapMd),
                        _textField(
                          label: "Description",
                          hint: "What will this class cover? (optional)",
                          controller: descriptionController,
                          maxLines: 4,
                        ),
                        const SizedBox(height: LiveClassTheme.gapMd),
                        _teacherField(liveClassViewModel),
                        const SizedBox(height: LiveClassTheme.gapMd),
                        _textField(
                          label: "YouTube class link",
                          hint: "https://www.youtube.com/watch?v=...",
                          controller: youtubeLinkController,
                          prefixIcon: Icons.play_circle_outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: LiveClassTheme.gapMd),
                    _section(
                      title: "SCHEDULE",
                      children: [_scheduleFields(width)],
                    ),
                    const SizedBox(height: LiveClassTheme.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(liveClassViewModel, width),
      ],
    );
  }

  /// Back button, title, subtitle and (when editing) the live status badge.
  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
        const SizedBox(width: LiveClassTheme.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEdit ? "Edit class" : "Schedule a class",
                style: LiveClassTheme.pageTitle,
              ),
              const SizedBox(height: 3),
              Text(
                widget.isEdit
                    ? "Update the schedule or details of this live class."
                    : "Set up a new live class for your students.",
                style: LiveClassTheme.pageSubtitle,
              ),
            ],
          ),
        ),
        // On edit, show what bucket the class currently lands in — and keep
        // it live as the dates are changed, so moving a class out of "Past"
        // is visible before saving.
        if (widget.isEdit && _startDateTime != null && _endDateTime != null)
          LiveClassStatusBadge(status: _previewModel().status),
      ],
    );
  }

  /// The class as it would be saved right now (for the status preview).
  /// Only call when both date-times are set.
  LiveClassModel _previewModel() => LiveClassModel(
        docId: widget.existing?.docId ?? stringDefault,
        title: titleController.text,
        description: descriptionController.text,
        youtubeLink: youtubeLinkController.text,
        teacherName: _selectedTeacher ?? "",
        teacherId: _selectedTeacherId,
        teacherPhone: _selectedTeacherPhone,
        subject: _selectedSubject ?? "",
        subjectCode: _selectedSubjectCode,
        classType: _classType,
        startDateTime: _startDateTime!,
        endDateTime: _endDateTime!,
      );

  /// The ← button (disabled while saving).
  Widget _backButton() {
    return Material(
      color: LiveClassTheme.surface,
      borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
      child: InkWell(
        onTap: _isSaving ? null : () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
            border: Border.all(color: LiveClassTheme.hairline),
          ),
          child:
              const Icon(Icons.arrow_back, size: 18, color: LiveClassTheme.ink),
        ),
      ),
    );
  }

  /// A white card grouping fields under an upper-case [title].
  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: LiveClassTheme.surface,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
        border: Border.all(color: LiveClassTheme.hairline),
        boxShadow: LiveClassTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LiveClassTheme.sectionTitle),
          const SizedBox(height: LiveClassTheme.gapMd),
          ...children,
        ],
      ),
    );
  }

  // ---- Fields ---------------------------------------------------------

  /// A labelled, full-width bordered text input in the module's theme.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? error,
    IconData? prefixIcon,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LiveClassTheme.fieldLabel),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: LiveClassTheme.surface,
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
            border: Border.all(
                color: error != null
                    ? LiveClassTheme.danger
                    : LiveClassTheme.hairline),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: onChanged == null ? null : (_) => onChanged(),
            style: const TextStyle(fontSize: 13.5, color: LiveClassTheme.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: LiveClassTheme.inkFaint),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, size: 17, color: LiveClassTheme.inkFaint),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 38, minHeight: 20),
              contentPadding:
                  EdgeInsets.fromLTRB(prefixIcon == null ? 14 : 0, 13, 14, 13),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: LiveClassTheme.errorText),
        ],
      ],
    );
  }

  /// Dropdown of the Full Course subjects from the `subject` collection
  /// (only full courses show live classes in the student app).
  ///
  /// The student app draws this name on the class card — on the thumbnail,
  /// in the title, and on its own line underneath — so a class needs one
  /// before it is worth showing.
  Widget _subjectField(LiveClassViewModel liveClassViewModel) {
    // Deduplicated: two subject docs can share a display name (different
    // codes, or a straight duplicate), and DropdownButton asserts there is
    // exactly one item per value — a repeated name crashes the whole form.
    final List<String> names =
        liveClassViewModel.subjects.map((s) => s.name).toSet().toList();

    // An existing class may name a subject that has since been renamed or
    // removed — keep that value selectable so editing doesn't drop it.
    final String? current = _selectedSubject;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    return LiveClassDropdownField(
      dropdownKey: const Key('live_class_subject_dropdown'),
      label: "Subject",
      hint: liveClassViewModel.subjectOptions.hintFor(
        hasOptions: names.isNotEmpty,
        loading: "Loading subjects…",
        empty: "No Full Course subjects found",
        select: "Select a subject",
      ),
      value: _selectedSubject,
      items: names,
      icon: Icons.library_books_outlined,
      error: _errors[_Field.subject],
      loadError: liveClassViewModel.subjectOptions.error,
      onRetry: liveClassViewModel.subjectOptions.retry,
      // Disabled while the subjects load.
      onChanged: liveClassViewModel.subjectOptions.isLoading
          ? null
          : (String? newValue) {
              setState(() {
                _selectedSubject = newValue;
                _selectedSubjectCode = liveClassViewModel.subjects
                        .where((s) => s.name == newValue)
                        .map((s) => s.code)
                        .firstOrNull ??
                    "";
              });
              _revalidate();
            },
    );
  }

  /// Dropdown of names from the `teacher` collection. Falls back to a plain
  /// text field only when that collection is empty (or unreachable), so the
  /// form is never a dead end.
  Widget _teacherField(LiveClassViewModel liveClassViewModel) {
    // Deduplicated for the same reason as the subject dropdown below: two
    // teachers can share a display name, and DropdownButton asserts there is
    // exactly one item per value.
    final List<String> names =
        liveClassViewModel.teachers.map((t) => t.name).toSet().toList();
    // An existing class may name a teacher who has since been removed —
    // keep that value selectable so editing doesn't silently drop it.
    final String? current = _selectedTeacher;
    if (current != null && current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }

    // Still loading: a disabled dropdown, not the free-text fallback.
    if (names.isEmpty && liveClassViewModel.teacherOptions.isLoading) {
      return LiveClassDropdownField(
        dropdownKey: const Key('live_class_teacher_dropdown'),
        label: "Teacher",
        hint: "Loading teachers…",
        value: null,
        items: const [],
        icon: Icons.person_outline,
        error: _errors[_Field.teacher],
        onChanged: null,
      );
    }

    if (names.isEmpty) {
      final String? loadError = liveClassViewModel.teacherOptions.error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(
            label: "Teacher",
            hint: "Type the teacher's name",
            controller: teacherNameController,
            error: _errors[_Field.teacher],
            onChanged: _revalidate,
          ),
          // No teachers, or they failed to load: typing still works, and a
          // failed load can be retried.
          if (loadError != null)
            LoadErrorLine(
              message: "$loadError — type the name instead, or",
              onRetry: liveClassViewModel.teacherOptions.retry,
            )
          else ...[
            const SizedBox(height: 5),
            const Text(
              "No teachers found — type the name instead.",
              style: TextStyle(fontSize: 11.5, color: LiveClassTheme.inkFaint),
            ),
          ],
        ],
      );
    }

    // Keep _selectedTeacher in step with the free-text fallback if the
    // dropdown appears after the admin already typed a name.
    if ((_selectedTeacher ?? "").isEmpty &&
        teacherNameController.text.trim().isNotEmpty) {
      _selectedTeacher = teacherNameController.text.trim();
      if (!names.contains(_selectedTeacher)) names.insert(0, _selectedTeacher!);
    }

    return LiveClassDropdownField(
      dropdownKey: const Key('live_class_teacher_dropdown'),
      label: "Teacher",
      hint: "Select a teacher",
      value: _selectedTeacher,
      items: names,
      icon: Icons.person_outline,
      error: _errors[_Field.teacher],
      onChanged: (String? newValue) {
        setState(() {
          _selectedTeacher = newValue;
          teacherNameController.text = newValue ?? "";
          // Resolve the id and phone now: a name kept from a deleted teacher
          // has no id, and must not inherit the previous pick's.
          final LiveClassTeacher? matched = liveClassViewModel.teachers
              .where((t) => t.name == newValue)
              .firstOrNull;
          _selectedTeacherId = matched?.id ?? "";
          _selectedTeacherPhone = matched?.phoneNumber ?? "";
        });
        _revalidate();
      },
    );
  }

  /// A class runs inside one day, so the schedule reads as one date and two
  /// times — not two date-times you have to keep in sync yourself. Quick
  /// chips cover the common cases (today/tomorrow, a round-length class) so
  /// the calendar and the clock face are only opened for the exceptions.
  Widget _scheduleFields(double width) {
    final bool stack = width < 700;

    final Widget startField = _timeField(
      fieldKey: const Key('live_class_start_time_field'),
      label: "Start time",
      value: _startTime,
      error: _errors[_Field.start],
      onPick: _pickStartTime,
    );
    final Widget endField = _timeField(
      fieldKey: const Key('live_class_end_time_field'),
      label: "End time",
      value: _endTime,
      error: _errors[_Field.end],
      onPick: _pickEndTime,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateField(),
        const SizedBox(height: LiveClassTheme.gapSm),
        _quickDateChips(),
        const SizedBox(height: LiveClassTheme.gapLg),
        if (stack)
          Column(children: [
            startField,
            const SizedBox(height: LiveClassTheme.gapMd),
            endField,
          ])
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: startField),
              const SizedBox(width: LiveClassTheme.gapMd),
              Expanded(child: endField),
            ],
          ),
        const SizedBox(height: LiveClassTheme.gapMd),
        _durationChips(),
        if (_startDateTime != null &&
            _endDateTime != null &&
            _endDateTime!.isAfter(_startDateTime!)) ...[
          const SizedBox(height: LiveClassTheme.gapLg),
          _scheduleSummary(),
        ],
      ],
    );
  }

  /// The class date (weekday + date once set).
  Widget _dateField() {
    final bool isSet = _classDate != null;
    return LiveClassPickerField(
      fieldKey: const Key('live_class_date_field'),
      label: "Class date",
      icon: Icons.calendar_today_outlined,
      text: isSet
          ? "${LiveClassFormat.weekday.format(_classDate!)}, "
              "${LiveClassFormat.date.format(_classDate!)}"
          : "Select the class date",
      isSet: isSet,
      error: _errors[_Field.date],
      onTap: _pickDate,
    );
  }

  /// Today / Tomorrow / next week — the three dates an admin actually picks
  /// most of the time, without opening a calendar at all.
  Widget _quickDateChips() {
    final DateTime today = ClassTime.dateOnly(DateTime.now());
    return Wrap(
      spacing: LiveClassTheme.gapSm,
      runSpacing: LiveClassTheme.gapSm,
      children: [
        for (final MapEntry<String, DateTime> option in {
          "Today": today,
          "Tomorrow": today.add(const Duration(days: 1)),
          "In a week": today.add(const Duration(days: 7)),
        }.entries)
          LiveClassChoiceChip(
            label: option.key,
            selected: _classDate != null &&
                ClassTime.sameDay(_classDate!, option.value),
            onTap: () => _setDate(option.value),
          ),
      ],
    );
  }

  /// Round lengths, applied from the start time. Disabled until there is a
  /// start to measure from — a duration with no anchor means nothing.
  Widget _durationChips() {
    final bool enabled = _startTime != null;
    final int? current = _durationMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          enabled ? "Duration" : "Duration — pick a start time first",
          style: LiveClassTheme.fieldLabel.copyWith(
              color:
                  enabled ? const Color(0xFF344054) : LiveClassTheme.inkFaint),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: LiveClassTheme.gapSm,
          runSpacing: LiveClassTheme.gapSm,
          children: [
            for (final int minutes in const [30, 45, 60, 90, 120])
              LiveClassChoiceChip(
                label: LiveClassFormat.minutes(minutes),
                selected: current == minutes,
                enabled: enabled,
                onTap: () => _setDuration(minutes),
              ),
          ],
        ),
      ],
    );
  }

  /// A start or end time field.
  Widget _timeField({
    required Key fieldKey,
    required String label,
    required TimeOfDay? value,
    required VoidCallback onPick,
    String? error,
  }) {
    return LiveClassPickerField(
      fieldKey: fieldKey,
      label: label,
      icon: Icons.schedule,
      text: value == null ? "Select a time" : LiveClassFormat.timeOfDay(value),
      isSet: value != null,
      error: error,
      onTap: onPick,
    );
  }

  /// Recap line under the times, coloured by the would-be status.
  Widget _scheduleSummary() {
    return LiveClassScheduleSummary(
      preview: _previewModel(),
      start: _startDateTime!,
      end: _endDateTime!,
    );
  }

  // ---- Action bar -----------------------------------------------------

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(LiveClassViewModel liveClassViewModel, double width) {
    // Under ~560px the three buttons stop fitting side by side, so Delete
    // drops to an icon and Save takes the remaining width — the usual
    // mobile shape, and it keeps Save the biggest target on the bar.
    final bool narrow = width < 560;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: width < 700 ? 16 : 32, vertical: 14),
      decoration: const BoxDecoration(
        color: LiveClassTheme.surface,
        border: Border(top: BorderSide(color: LiveClassTheme.hairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            children: [
              if (widget.isEdit)
                narrow
                    ? IconButton(
                        onPressed: _isSaving
                            ? null
                            : () => _onDelete(liveClassViewModel),
                        tooltip: "Delete class",
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: LiveClassTheme.danger,
                      )
                    : TextButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _onDelete(liveClassViewModel),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text("Delete"),
                        style: TextButton.styleFrom(
                          foregroundColor: LiveClassTheme.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
              if (!narrow) const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: LiveClassTheme.inkMuted,
                  padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 12 : 18, vertical: 14),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: LiveClassTheme.gapSm),
              narrow
                  ? Expanded(child: _saveButton(liveClassViewModel))
                  : _saveButton(liveClassViewModel),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps its width while saving so the bar doesn't twitch — the label is
  /// swapped for a spinner in place.
  Widget _saveButton(LiveClassViewModel liveClassViewModel) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, minHeight: 42),
      child: ElevatedButton(
        key: const Key('live_class_save_button'),
        onPressed: _isSaving ? null : () => _onSubmit(liveClassViewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: LiveClassTheme.ink,
          disabledBackgroundColor: LiveClassTheme.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd)),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Text(
                widget.isEdit ? "Update class" : "Save class",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
