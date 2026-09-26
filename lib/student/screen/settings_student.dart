import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/core/widgets/valid_till_picker.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/model/enrolled_course_model.dart';
import 'package:bbarna/student/screen/edit_enrolled_unit.dart';
import 'package:bbarna/student/screen/enrolled_unit_list.dart';
import 'package:bbarna/student/viewModel/student_viewmodel.dart';
import 'package:bbarna/student/widgets/enrolment_validity.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// A student's enrolments: what they can reach, and adding more.
///
/// The page was one 700-line `build` nested about twenty levels deep, with
/// every control pinned at `width: 350` and spaced by a bare
/// `SizedBox(height: 60)`. It is two cards now — enrol, and what they are
/// already enrolled in.
class SettingStudent extends StatefulWidget {
  final String studentId;
  final String studentName;

  const SettingStudent(
      {required this.studentId, required this.studentName, super.key});

  @override
  State<SettingStudent> createState() => _SettingStudentState();
}

/// The fields of the enrol form that can carry an inline error.
enum _Field { course, subject, units, validity }

class _SettingStudentState extends State<SettingStudent> {
  final GlobalKey<ScaffoldState> key = GlobalKey();

  String? _selectedCourseName;
  String _selectedCourseCode = "";
  String? _selectedSubjectName;
  String _selectedSubjectCode = "";
  String _selectedSubjectImage = "";

  DateTime? _validTill;

  /// Which enrolled rows are showing "time left" rather than the date.
  ///
  /// This was a single bool shared by every row, so tapping one row's chip
  /// flipped all of them at once.
  final Set<String> _showingRemaining = {};

  final Map<_Field, String> _errors = {};

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

