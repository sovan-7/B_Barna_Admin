import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/model/enrolled_course_model.dart';
import 'package:bbarna/student/screen/edit_enrolled_unit.dart';
import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/student/widgets/enrolment_validity.dart';
import 'package:bbarna/student/widgets/slide_dialog.dart';
import 'package:flutter/material.dart';

/// "ENROLLED SUBJECTS" card on the student settings screen: one row per
/// subject the student can reach, with its unit count, its validity (tap
/// to switch between the end date and the time left), and buttons to edit
/// its units or remove it.
class EnrolledSubjectsCard extends StatefulWidget {
  /// Supplies the enrolments and performs edits / removals.
  final StudentViewModel studentViewModel;

  /// The student whose enrolments are shown (reloaded after a removal).
  final String studentId;

  const EnrolledSubjectsCard({
    required this.studentViewModel,
    required this.studentId,
    super.key,
  });

  @override
  State<EnrolledSubjectsCard> createState() => _EnrolledSubjectsCardState();
}

class _EnrolledSubjectsCardState extends State<EnrolledSubjectsCard> {
  /// Subject codes of the rows currently showing "time left" instead of
  /// the end date (each row toggles on its own).
  final Set<String> _showingRemaining = {};

  /// Shortcut for the view model.
  StudentViewModel get _viewModel => widget.studentViewModel;

  @override
  Widget build(BuildContext context) {
    final List<EnrolledCourseModel> enrolled =
        _viewModel.enrolledCourseBaseModel?.enrolledCourseList ?? const [];

    return FormSection(
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
          const _EmptyEnrolments()
        else
          for (final EnrolledCourseModel course in enrolled) _row(course),
      ],
    );
  }

  /// One enrolled subject: thumbnail, name + code, chips and actions.
  Widget _row(EnrolledCourseModel course) {
    final bool showRemaining = _showingRemaining.contains(course.subjectCode);

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
          ImageOrInitial(
            imageUrl: course.subjectImage,
            initial: course.subjectCode.isEmpty
                ? "?"
                : course.subjectCode.characters.first,
            size: 38,
            fontSize: 14,
          ),
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
          _UnitCountChip(units: course.unitCodeList.length),
          const SizedBox(width: 6),
          _ValidityChip(
            course: course,
            showRemaining: showRemaining,
            onToggle: () => setState(() {
              if (!_showingRemaining.remove(course.subjectCode)) {
                _showingRemaining.add(course.subjectCode);
              }
            }),
          ),
          const SizedBox(width: AppTokens.gapSm),
          _actions(course),
        ],
      ),
    );
  }

  /// Edit-units and remove buttons for one row.
  Widget _actions(EnrolledCourseModel course) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: "Edit units",
          child: InkWell(
            key: Key('enrolled_edit_${course.subjectCode}'),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            // Opens the unit picker directly (editing is reversible, so no
            // confirmation first).
            onTap: () async {
              await _viewModel.setEditedUnitList(course.subjectCode);
              if (!mounted) return;
              await showSlideDialog(context, const EditEnrolledUnit());
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
            onTap: () => _confirmRemove(course),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child:
                  Icon(Icons.delete_outline, size: 17, color: AppTokens.danger),
            ),
          ),
        ),
      ],
    );
  }

  /// Asks for confirmation, removes the subject, then reloads the list.
  void _confirmRemove(EnrolledCourseModel course) {
    final String subjectCode = course.subjectCode;
    RemoveAlert.showRemoveAlert(
      title: course.subjectName,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        await _viewModel.removeCourse(subjectCode);
        await _viewModel.getEnrolledCourseList(widget.studentId);
      },
    );
  }
}

/// Placeholder shown when the student has no enrolments.
class _EmptyEnrolments extends StatelessWidget {
  const _EmptyEnrolments();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: const Column(
        children: [
          Icon(Icons.school_outlined, size: 24, color: AppTokens.inkFaint),
          SizedBox(height: 8),
          Text("Not enrolled in anything yet",
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink)),
          SizedBox(height: 3),
          Text("Use the form above to give this student a subject.",
              style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
        ],
      ),
    );
  }
}

/// "3 units" pill; red "No units" when the enrolment covers none.
class _UnitCountChip extends StatelessWidget {
  /// Number of units enrolled.
  final int units;

  const _UnitCountChip({required this.units});

  @override
  Widget build(BuildContext context) {
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
              size: 12, color: none ? AppTokens.danger : AppTokens.inkMuted),
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
}

/// Validity pill: green end date (or time left), red once expired, grey
/// "No end date" when there is none. Tapping swaps date ↔ time left.
class _ValidityChip extends StatelessWidget {
  /// The enrolled subject.
  final EnrolledCourseModel course;

  /// Show the time left instead of the end date.
  final bool showRemaining;

  /// Swaps [showRemaining] for this row.
  final VoidCallback onToggle;

  const _ValidityChip({
    required this.course,
    required this.showRemaining,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool expired = EnrolmentValidity.hasExpired(course.accessTill);
    final String? date = EnrolmentValidity.formatDate(course.accessTill);
    final String? remaining =
        EnrolmentValidity.formatRemaining(course.accessTill);

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
          onTap: date == null ? null : onToggle,
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
}
