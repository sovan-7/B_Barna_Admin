import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/screen/add_unit.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/units/widgets/unit_card.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/viewModel/catalogue_filter.dart';
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
      statTiles: (vm) {
        final int? visible = vm.stats["visible"];
        return [
          StatTile.count(
              key: const Key('unit_stat_total'),
              label: "Total",
              count: vm.totalCount),
          StatTile.count(
              key: const Key('unit_stat_visible'),
              label: "Visible",
              count: visible),
          StatTile.count(
              key: const Key('unit_stat_hidden'),
              label: "Hidden",
              count: visible == null ? null : vm.totalCount - visible),
          StatTile.count(
              key: const Key('unit_stat_locked'),
              label: "Locked",
              count: vm.stats["locked"]),
        ];
      },
      chipOptions: [
        for (final CatalogueFilter filter in CatalogueFilter.values)
          FilterOption(filter.name, filter.label,
              key: Key('unit_filter_${filter.name}')),
      ],
      chipMatches: (unit, filter) => CatalogueFilter.values
          .byName(filter)
          .matches(shown: unit.willShow, locked: unit.lockStatus),
      tableColumns: const [
        AdminTableColumn("Unit", flex: 5),
        AdminTableColumn("Code", width: 120),
        AdminTableColumn("Priority", width: 64),
        AdminTableColumn("Status", width: 84),
        AdminTableColumn("Locked", width: 64),
        AdminTableColumn("", width: 76, alignment: Alignment.centerRight),
      ],
      rowId: (unit) => unit.id,
      rowKeyPrefix: "unit",
      tableMinWidth: 760,
      rowCells: (context, unit, hovered, onChanged) => [
        TableIdentity(
          title: unit.name,
          subtitle: [
            TableIdentity.hasText(unit.subjectName)
                ? unit.subjectName
                : "No subject",
            if (TableIdentity.hasText(unit.courseName)) unit.courseName,
            if (unit.subjectCodeList.length > 1)
              "also in ${unit.subjectCodeList.length - 1} more",
          ].join(" · "),
          imageUrl: unit.image,
          initial: unit.code.isEmpty ? "?" : unit.code.characters.first,
        ),
        CodeChip(unit.code),
        TableText("${unit.displayPriority}"),
        StatusPill(unit.willShow ? "Visible" : "Hidden",
            tone: unit.willShow ? StatusTone.success : StatusTone.neutral),
        LockSwitch(
          switchKey: Key('unit_lock_${unit.id}'),
          locked: unit.lockStatus,
          itemLabel: "this unit",
          onChanged: (_) => Provider.of<UnitViewModel>(context, listen: false)
              .toggleLocked(unit),
        ),
        unitActions(context, unit, onChanged, hovered),
      ],
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
