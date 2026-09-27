import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:flutter/material.dart';

/// Picks which units of a subject a student can reach.
///
/// The add flow and the edit flow each had their own copy of this dialog,
/// one line apart and both carrying the same defect (see [isSelected]).
/// They share one widget now; the caller supplies the two lists and the
/// callbacks that differ.
class UnitPickerDialog extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// The units of the chosen subject.
  final List<UnitModel> units;

  /// Index-aligned with [units]: the unit's own code when it is selected,
  /// an empty string when it is not.
  final List<String> selection;

  final ValueChanged<int> onToggle;
  final VoidCallback onToggleAll;
  final VoidCallback onSave;
  final String saveLabel;
  final bool isLoading;

  const UnitPickerDialog({
    required this.title,
    required this.units,
    required this.selection,
    required this.onToggle,
    required this.onToggleAll,
    required this.onSave,
    this.subtitle,
    this.saveLabel = "Save",
    this.isLoading = false,
    super.key,
  });

  /// Whether the unit at [index] is selected.
  ///
  /// Compared, not `contains`ed. Both dialogs did
  /// `selection[index].contains(unit.code)` — a substring test on a String,
  /// so a unit coded `U1` read as selected whenever the slot held `U10`.
  bool isSelected(int index) =>
      index < selection.length && selection[index] == units[index].code;

  int get selectedCount => selection.where((code) => code.isNotEmpty).length;

  bool get allSelected => units.isNotEmpty && selectedCount == units.length;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Material(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          // Sized to the window rather than pinned at 600x600, which
          // overflowed on anything smaller.
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screen.height * .82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(context),
              Flexible(child: _body()),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTokens.inkMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          Tooltip(
            message: "Close",
            child: InkWell(
              key: const Key('unit_picker_close'),
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18, color: AppTokens.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: AppTokens.inkFaint),
          ),
        ),
      );
    }

    if (units.isEmpty) {
      // A subject with no units: explain rather than show an empty box.
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.layers_outlined, size: 28, color: AppTokens.inkFaint),
            SizedBox(height: 10),
            Text("This subject has no units yet",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            SizedBox(height: 3),
            Text("Add units to the subject before enrolling a student in it.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shrinkWrap: true,
      itemCount: units.length,
      itemBuilder: (context, index) => _row(index),
    );
  }

  Widget _row(int index) {
    final UnitModel unit = units[index];
    final bool selected = isSelected(index);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? const Color(0xFF2563EB).withValues(alpha: .06)
            : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: InkWell(
          // The whole row toggles, not just the checkbox.
          key: Key('unit_picker_row_${unit.code}'),
          onTap: () => onToggle(index),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB).withValues(alpha: .35)
                      : AppTokens.hairline),
            ),
            child: Row(
              children: [
                _thumbnail(unit),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name.isEmpty || unit.name == stringDefault
                            ? "Untitled unit"
                            : unit.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(unit.code,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: AppTokens.inkFaint)),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.gapSm),
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color:
                      selected ? const Color(0xFF2563EB) : AppTokens.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The unit's picture as a fixed 38px square, cropped (a letter tile
  /// when missing), so every row has the same height.
  Widget _thumbnail(UnitModel unit) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: SizedBox(
        height: 38,
        width: 38,
        child: unit.image.trim().isEmpty
            ? _fallback(unit)
            : Image.network(unit.image,
                fit: BoxFit.cover, errorBuilder: (c, e, s) => _fallback(unit)),
      ),
    );
  }

  Widget _fallback(UnitModel unit) => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: Text(
          unit.code.isEmpty ? "?" : unit.code.characters.first.toUpperCase(),
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTokens.inkFaint),
        ),
      );

  Widget _footer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              // How many units are ticked, out of the total.
              "$selectedCount of ${units.length} selected",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppTokens.inkMuted),
            ),
          ),
          const Spacer(),
          if (units.isNotEmpty)
            TextButton(
              key: const Key('unit_picker_toggle_all'),
              onPressed: onToggleAll,
              style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: Text(allSelected ? "Clear all" : "Select all",
                  style: const TextStyle(fontSize: 12.5)),
            ),
          const SizedBox(width: AppTokens.gapSm),
          ElevatedButton(
            key: const Key('unit_picker_save'),
            onPressed: units.isEmpty ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.ink,
              disabledBackgroundColor: AppTokens.ink.withValues(alpha: .4),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
            ),
            child: Text(saveLabel,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
