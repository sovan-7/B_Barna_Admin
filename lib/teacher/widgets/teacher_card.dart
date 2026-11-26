import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/widgets/teacher_access.dart';
import 'package:flutter/material.dart';

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
                          TeacherRoleChip(role: _data.role),
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

  /// The modules this teacher can open, as chips.
  Widget _moduleAccess() {
    final List<int> granted = grantedModuleIndices(_data);

    if (granted.isEmpty) return const TeacherAccessLine.none();
    if (hasEveryModule(granted)) return const TeacherAccessLine.all();

    final List<int> shown = granted.take(_visibleModules).toList();
    final int rest = granted.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final int index in shown) TeacherModuleChip(index: index),
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

  /// Opens the edit screen; the list reloads if it saved or deleted
  /// something.
  void _openEdit() => openEditTeacher(context, _data, widget.onChanged);

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() => confirmDeleteTeacher(context, _data);
}
