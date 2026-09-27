import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/valid_till_picker.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/screen/enrolled_unit_list.dart';
import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/student/widgets/enrolled_subjects_card.dart';
import 'package:bbarna/student/widgets/slide_dialog.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// A student's enrolments: what they can reach, and adding more. Two cards:
/// enrol in a subject, and the subjects already enrolled in.
class SettingStudent extends StatefulWidget {
  /// The student being managed.
  final String studentId;

  /// Their name, shown as the page title.
  final String studentName;

  const SettingStudent(
      {required this.studentId, required this.studentName, super.key});

  @override
  State<SettingStudent> createState() => _SettingStudentState();
}

/// The fields of the enrol form that can carry an inline error.
enum _Field { course, subject, units, validity }

class _SettingStudentState extends State<SettingStudent> {
  /// Course chosen in the dropdown (by name).
  String? _selectedCourseName;

  /// Code of the chosen course.
  String _selectedCourseCode = "";

  /// Subject chosen in the dropdown (by name).
  String? _selectedSubjectName;

  /// Code of the chosen subject.
  String _selectedSubjectCode = "";

  /// Thumbnail URL of the chosen subject (copied onto the enrolment).
  String _selectedSubjectImage = "";

  /// Last day of access for the new enrolment.
  DateTime? _validTill;

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<_Field, String> _errors = {};

