import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The course list on wide screens: one row per course with its code,
/// priority, visibility, an inline lock switch, and edit / delete on hover.
class CourseTable extends StatelessWidget {
  /// The courses shown, already searched and filtered.
  final List<CourseModel> courses;

  /// Called after an edit so the list can reload.
  final VoidCallback onChanged;

  const CourseTable(
      {required this.courses, required this.onChanged, super.key});

  /// Narrowest list width the table is used at (cards below it).
  static const double minWidth = 720;

  static const List<AdminTableColumn> _columns = [
    AdminTableColumn("Course", flex: 5),
    AdminTableColumn("Code", width: 120),
    AdminTableColumn("Priority", width: 64),
    AdminTableColumn("Status", width: 84),
    AdminTableColumn("Locked", width: 64),
    AdminTableColumn("", width: 76, alignment: Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminTable(
      columns: _columns,
      rowCount: courses.length,
      rowKey: (i) => ValueKey('course_row_${courses[i].docId}'),
      cellsBuilder: (context, i, hovered) {
        final CourseModel course = courses[i];
        return [
          TableIdentity(
            title: course.name,
            subtitle: course.description,
            imageUrl: course.image,
            initial: course.code.isEmpty ? "?" : course.code.characters.first,
          ),
          CodeChip(course.code),
          TableText("${course.displayPriority}"),
          StatusPill(course.willDisplay ? "Visible" : "Hidden",
              tone:
                  course.willDisplay ? StatusTone.success : StatusTone.neutral),
          LockSwitch(
            switchKey: Key('course_lock_${course.docId}'),
            locked: course.isLocked,
            itemLabel: "this course",
            onChanged: (_) =>
                Provider.of<CourseViewModel>(context, listen: false)
                    .toggleLocked(course),
          ),
          courseActions(context, course, onChanged, hovered),
        ];
      },
    );
  }
}
