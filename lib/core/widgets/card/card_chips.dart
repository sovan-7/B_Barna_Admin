import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The small grey box showing an item's code (e.g. "NOTES-01") next to its
/// title. The text can be selected and copied.
class CodeChip extends StatelessWidget {
  /// The code to show.
  final String code;

  const CodeChip(this.code, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: SelectableLabel(code,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppTokens.inkMuted)),
    );
  }
}

/// A read-only pill: icon + label.
///
/// [filled] tints the background and border with [color] (e.g. the green
/// FREE / amber PAID chip); otherwise it is grey with a coloured icon and
/// label.
class StatusChip extends StatelessWidget {
  /// Leading icon.
  final IconData icon;

  /// Chip text.
  final String label;

  /// Icon and text colour (and tint when [filled]).
  final Color color;

  /// Tints the background and border with [color].
  final bool filled;

  const StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: .10) : AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
            color: filled ? color.withValues(alpha: .28) : AppTokens.hairline),
      ),
      child: _ChipContent(icon: icon, label: label, color: color),
    );
  }
}

/// A pill that is also a switch: it shows the current state of a flag and
/// flips it when tapped (e.g. Locked / Unlocked).
///
/// When [on], it is tinted with [onColor]; when off it is grey.
class ToggleChip extends StatelessWidget {
  /// Leading icon.
  final IconData icon;

  /// Chip text (describes the current state).
  final String label;

  /// Current value of the flag.
  final bool on;

  /// Tint used while [on].
  final Color onColor;

  /// What tapping will do, e.g. "Lock this PDF".
  final String tooltip;

  /// Flips the flag.
  final VoidCallback onTap;

  /// Key on the tappable [InkWell] (tests tap through it).
  final Key? buttonKey;

  /// True while the flip is being saved: the chip ignores taps and shows
  /// a small spinner in place of its icon.
  final bool busy;

  const ToggleChip({
    required this.icon,
    required this.label,
    required this.on,
    required this.onColor,
    required this.tooltip,
    required this.onTap,
    this.buttonKey,
    this.busy = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = on ? onColor : AppTokens.inkFaint;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: on ? color.withValues(alpha: .10) : AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                  color:
                      on ? color.withValues(alpha: .28) : AppTokens.hairline),
            ),
            child: _ChipContent(
                icon: icon, label: label, color: color, busy: busy),
          ),
        ),
      ),
    );
  }
}

/// Icon + label inside a chip.
class _ChipContent extends StatelessWidget {
  /// Leading icon.
  final IconData icon;

  /// Text.
  final String label;

  /// Icon and text colour.
  final Color color;

  /// Shows a spinner in place of the icon.
  final bool busy;

  const _ChipContent(
      {required this.icon,
      required this.label,
      required this.color,
      this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          )
        else
          Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
