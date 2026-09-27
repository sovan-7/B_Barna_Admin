import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/screen/edit_unit.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the unit list: thumbnail, name, code and its course ›
/// subject breadcrumb; priority, visibility and a tappable lock; edit /
/// delete buttons.
class UnitCard extends StatefulWidget {
  /// The item shown in this row.
  final UnitModel unitData;

  /// Called after something changed, so the list can refresh.
  final VoidCallback onChanged;

  const UnitCard({required this.unitData, required this.onChanged, super.key});

  @override
  State<UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends State<UnitCard> {
  /// Shortcut for the item shown.
  UnitModel get _data => widget.unitData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(),
        actions: _actions(layout.showActions),
      ),
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _thumbnail(),
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
                  CodeChip(_data.code),
                ],
              ),
              const SizedBox(height: 4),
              // Where the unit sits: course › subject, as one breadcrumb
              // line.
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      size: 12, color: AppTokens.inkFaint),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _breadcrumb(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTokens.inkMuted),
                    ),
                  ),
                ],
              ),
              if (_data.subjectCodeList.length > 1) ...[
                const SizedBox(height: 4),
                Text(
                  // A unit can be shared across several subjects.
                  "Also in ${_data.subjectCodeList.length - 1} more subject"
                  "${_data.subjectCodeList.length - 1 == 1 ? '' : 's'}",
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTokens.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Course › Subject" style path of where this item sits.
  String _breadcrumb() {
    final String course =
        _data.courseName.isEmpty || _data.courseName == stringDefault
            ? "No course"
            : _data.courseName;
    final String subject =
        _data.subjectName.isEmpty || _data.subjectName == stringDefault
            ? "No subject"
            : _data.subjectName;
    return "$course  ›  $subject";
  }

  /// The item's picture, or the first letter of its code when there is
  /// none (or it fails to load).
  Widget _thumbnail() {
    return ImageOrInitial(
      imageUrl: _data.image,
      initial: _data.code.isEmpty ? "?" : _data.code.characters.first,
      size: 46,
    );
  }

  /// Status chips shown beside (or, when compact, under) the identity.
  Widget _chips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: Icons.low_priority,
          label: "Priority ${_data.displayPriority}",
          color: AppTokens.inkMuted,
        ),
        // Visible / hidden, read from the unit's `willShow` flag.
        StatusChip(
          icon: _data.willShow
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          label: _data.willShow ? "Visible" : "Hidden",
          color: _data.willShow ? const Color(0xFF108460) : AppTokens.inkFaint,
          filled: _data.willShow,
        ),
        _lockChip(),
      ],
    );
  }

  /// The lock is a control, not a label — it stays a chip so it lines up
  /// with the other two, but it is tappable and says what it will do.
  Widget _lockChip() {
    final bool locked = _data.lockStatus;
    final Color color = locked ? const Color(0xFFB54708) : AppTokens.inkFaint;

    return Tooltip(
      message: locked ? "Unlock this unit" : "Lock this unit",
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          key: Key('unit_lock_${_data.id}'),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onTap: () => Provider.of<UnitViewModel>(context, listen: false)
              .toggleLocked(_data),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: locked
                  ? color.withValues(alpha: .10)
                  : AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                  color: locked
                      ? color.withValues(alpha: .28)
                      : AppTokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    locked
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_outlined,
                    size: 12,
                    color: color),
                const SizedBox(width: 5),
                Text(locked ? "Locked" : "Unlocked",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('unit_edit_${_data.id}'),
          tooltip: "Edit unit",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('unit_delete_${_data.id}'),
          tooltip: "Delete unit",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the edit screen; the list reloads if it saved or deleted
  /// something.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditUnit(unitData: _data)),
    ).ifSaved(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final UnitViewModel unitViewModel =
        Provider.of<UnitViewModel>(context, listen: false);
    final String docId = _data.id;

    confirmDelete(
      title: _data.name,
      delete: () => unitViewModel.deleteUnit(docId),
      successMessage: "Unit deleted successfully",
    );
  }
}
