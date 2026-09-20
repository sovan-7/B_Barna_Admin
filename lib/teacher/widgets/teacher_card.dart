import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/screen/edit_teacher.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One teacher row.
///
/// The module chips used to list every granted module by its stored,
/// upper-case constant — thirteen shouting pills for an admin. They are
/// human labels now, capped at four with the rest counted, and a teacher
/// with everything just says so.
class TeacherCard extends StatefulWidget {
  final TeacherModel teacherData;
  final VoidCallback onChanged;

  const TeacherCard(
      {required this.teacherData, required this.onChanged, super.key});

  @override
  State<TeacherCard> createState() => _TeacherCardState();
}

class _TeacherCardState extends State<TeacherCard> {
  /// How many module chips to show before collapsing the rest into a count.
  static const int _visibleModules = 4;

  bool _hovered = false;

  TeacherModel get _data => widget.teacherData;

  bool get _isAdmin => _data.role == roleAdmin;

  Color get _roleColor =>
      _isAdmin ? const Color(0xFFB54708) : const Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 900;
    final bool showActions = _hovered || isCompact;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: AppTokens.gapSm),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
              color: _hovered
                  ? AppTokens.inkFaint.withValues(alpha: .5)
                  : AppTokens.hairline),
          boxShadow: AppTokens.cardShadow,
        ),
        child: Column(
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
                                    fontSize: 12,
                                    color: AppTokens.inkMuted)),
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
                                    fontSize: 12,
                                    color: AppTokens.inkMuted)),
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
        ),
      ),
    );
  }

  Widget _avatar() {
    final String initial =
        _data.name.trim().isEmpty ? "?" : _data.name.trim().characters.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: SizedBox(
        height: 44,
        width: 44,
        child: _data.imageUrl.trim().isEmpty
            ? _initialAvatar(initial)
            // The fallback used to be the app logo — a white badge, so a
            // broken photo left a white circle on a white card.
            : Image.network(_data.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _initialAvatar(initial)),
      ),
    );
  }

  Widget _initialAvatar(String initial) => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: Text(initial.toUpperCase(),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTokens.inkFaint)),
      );

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
      return _accessLine(Icons.all_inclusive, "Every module",
          const Color(0xFF108460));
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

  Widget _actions(bool visible) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton(
              key: Key('teacher_edit_${_data.username}'),
              icon: Icons.edit_outlined,
              tooltip: "Edit teacher",
              color: AppTokens.inkMuted,
              onTap: _openEdit,
            ),
            const SizedBox(width: 2),
            _iconButton(
              // The delete control had no key at all, so nothing could
              // reach it in a test.
              key: Key('teacher_delete_${_data.username}'),
              icon: Icons.delete_outline,
              tooltip: "Delete teacher",
              color: AppTokens.danger,
              onTap: _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTeacher(teacherData: _data)),
    ).whenComplete(widget.onChanged);
  }

  void _confirmDelete() {
    final TeacherViewModel teacherViewModel =
        Provider.of<TeacherViewModel>(context, listen: false);
    final String username = _data.username;

    RemoveAlert.showRemoveAlert(
      title: _data.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        // RemoveAlert never closes itself, and it is dismissed before the
        // delete so there is no second route in flight. The old flow pushed
        // a loader on top of the alert and then popped twice.
        Navigator.pop(navigatorKey.currentContext!);
        final bool success = await teacherViewModel.deleteTeacher(username);
        if (success) {
          Helper.showInfoMessage(msg: "Teacher deleted successfully");
        }
      },
    );
  }
}
