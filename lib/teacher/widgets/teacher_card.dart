import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/screen/edit_teacher.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the teacher list: photo, name, role, username and phone,
/// with the modules they can access underneath (human labels, capped at
/// four with the rest counted; "All modules" when they have everything).
class TeacherCard extends StatefulWidget {
  /// The item shown in this row.
  final TeacherModel teacherData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const TeacherCard(
      {required this.teacherData, required this.onChanged, super.key});

  @override
  State<TeacherCard> createState() => _TeacherCardState();
}

class _TeacherCardState extends State<TeacherCard> {
  /// How many module chips to show before collapsing the rest into a count.
  static const int _visibleModules = 4;

  /// Shortcut for the item shown.
  TeacherModel get _data => widget.teacherData;

  /// Whether this teacher has the Admin role.
  bool get _isAdmin => _data.role == roleAdmin;

  /// Amber for Admin, blue for Subadmin.
  Color get _roleColor =>
      _isAdmin ? const Color(0xFFB54708) : const Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) {
        final bool showActions = layout.showActions;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(),
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
                          _roleChip(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.alternate_email,
                              size: 12, color: AppTokens.inkFaint),
                          const SizedBox(width: 5),
                          Flexible(
                            child: SelectableLabel(_data.username,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTokens.inkMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 12, color: AppTokens.inkFaint),
                          const SizedBox(width: 5),
                          Flexible(
                            child: SelectableLabel(
                                _data.phoneNumber.trim().isEmpty
                                    ? "No phone"
                                    : _data.phoneNumber,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTokens.inkMuted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.gapSm),
                _actions(showActions),
              ],
            ),
            const SizedBox(height: 12),
            _moduleAccess(),
          ],
        );
      },
    );
  }

  /// Round profile photo, or the first letter of the name.
  Widget _avatar() {
    return ImageOrInitial(
      imageUrl: _data.imageUrl,
      initial:
          _data.name.trim().isEmpty ? "?" : _data.name.trim().characters.first,
      size: 44,
      radius: AppTokens.radiusPill,
    );
  }

  /// "Admin" / "Subadmin" pill.
  Widget _roleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _roleColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: _roleColor.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_isAdmin ? Icons.shield_outlined : Icons.person_outline,
              size: 12, color: _roleColor),
          const SizedBox(width: 5),
          Text(_isAdmin ? "Admin" : "Subadmin",
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: _roleColor)),
        ],
      ),
    );
  }

  /// The modules this teacher can open, as chips.
  Widget _moduleAccess() {
    // Positions in moduleList, so the chips keep the sidebar's order rather
    // than whatever order the access list happens to be stored in.
    final List<int> granted = [
      for (int i = 0; i < moduleList.length; i++)
        if (_data.moduleAccess.contains(moduleList[i])) i,
    ];

    if (granted.isEmpty) {
      return _accessLine(Icons.block, "No module access", AppTokens.danger);
    }
    if (granted.length == moduleList.length) {
      return _accessLine(
          Icons.all_inclusive, "Every module", const Color(0xFF108460));
    }

    final List<int> shown = granted.take(_visibleModules).toList();
    final int rest = granted.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final int index in shown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(moduleIconList[index],
                    size: 12, color: AppTokens.inkFaint),
                const SizedBox(width: 5),
                Text(moduleDisplayList[index],
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppTokens.inkMuted)),
              ],
            ),
          ),
        if (rest > 0)
          Tooltip(
            message: granted
                .skip(_visibleModules)
                .map((i) => moduleDisplayList[i])
                .join(", "),
            child: Text("+$rest more",
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.inkFaint)),
          ),
      ],
    );
  }

  /// One icon + label line used by [_moduleAccess].
  Widget _accessLine(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('teacher_edit_${_data.username}'),
          tooltip: "Edit teacher",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('teacher_delete_${_data.username}'),
          tooltip: "Delete teacher",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the edit screen; the list reloads when it closes.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTeacher(teacherData: _data)),
    ).whenComplete(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final TeacherViewModel teacherViewModel =
        Provider.of<TeacherViewModel>(context, listen: false);
    final String username = _data.username;

    confirmDelete(
      title: _data.name,
      delete: () => teacherViewModel.deleteTeacher(username),
      successMessage: "Teacher deleted successfully",
    );
  }
}