  void _revalidate(StudentViewModel studentViewModel) {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate(studentViewModel);
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  Future<void> _onEnrol(StudentViewModel studentViewModel) async {
    final Map<_Field, String> errors = _validate(studentViewModel);
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      // The inline messages name what is missing; this only has to get the
      // admin looking at them. It used to say "Please fill the above field"
      // whatever was wrong, with nothing marked on any field.
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

  /// Enrolments run for months or years, so the quick picks do too. The
  /// calendar still reaches five years out -- a year used to be the hard
  /// ceiling, so a two-year enrolment could not be entered at all.
  static const DatePreset _oneYear = DatePreset.months(12, "1 year");

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
              title: "Students",
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isCompact)
                    const Expanded(child: ExtraSideBar(sidebarIndex: 10)),
                  Expanded(
                    flex: 5,
                    child: Consumer<StudentViewModel>(
                      builder: (context, studentViewModel, child) =>
                          _page(studentViewModel, width),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Read from MediaQuery, not the SizeConfig global, which is only as
      // fresh as the last screen that set it.
      drawer: isCompact
          ? const Drawer(child: ExtraSideBar(sidebarIndex: 10))
          : null,
    );
  }

  Widget _page(StudentViewModel studentViewModel, double width) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: width < 700 ? 16 : 32, vertical: 24),
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
              _enrolledCard(studentViewModel),
              const SizedBox(height: AppTokens.gapXl),
            ],
          ),
        ),
      ),
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
              Text(widget.studentName.trim().isEmpty
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

  Widget _section({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
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
          Row(
            children: [
              Text(title, style: AppTokens.sectionTitle),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: AppTokens.gapMd),
          ...children,
        ],
      ),
    );
  }

  // ---- Enrol ----------------------------------------------------------

  Widget _enrolCard(StudentViewModel studentViewModel, double width) {
    return _section(
      title: "ENROL IN A SUBJECT",
      children: [
        _twoUp(
          width,
          _courseField(studentViewModel),
          _subjectField(studentViewModel),
        ),
        const SizedBox(height: AppTokens.gapMd),
        _twoUp(
          width,
          _unitsField(studentViewModel),
          _validityField(),
        ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
            ),
            child: const Text("Enrol",
                style:
                    TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _twoUp(double width, Widget left, Widget right) {
    if (width < 760) {
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

  Widget _courseField(StudentViewModel studentViewModel) {
    final List<CourseModel> courses = studentViewModel.courseList;
    final List<String> names =
        courses.map((c) => c.name).where((n) => n.isNotEmpty).toSet().toList();

    return _dropdownField(
      fieldKey: const Key('enrol_course_dropdown'),
      label: "Course",
      hint: courses.isEmpty ? "Loading courses…" : "Select a course",
      value: _selectedCourseName,
      items: names,
      icon: Icons.menu_book_outlined,
      error: _errors[_Field.course],
      enabled: courses.isNotEmpty,
      onChanged: (value) {
        setState(() {
          _selectedCourseName = value;
          // firstOrNull, not first: `.first` threw a StateError whenever a
          // course had been renamed or removed since the list loaded.
          _selectedCourseCode =
              courses.where((c) => c.name == value).map((c) => c.code).firstOrNull ??
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

  Widget _subjectField(StudentViewModel studentViewModel) {
    final List<SubjectModel> subjects = studentViewModel.subjectList;
    final List<String> names =
        subjects.map((s) => s.name).where((n) => n.isNotEmpty).toSet().toList();
    // The old gate was `courseList.isEmpty` — it watched the *course list*
    // rather than the chosen course, so this was open before you had picked
    // anything and never closed again.
    final bool enabled = _selectedCourseCode.isNotEmpty;

    return _dropdownField(
      fieldKey: const Key('enrol_subject_dropdown'),
      label: "Subject",
      hint: !enabled
          ? "Choose a course first"
          : names.isEmpty
              ? "No subjects in this course"
              : "Select a subject",
      value: _selectedSubjectName,
      items: names,
      icon: Icons.library_books_outlined,
      error: _errors[_Field.subject],
      enabled: enabled,
      onChanged: (value) {
        final SubjectModel? subject =
            subjects.where((s) => s.name == value).firstOrNull;
        setState(() {
          _selectedSubjectName = value;
          _selectedSubjectCode = subject?.code ?? "";
          // The subject's own image. This was taken from the *course* and
          // then saved as `subject_image`, so every enrolled row showed the
          // course picture under the subject's name.
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

  Widget _unitsField(StudentViewModel studentViewModel) {
    final int selected = studentViewModel.selectedUnitLength;
    final int total = studentViewModel.unitList.length;
    final bool enabled = _selectedSubjectCode.isNotEmpty;
    final String? error = _errors[_Field.units];

    return _pickerField(
      fieldKey: const Key('enrol_units_field'),
      label: "Units",
      icon: Icons.layers_outlined,
      isSet: selected > 0,
      enabled: enabled,
      error: error,
      text: !enabled
          ? "Choose a subject first"
          : selected > 0
              ? "$selected of $total units"
              : "Select units",
      onTap: () async {
        await _showSlideDialog(const EnrolledUnitList());
        if (mounted) _revalidate(studentViewModel);
      },
    );
  }

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
              key: fieldKey,
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
              // DropdownButton uses `style` verbatim rather than merging
              // it, and this State's context sits above the Scaffold's
              // Material — inheriting DefaultTextStyle there picks up
              // WidgetsApp's yellow double-underline error style.
              style: (Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle())
                  .copyWith(
                fontSize: 13.5,
                color: AppTokens.ink,
                decoration: TextDecoration.none,
              ),
              onChanged: enabled ? onChanged : null,
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
        Text(label, style: _labelStyle),
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
                      color:
                          isSet ? AppTokens.inkMuted : AppTokens.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              isSet ? FontWeight.w600 : FontWeight.normal,
                          color:
                              isSet ? AppTokens.ink : AppTokens.inkFaint,
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

  static const TextStyle _labelStyle = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));

  Future<void> _showSlideDialog(Widget child) {
    return showGeneralDialog(
      context: context,
      barrierLabel: "Barrier",
      barrierDismissible: true,
      // Transparent left the page fully lit behind the dialog, so it never
      // read as a layer on top.
      barrierColor: Colors.black.withValues(alpha: .35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => Center(child: child),
      transitionBuilder: (_, anim, __, dialog) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: dialog,
        ),
      ),
    );
  }

  // ---- Enrolled -------------------------------------------------------

  Widget _enrolledCard(StudentViewModel studentViewModel) {
    final List<EnrolledCourseModel> enrolled =
        studentViewModel.enrolledCourseBaseModel?.enrolledCourseList ??
            const [];

    return _section(
      title: "ENROLLED SUBJECTS",
      trailing: Text(
        enrolled.isEmpty
            ? "None"
            : "${enrolled.length} subject${enrolled.length == 1 ? '' : 's'}",
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.ink),
      ),
      children: [
        if (enrolled.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: const Column(
              children: [
                Icon(Icons.school_outlined,
                    size: 24, color: AppTokens.inkFaint),
                SizedBox(height: 8),
                Text("Not enrolled in anything yet",
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink)),
                SizedBox(height: 3),
                Text("Use the form above to give this student a subject.",
                    style:
                        TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
              ],
            ),
          )
        else
          for (final EnrolledCourseModel course in enrolled)
            _enrolledRow(studentViewModel, course),
      ],
    );
  }

  Widget _enrolledRow(
      StudentViewModel studentViewModel, EnrolledCourseModel course) {
    final bool showRemaining = _showingRemaining.contains(course.subjectCode);
    final bool expired = EnrolmentValidity.hasExpired(course.accessTill);
    final String? date = EnrolmentValidity.formatDate(course.accessTill);
    final String? remaining =
        EnrolmentValidity.formatRemaining(course.accessTill);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.gapSm),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        children: [
          _thumbnail(course),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.subjectName.isEmpty ||
                          course.subjectName == stringDefault
                      ? "Untitled subject"
                      : course.subjectName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink),
                ),
                const SizedBox(height: 2),
                Text(course.subjectCode,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: AppTokens.inkFaint)),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          _unitChip(course),
          const SizedBox(width: 6),
          _validityChip(course, showRemaining, expired, date, remaining),
          const SizedBox(width: AppTokens.gapSm),
          _rowActions(studentViewModel, course),
        ],
      ),
    );
  }

  Widget _thumbnail(EnrolledCourseModel course) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: SizedBox(
        height: 38,
        width: 38,
        child: course.subjectImage.trim().isEmpty
            ? _thumbFallback(course)
            // A fixed square, cropped. It was 50px with `BoxFit.fill` and
            // a 60px fallback, so a broken image squashed the picture and
            // changed the row height.
            : Image.network(course.subjectImage,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _thumbFallback(course)),
      ),
    );
  }

  Widget _thumbFallback(EnrolledCourseModel course) => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: Text(
          course.subjectCode.isEmpty
              ? "?"
              : course.subjectCode.characters.first.toUpperCase(),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTokens.inkFaint),
        ),
      );

  Widget _unitChip(EnrolledCourseModel course) {
    final int units = course.unitCodeList.length;
    final bool none = units == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: none
            ? AppTokens.danger.withValues(alpha: .10)
            : AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
            color: none
                ? AppTokens.danger.withValues(alpha: .28)
                : AppTokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined,
              size: 12,
              color: none ? AppTokens.danger : AppTokens.inkMuted),
          const SizedBox(width: 5),
          Text(none ? "No units" : "$units unit${units == 1 ? '' : 's'}",
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: none ? AppTokens.danger : AppTokens.inkMuted)),
        ],
      ),
    );
  }

  /// Tapping swaps this row between the end date and the time left. It
  /// used to flip a flag shared by every row at once.
  Widget _validityChip(EnrolledCourseModel course, bool showRemaining,
      bool expired, String? date, String? remaining) {
    final Color color = expired
        ? AppTokens.danger
        : (date == null ? AppTokens.inkFaint : const Color(0xFF108460));
    final String label = date == null
        ? "No end date"
        : showRemaining
            ? (remaining ?? "—")
            : date;

    return Tooltip(
      message: date == null
          ? "This enrolment has no end date"
          : showRemaining
              ? "Show the end date"
              : "Show the time left",
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          key: Key('enrolled_validity_${course.subjectCode}'),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onTap: date == null
              ? null
              : () => setState(() {
                    if (!_showingRemaining.remove(course.subjectCode)) {
                      _showingRemaining.add(course.subjectCode);
                    }
                  }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: color.withValues(alpha: .28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(expired ? Icons.event_busy : Icons.event_available,
                    size: 12, color: color),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowActions(
      StudentViewModel studentViewModel, EnrolledCourseModel course) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: "Edit units",
          child: InkWell(
            key: Key('enrolled_edit_${course.subjectCode}'),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            // Straight into the picker. It used to raise a "Are you sure
            // want to edit ?" confirmation first — a destructive-action
            // dialog in front of a reversible one.
            onTap: () async {
              await studentViewModel.setEditedUnitList(course.subjectCode);
              if (!mounted) return;
              await _showSlideDialog(const EditEnrolledUnit());
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.edit_outlined,
                  size: 17, color: AppTokens.inkMuted),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Tooltip(
          message: "Remove this subject",
          child: InkWell(
            key: Key('enrolled_remove_${course.subjectCode}'),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            onTap: () => _confirmRemove(studentViewModel, course),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.delete_outline,
                  size: 17, color: AppTokens.danger),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRemove(
      StudentViewModel studentViewModel, EnrolledCourseModel course) {
    final String subjectCode = course.subjectCode;
    RemoveAlert.showRemoveAlert(
      title: course.subjectName,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        await studentViewModel.removeCourse(subjectCode);
        await studentViewModel.getEnrolledCourseList(widget.studentId);
      },
    );
  }
}
