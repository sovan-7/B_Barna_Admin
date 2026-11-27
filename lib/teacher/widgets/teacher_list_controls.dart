import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/widgets/teacher_access.dart';
import 'package:flutter/material.dart';

/// Three tiles above the teacher list: how many teachers there are, and how
/// many of them are Admins and Subadmins.
class TeacherStatsStrip extends StatelessWidget {
  /// Every teacher.
  final int total;

  /// Teachers with the Admin role.
  final int admins;

  /// Teachers with the Subadmin role.
  final int subadmins;

  const TeacherStatsStrip({
    required this.total,
    required this.admins,
    required this.subadmins,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StatsStrip(
      oneLineMinWidth: 360,
      tiles: [
        StatTile.count(
            key: const Key('teacher_stat_total'), label: "Total", count: total),
        StatTile.count(
            key: const Key('teacher_stat_admins'),
            label: "Admins",
            count: admins,
            valueColor: teacherAdminColor),
        StatTile.count(
            key: const Key('teacher_stat_subadmins'),
            label: "Subadmins",
            count: subadmins,
            valueColor: teacherSubadminColor),
      ],
    );
  }
}

/// All / Admin / Subadmin as a row of filter chips.
class TeacherRoleFilter extends StatelessWidget {
  /// The role shown ([roleAdmin] or [roleSubadmin]), or null for all.
  final String? selected;

  /// Called with the picked role, or null for All.
  final ValueChanged<String?> onChanged;

  const TeacherRoleFilter(
      {required this.selected, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return FilterChipBar<String?>(
      selected: selected,
      onChanged: onChanged,
      options: const [
        FilterOption(null, "All", key: Key('teacher_role_filter_all')),
        FilterOption(roleAdmin, "Admin", key: Key('teacher_role_filter_admin')),
        FilterOption(roleSubadmin, "Subadmin",
            key: Key('teacher_role_filter_subadmin')),
      ],
    );
  }
}
