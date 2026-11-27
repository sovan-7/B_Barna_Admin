import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/screen/edit_teacher.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Pieces of a teacher's row shared by the wide roster table
// (`TeacherRosterRow`) and the compact card (`TeacherCard`).

/// Amber, the Admin role's colour.
const Color teacherAdminColor = Color(0xFFB54708);

/// Blue, the Subadmin role's colour.
const Color teacherSubadminColor = Color(0xFF2563EB);

/// Green for "Every module".
const Color teacherAllModulesColor = Color(0xFF108460);

/// Positions in [moduleList] of the modules [teacher] can open, in the
/// sidebar's order rather than whatever order the access list happens to be
/// stored in. Modules switched off for everyone are left out.
List<int> grantedModuleIndices(TeacherModel teacher) => [
      for (final int i in moduleNavOrder)
        if (!hiddenModuleIndices.contains(i) &&
            accessGrants(teacher.moduleAccess, i))
          i,
    ];

/// Whether [granted] (from [grantedModuleIndices]) covers every module a
/// teacher can be given.
bool hasEveryModule(List<int> granted) =>
    granted.length >= assignableModuleList.length;

/// "Admin" / "Subadmin" pill.
class TeacherRoleChip extends StatelessWidget {
  /// The teacher's stored role.
  final String role;

  const TeacherRoleChip({required this.role, super.key});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = role == roleAdmin;
    final Color color = isAdmin ? teacherAdminColor : teacherSubadminColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAdmin ? Icons.shield_outlined : Icons.person_outline,
              size: 12, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(isAdmin ? "Admin" : "Subadmin",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

/// One grey chip naming a module: its icon and human label.
class TeacherModuleChip extends StatelessWidget {
  /// Position of the module in [moduleList].
  final int index;

  const TeacherModuleChip({required this.index, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(moduleIconList[index], size: 12, color: AppTokens.inkFaint),
          const SizedBox(width: 5),
          Text(moduleDisplayList[index],
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTokens.inkMuted)),
        ],
      ),
    );
  }
}

/// An icon and a short label in one colour, e.g. "Every module".
class TeacherAccessLine extends StatelessWidget {
  /// The leading icon.
  final IconData icon;

  /// The text.
  final String label;

  /// Colour of both.
  final Color color;

  const TeacherAccessLine(
      {required this.icon,
      required this.label,
      required this.color,
      super.key});

  /// "No module access", in red.
  const TeacherAccessLine.none({super.key})
      : icon = Icons.block,
        label = "No module access",
        color = AppTokens.danger;

  /// "Every module", in green.
  const TeacherAccessLine.all({super.key})
      : icon = Icons.all_inclusive,
        label = "Every module",
        color = teacherAllModulesColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}

/// Opens Edit Teacher for [teacher]; [onChanged] runs if it saved or
/// deleted something.
void openEditTeacher(
    BuildContext context, TeacherModel teacher, VoidCallback onChanged) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => EditTeacher(teacherData: teacher)),
  ).ifSaved(onChanged);
}

/// Asks for confirmation, then deletes [teacher].
void confirmDeleteTeacher(BuildContext context, TeacherModel teacher) {
  final TeacherViewModel teacherViewModel =
      Provider.of<TeacherViewModel>(context, listen: false);
  final String username = teacher.username;

  confirmDelete(
    title: teacher.name,
    delete: () => teacherViewModel.deleteTeacher(username),
    successMessage: "Teacher deleted successfully",
  );
}
