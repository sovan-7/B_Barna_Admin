import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/widgets/teacher_access.dart';
import 'package:flutter/material.dart';

/// Width of the edit/delete column.
const double _actionsWidth = 76;

/// Width of the Role column (fits the Subadmin pill).
const double _roleWidth = 112;

/// Width of the Modules column (fits "No module access").
const double _modulesWidth = 150;

/// Left/right padding inside the table.
const double _sidePadding = 16;

/// Size of the photo in the Teacher column.
const double _avatarSize = 32;

/// Gap between the photo and the name.
const double _avatarGap = 10;

/// Lays [teacher], [username] and [phone] out in flexible columns, then
/// [role], [modules] and [actions] in fixed ones (their content has a set
/// size). The header and every
/// row go through here so their columns always line up.
Widget _columns({
  required Widget teacher,
  required Widget username,
  required Widget phone,
  required Widget role,
  required Widget modules,
  required Widget actions,
}) {
  return Row(
    children: [
      Expanded(flex: 5, child: teacher),
      const SizedBox(width: AppTokens.gapMd),
      Expanded(flex: 3, child: username),
      const SizedBox(width: AppTokens.gapMd),
      Expanded(flex: 3, child: phone),
      const SizedBox(width: AppTokens.gapMd),
      SizedBox(
          width: _roleWidth,
          child: Align(alignment: Alignment.centerLeft, child: role)),
      const SizedBox(width: AppTokens.gapSm),
      SizedBox(
          width: _modulesWidth,
          child: Align(alignment: Alignment.centerLeft, child: modules)),
      SizedBox(
          width: _actionsWidth,
          child: Align(alignment: Alignment.centerRight, child: actions)),
    ],
  );
}

/// The teacher list on wide screens: one compact row per teacher under a
/// header (Teacher, Username, Phone, Role, Modules).
///
/// The white box is only as tall as its rows and scrolls once they no
/// longer fit.
class TeacherRosterTable extends StatelessWidget {
  /// The teachers shown, already searched and filtered.
  final List<TeacherModel> teachers;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const TeacherRosterTable(
      {required this.teachers, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.hairline),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _HeaderRow(),
              const Divider(height: 1, thickness: 1, color: AppTokens.hairline),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: teachers.length,
                  separatorBuilder: (context, index) => const Divider(
                      height: 1, thickness: 1, color: AppTokens.hairline),
                  itemBuilder: (context, index) => TeacherRosterRow(
                    key: ValueKey(teachers[index].username),
                    teacherData: teachers[index],
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The column titles.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget title(String text) => Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppTokens.inkFaint));

    return Container(
      color: AppTokens.surfaceMuted.withValues(alpha: .6),
      padding:
          const EdgeInsets.symmetric(horizontal: _sidePadding, vertical: 10),
      child: _columns(
        teacher: title("TEACHER"),
        username: title("USERNAME"),
        phone: title("PHONE"),
        role: title("ROLE"),
        modules: title("MODULES"),
        actions: const SizedBox.shrink(),
      ),
    );
  }
}

/// One teacher in [TeacherRosterTable]. The Modules cell opens the row to
/// list every module the teacher can reach; edit and delete fade in on
/// hover (always shown on compact screens, which have no hover).
class TeacherRosterRow extends StatefulWidget {
  /// The teacher shown.
  final TeacherModel teacherData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const TeacherRosterRow(
      {required this.teacherData, required this.onChanged, super.key});

  @override
  State<TeacherRosterRow> createState() => _TeacherRosterRowState();
}

class _TeacherRosterRowState extends State<TeacherRosterRow> {
  /// True while the mouse pointer is over the row.
  bool _hovered = false;

  /// True while the full module list is open under the row.
  bool _expanded = false;

  /// Shortcut for the teacher shown.
  TeacherModel get _data => widget.teacherData;

  @override
  Widget build(BuildContext context) {
    final List<int> granted = grantedModuleIndices(_data);
    final bool canExpand = granted.isNotEmpty && !hasEveryModule(granted);
    final bool showActions = _hovered ||
        MediaQuery.sizeOf(context).width < AppTokens.compactBreakpoint;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: _hovered || _expanded
            ? AppTokens.surfaceMuted.withValues(alpha: .7)
            : AppTokens.surface,
        padding:
            const EdgeInsets.symmetric(horizontal: _sidePadding, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _columns(
              teacher: _teacherCell(),
              username: _usernameCell(),
              phone: _phoneCell(),
              role: TeacherRoleChip(role: _data.role),
              modules: _modulesCell(granted, canExpand),
              actions: _actions(showActions),
            ),
            if (_expanded && canExpand)
              Padding(
                padding: const EdgeInsets.only(
                    left: _avatarSize + _avatarGap,
                    top: 10,
                    right: _actionsWidth,
                    bottom: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final int index in granted)
                      TeacherModuleChip(index: index),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Photo and name.
  Widget _teacherCell() {
    final String name = _data.name.trim();
    return Row(
      children: [
        ImageOrInitial(
          imageUrl: _data.imageUrl,
          initial: name.isEmpty ? "?" : name.characters.first,
          size: _avatarSize,
          radius: AppTokens.radiusPill,
          fontSize: 13,
        ),
        const SizedBox(width: _avatarGap),
        Flexible(
          child: SelectableLabel(_data.name,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink)),
        ),
      ],
    );
  }

  /// "@" and the username.
  Widget _usernameCell() {
    return Row(
      children: [
        const Text("@",
            style: TextStyle(fontSize: 12.5, color: AppTokens.inkFaint)),
        Flexible(
          child: SelectableLabel(_data.username,
              style:
                  const TextStyle(fontSize: 12.5, color: AppTokens.inkMuted)),
        ),
      ],
    );
  }

  /// The phone number, or a dash when there is none.
  Widget _phoneCell() {
    final String phone = _data.phoneNumber.trim();
    if (phone.isEmpty) {
      return const Text("—",
          style: TextStyle(fontSize: 12.5, color: AppTokens.inkFaint));
    }
    return SelectableLabel(phone,
        style: const TextStyle(fontSize: 12.5, color: AppTokens.inkMuted));
  }

  /// "Every module", "No module access", or "5 of 15" that opens the row.
  Widget _modulesCell(List<int> granted, bool canExpand) {
    if (granted.isEmpty) return const TeacherAccessLine.none();
    if (!canExpand) return const TeacherAccessLine.all();

    return Tooltip(
      message: _expanded ? "Hide modules" : "Show modules",
      child: InkWell(
        key: Key('teacher_modules_toggle_${_data.username}'),
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  "${granted.length} of ${assignableModuleList.length}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.inkMuted),
                ),
              ),
              const SizedBox(width: 2),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: AppTokens.inkFaint),
            ],
          ),
        ),
      ),
    );
  }

  /// Edit and delete.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('teacher_edit_${_data.username}'),
          tooltip: "Edit teacher",
          onTap: () => openEditTeacher(context, _data, widget.onChanged),
        ),
        CardDeleteButton(
          buttonKey: Key('teacher_delete_${_data.username}'),
          tooltip: "Delete teacher",
          onTap: () => confirmDeleteTeacher(context, _data),
        ),
      ],
    );
  }
}
