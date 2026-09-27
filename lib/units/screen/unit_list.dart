import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/screen/add_unit.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/units/widgets/unit_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The unit list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the unit-specific texts and card,
/// and preloads the course list the Add/Edit Unit form needs.
class UnitList extends StatelessWidget {
  const UnitList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<UnitViewModel, UnitModel>(
      title: "Units",
      subtitle: "Newest first. Each unit sits under one subject.",
      addButtonLabel: "NEW UNIT",
      addScreenBuilder: (context) => const AddUnit(),
      searchHint: "Search by unit code",
      skeletonRowHeight: 82,
      emptyIcon: Icons.layers_outlined,
      emptyTitle: "No units yet",
      emptyMessage: "Units sit under a subject, and topics hang off them.",
      filteredMessage:
          "No unit code starts with that. Search matches the code, not the name.",
      emptyAddLabel: "Add a unit",
      onFirstFrame: _preloadCourses,
      itemBuilder: (context, unit, onChanged) => UnitCard(
        key: ValueKey(unit.id),
        unitData: unit,
        onChanged: onChanged,
      ),
    );
  }

  /// The add/edit form needs the course list for its course picker; load
  /// it once if nothing has yet.
  static void _preloadCourses(BuildContext context) {
    final CourseViewModel courseViewModel =
        Provider.of<CourseViewModel>(context, listen: false);
    if (courseViewModel.allCourses.isEmpty) courseViewModel.getCourseList();
  }
}
