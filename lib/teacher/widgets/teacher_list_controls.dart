import 'package:bbarna/resources/app_tokens.dart';
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
    return Row(
      children: [
        Expanded(
            child: _tile(const Key('teacher_stat_total'), "Total", total,
                AppTokens.ink)),
        const SizedBox(width: AppTokens.gapSm),
        Expanded(
            child: _tile(const Key('teacher_stat_admins'), "Admins", admins,
                teacherAdminColor)),
        const SizedBox(width: AppTokens.gapSm),
        Expanded(
            child: _tile(const Key('teacher_stat_subadmins'), "Subadmins",
                subadmins, teacherSubadminColor)),
      ],
    );
  }

  /// One tile: a small label over a large number.
  Widget _tile(Key key, String label, int value, Color color) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTokens.inkMuted)),
          const SizedBox(height: 2),
          Text("$value",
              style: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

/// All / Admin / Subadmin as one segmented control.
class TeacherRoleFilter extends StatelessWidget {
  /// The role shown ([roleAdmin] or [roleSubadmin]), or null for all.
  final String? selected;

  /// Called with the picked role, or null for All.
  final ValueChanged<String?> onChanged;

  const TeacherRoleFilter(
      {required this.selected, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(const Key('teacher_role_filter_all'), "All", null),
          _segment(const Key('teacher_role_filter_admin'), "Admin", roleAdmin),
          _segment(const Key('teacher_role_filter_subadmin'), "Subadmin",
              roleSubadmin),
        ],
      ),
    );
  }

  /// One part of the control.
  Widget _segment(Key key, String label, String? role) {
    final bool isSelected = selected == role;
    return Material(
      color: isSelected ? AppTokens.surfaceMuted : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm - 2),
      child: InkWell(
        key: key,
        onTap: () => onChanged(role),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm - 2),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTokens.ink : AppTokens.inkMuted)),
        ),
      ),
    );
  }
}
