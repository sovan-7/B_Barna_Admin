import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/screen/edit_course.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the course list: thumbnail, name, code and description;
/// priority / visibility chips and a tappable lock; edit / delete buttons.
/// On narrow screens (< 900px) the sections stack instead of sitting in a
/// row.
class CourseCard extends StatefulWidget {
  /// The item shown in this row.
  final CourseModel courseData;

  /// Called after something changed, so the list can refresh.
  final VoidCallback onChanged;

  const CourseCard(
      {required this.courseData, required this.onChanged, super.key});

  @override
  State<CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<CourseCard> {
  /// Shortcut for the item shown.
  CourseModel get _data => widget.courseData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(),
        actions: _actions(layout.showActions),
      ),
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumbnail(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SelectableLabel(
                      _data.name,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodeChip(_data.code),
                ],
              ),
              if (_data.description.trim().isNotEmpty &&
                  _data.description != stringDefault) ...[
                const SizedBox(height: 4),
                Text(
                  _data.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.body,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The item's picture, or the first letter of its code when there is
  /// none (or it fails to load).
  Widget _thumbnail() {
    return ImageOrInitial(
      imageUrl: _data.image,
      initial: _data.code.isEmpty ? "?" : _data.code.characters.first,
      size: 42,
    );
  }

  /// Priority, visibility and lock as one consistent set of status chips,
  /// rather than a yellow box, a coloured pill and a bare red padlock.
  Widget _chips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: Icons.low_priority,
          label: "Priority ${_data.displayPriority}",
          color: AppTokens.inkMuted,
        ),
        StatusChip(
          icon: _data.willDisplay
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          label: _data.willDisplay ? "Visible" : "Hidden",
          color:
              _data.willDisplay ? const Color(0xFF108460) : AppTokens.inkFaint,
          filled: true,
        ),
        _lockChip(),
      ],
    );
  }

  /// The lock is a control, not a label — it stays a chip so it lines up
  /// with the other two, but it is tappable and says what it will do.
  Widget _lockChip() {
    final bool locked = _data.isLocked;
    final Color color = locked ? const Color(0xFFB54708) : AppTokens.inkFaint;

    return Tooltip(
      message: locked ? "Unlock this course" : "Lock this course",
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          key: Key('course_lock_${_data.docId}'),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onTap: () => Provider.of<CourseViewModel>(context, listen: false)
              .toggleLocked(_data),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: locked
                  ? color.withValues(alpha: .10)
                  : AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                  color: locked
                      ? color.withValues(alpha: .28)
                      : AppTokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_outlined,
                    size: 12,
                    color: color),
                const SizedBox(width: 5),
                Text(locked ? "Locked" : "Unlocked",
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

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('course_edit_${_data.docId}'),
          tooltip: "Edit course",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('course_delete_${_data.docId}'),
          tooltip: "Delete course",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the edit screen; the list reloads when it comes back.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditCourse(courseData: _data)),
    ).whenComplete(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final CourseViewModel courseViewModel =
        Provider.of<CourseViewModel>(context, listen: false);
    final String docId = _data.docId;

    confirmDelete(
      title: _data.name,
      delete: () => courseViewModel.deleteCourse(docId),
      successMessage: "Course deleted successfully",
      onDeleted: () => courseViewModel.getCourseList(),
    );
  }
}