  /// Format of the chosen validity date.
  static final DateFormat _displayDate = DateFormat("d MMM yyyy");

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final StudentViewModel studentViewModel =
          Provider.of<StudentViewModel>(context, listen: false);
      studentViewModel.clearStudentData();
      studentViewModel.getEnrolledCourseList(widget.studentId);
      studentViewModel.getCourseList();
    });
  }

  // ---- Validation -----------------------------------------------------

  /// Checks every field and returns the problems (empty when valid).
  Map<_Field, String> _validate(StudentViewModel studentViewModel) {
    final Map<_Field, String> errors = {};
    if (_selectedCourseCode.isEmpty) {
      errors[_Field.course] = "Choose a course";
    }
    if (_selectedSubjectCode.isEmpty) {
      errors[_Field.subject] = "Choose a subject";
    }
    // Never checked before: an enrolment with no units gives the student a
    // subject they cannot open anything inside.
    if (studentViewModel.selectedUnitLength == 0) {
      errors[_Field.units] = "Choose at least one unit";
    }
    if (_validTill == null) {
      errors[_Field.validity] = "Set how long the access lasts";
    }
    return errors;
  }

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the form is still being filled in).
  void _revalidate(StudentViewModel studentViewModel) {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate(studentViewModel);
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  /// Validates the enrol card, then enrols the student in the chosen subject
  /// and units until the chosen date.
  Future<void> _onEnrol(StudentViewModel studentViewModel) async {
    final Map<_Field, String> errors = _validate(studentViewModel);
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      // The inline messages say what is missing; the toast only points the
      // admin at them.
      Helper.showSnackBarMessage(
          msg: errors.length == 1
              ? "Check the highlighted field"
              : "Check the ${errors.length} highlighted fields",
          isSuccess: false);
      return;
    }

    setState(() => _errors.clear());

    await studentViewModel.enrolledCourse(
      _selectedSubjectCode,
      _selectedSubjectName ?? stringDefault,
      _selectedSubjectImage,
      _validTill!.millisecondsSinceEpoch,
      widget.studentId,
      widget.studentName,
    );

    if (!mounted) return;
    setState(() {
      _selectedSubjectName = null;
      _selectedSubjectCode = "";
      _selectedSubjectImage = "";
      _validTill = null;
    });
    studentViewModel.clearUnitList();
  }

  /// Default quick pick. Enrolments run for months or years, so the quick
  /// picks do too; the calendar reaches five years out.
  static const DatePreset _oneYear = DatePreset.months(12, "1 year");

  /// Opens the valid-till calendar for the enrolment.
  Future<void> _pickValidTill() async {
    final DateTime? picked = await showValidTillPicker(
      context,
      title: "Access valid till",
      initial: _validTill,
      presets: const [
        DatePreset.months(3, "3 months"),
        DatePreset.months(6, "6 months"),
        _oneYear,
        DatePreset.months(24, "2 years"),
      ],
      defaultPreset: _oneYear,
    );
    if (picked == null || !mounted) return;
    setState(() => _validTill = picked);
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Students",
      sidebarIndex: 10,
      body: (context, width) => Consumer<StudentViewModel>(
        builder: (context, studentViewModel, child) =>
            _page(studentViewModel, width),
      ),
    );
  }

  /// The scrolling form (header and sections) with the action bar below.
  Widget _page(StudentViewModel studentViewModel, double width) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.symmetric(horizontal: width < 700 ? 16 : 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _pageHeader(),
              const SizedBox(height: AppTokens.gapLg),
              _enrolCard(studentViewModel, width),
              const SizedBox(height: AppTokens.gapMd),
              EnrolledSubjectsCard(
                studentViewModel: studentViewModel,
                studentId: widget.studentId,
              ),
              const SizedBox(height: AppTokens.gapXl),
            ],
          ),
        ),
      ),
    );
  }

  /// Back button, the student's name and a subtitle.
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
              Text(
                  widget.studentName.trim().isEmpty
                      ? "Student"
                      : widget.studentName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.pageTitle),
              const SizedBox(height: 3),
              const Text("What this student can reach, and for how long.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
      ],
    );
  }

  /// The ← button.
  Widget _backButton() {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: () => Navigator.pop(context),
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

  // ---- Enrol ----------------------------------------------------------

  /// "ENROL IN A SUBJECT" card: course, subject, units, validity and the
  /// Enrol button.
  Widget _enrolCard(StudentViewModel studentViewModel, double width) {
    return FormSection(
      title: "ENROL IN A SUBJECT",
      children: [
        FormTwoUp(
            width: width,
            left: _courseField(studentViewModel),
            right: _subjectField(studentViewModel),
            breakpoint: 760),
        const SizedBox(height: AppTokens.gapMd),
        FormTwoUp(
            width: width,
            left: _unitsField(studentViewModel),
            right: _validityField(),
            breakpoint: 760),
        const SizedBox(height: AppTokens.gapLg),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            key: const Key('student_enrol_button'),
            onPressed: () => _onEnrol(studentViewModel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.ink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
            ),
            child: const Text("Enrol",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  /// Course dropdown.
  Widget _courseField(StudentViewModel studentViewModel) {
    final List<CourseModel> courses = studentViewModel.courseList;
    final List<String> names =
        courses.map((c) => c.name).where((n) => n.isNotEmpty).toSet().toList();

    return _dropdownField(
      fieldKey: const Key('enrol_course_dropdown'),
      label: "Course",
      hint: studentViewModel.courseOptions.hintFor(
        hasOptions: names.isNotEmpty,
        loading: "Loading courses…",
        empty: "No courses yet",
        select: "Select a course",
      ),
      value: _selectedCourseName,
      items: names,
      icon: Icons.menu_book_outlined,
      error: _errors[_Field.course],
      enabled: courses.isNotEmpty,
      loadError: studentViewModel.courseOptions.error,
      onRetry: studentViewModel.courseOptions.retry,
      onChanged: (value) {
        setState(() {
          _selectedCourseName = value;
          // firstOrNull, not first: `.first` threw a StateError whenever a
          // course had been renamed or removed since the list loaded.
          _selectedCourseCode = courses
                  .where((c) => c.name == value)
                  .map((c) => c.code)
                  .firstOrNull ??
              "";
          _selectedSubjectName = null;
          _selectedSubjectCode = "";
          _selectedSubjectImage = "";
        });
        studentViewModel.clearSubjectList();
        studentViewModel.clearUnitList();
        if (_selectedCourseCode.isNotEmpty) {
          studentViewModel.getSubjectList(_selectedCourseCode);
        }
        _revalidate(studentViewModel);
      },
    );
  }

  /// Subject dropdown (enabled once a course is chosen).
  Widget _subjectField(StudentViewModel studentViewModel) {
    final List<SubjectModel> subjects = studentViewModel.subjectList;
    final List<String> names =
        subjects.map((s) => s.name).where((n) => n.isNotEmpty).toSet().toList();
    // Only usable once a course has been chosen.
    final bool enabled = _selectedCourseCode.isNotEmpty;

    return _dropdownField(
      fieldKey: const Key('enrol_subject_dropdown'),
      label: "Subject",
      hint: !enabled
          ? "Choose a course first"
          : studentViewModel.subjectOptions.hintFor(
              hasOptions: names.isNotEmpty,
              loading: "Loading subjects…",
              empty: "No subjects in this course",
              select: "Select a subject",
            ),
      value: _selectedSubjectName,
      items: names,
      icon: Icons.library_books_outlined,
      error: _errors[_Field.subject],
      // Disabled while the subjects of the chosen course load.
      enabled: enabled && !studentViewModel.subjectOptions.isLoading,
      loadError: enabled ? studentViewModel.subjectOptions.error : null,
      onRetry: studentViewModel.subjectOptions.retry,
      onChanged: (value) {
        final SubjectModel? subject =
            subjects.where((s) => s.name == value).firstOrNull;
        setState(() {
          _selectedSubjectName = value;
          _selectedSubjectCode = subject?.code ?? "";
          // The subject's own image (saved on the enrolment as `subject_image`).
          _selectedSubjectImage = subject?.image ?? "";
        });
        studentViewModel.clearUnitList();
        if (_selectedSubjectCode.isNotEmpty) {
          studentViewModel.getUnitList(subjectCode: _selectedSubjectCode);
        }
        _revalidate(studentViewModel);
      },
    );
  }

  /// Opens the unit picker; shows how many units are ticked.
  Widget _unitsField(StudentViewModel studentViewModel) {
    final int selected = studentViewModel.selectedUnitLength;
    final int total = studentViewModel.unitList.length;
    final bool subjectChosen = _selectedSubjectCode.isNotEmpty;
    final bool loading = studentViewModel.unitOptions.isLoading;
    final String? loadError = studentViewModel.unitOptions.error;
    final String? error = _errors[_Field.units] ??
        (subjectChosen && loadError != null ? loadError : null);

    return _pickerField(
      fieldKey: const Key('enrol_units_field'),
      label: "Units",
      icon: Icons.layers_outlined,
      isSet: selected > 0,
      enabled: subjectChosen && !loading,
      error: error,
      text: !subjectChosen
          ? "Choose a subject first"
          : loading
              ? "Loading units…"
              : loadError != null
                  ? "Tap to try loading the units again"
                  : selected > 0
                      ? "$selected of $total units"
                      : "Select units",
      onTap: () async {
        // The units failed to load: tapping retries instead of opening an
        // empty picker.
        if (loadError != null) {
          await studentViewModel.unitOptions.retry();
          return;
        }
        await showSlideDialog(context, const EnrolledUnitList());
        if (mounted) _revalidate(studentViewModel);
      },
    );
  }

  /// "Access valid till" picker box.
  Widget _validityField() {
    final String? error = _errors[_Field.validity];

    return _pickerField(
      fieldKey: const Key('enrol_validity_field'),
      label: "Access valid till",
      icon: Icons.event_available_outlined,
      isSet: _validTill != null,
      error: error,
      text: _validTill == null
          ? "Select a date"
          : _displayDate.format(_validTill!),
      onTap: _pickValidTill,
    );
  }

  /// A [FormDropdownField] wired to this form's saving state.
  Widget _dropdownField({
    required Key fieldKey,
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String? error,
    bool enabled = true,
    String? loadError,
    VoidCallback? onRetry,
  }) {
    return FormDropdownField(
      dropdownKey: fieldKey,
      label: label,
      hint: hint,
      value: value,
      items: items,
      icon: icon,
      onChanged: enabled ? onChanged : null,
      error: error,
      enabled: enabled,
      loadError: loadError,
      onRetry: onRetry,
    );
  }

  /// A labelled tappable box that opens a picker (units, date).
  Widget _pickerField({
    required Key fieldKey,
    required String label,
    required IconData icon,
    required String text,
    required bool isSet,
    required VoidCallback onTap,
    bool enabled = true,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Material(
          color: enabled ? AppTokens.surface : AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: InkWell(
            key: fieldKey,
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                    color:
                        error != null ? AppTokens.danger : AppTokens.hairline),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      size: 17,
                      color: isSet ? AppTokens.inkMuted : AppTokens.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              isSet ? FontWeight.w600 : FontWeight.normal,
                          color: isSet ? AppTokens.ink : AppTokens.inkFaint,
                        )),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: AppTokens.inkFaint),
                ],
              ),
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
}
