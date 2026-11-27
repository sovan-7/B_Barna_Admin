import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// What a [StatusPill] says about its row, which picks its colours.
enum StatusTone {
  /// Visible, sent, free, active.
  success,

  /// Locked, paid, needs attention.
  warning,

  /// Failed, expired, live now.
  danger,

  /// Upcoming, informational.
  info,

  /// Hidden, pending, no data.
  neutral;

  /// Background tint.
  Color get fill => switch (this) {
        StatusTone.success => AppTokens.successFill,
        StatusTone.warning => AppTokens.warningFill,
        StatusTone.danger => AppTokens.dangerFill,
        StatusTone.info => AppTokens.infoFill,
        StatusTone.neutral => AppTokens.surfaceMuted,
      };

  /// Text and icon colour on [fill].
  Color get text => switch (this) {
        StatusTone.success => AppTokens.successText,
        StatusTone.warning => AppTokens.warningText,
        StatusTone.danger => AppTokens.dangerText,
        StatusTone.info => AppTokens.infoText,
        StatusTone.neutral => AppTokens.inkMuted,
      };
}

/// A small tinted pill for a row's state ("Visible", "Paid", "Failed").
/// Optionally led by an icon or a dot (a dot reads as "live").
class StatusPill extends StatelessWidget {
  /// Pill text.
  final String label;

  /// Colours.
  final StatusTone tone;

  /// Leading icon, or nothing.
  final IconData? icon;

  /// A leading dot instead of an icon.
  final bool dot;

  const StatusPill(
    this.label, {
    this.tone = StatusTone.neutral,
    this.icon,
    this.dot = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = tone.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.fill,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              height: 6,
              width: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

/// A compact switch for a row's lock flag. While [busy] (the flip is being
/// saved) it shows a small spinner and ignores taps.
class LockSwitch extends StatelessWidget {
  /// Whether the item is locked.
  final bool locked;

  /// Flips the flag; the switch is read-only when null.
  final ValueChanged<bool>? onChanged;

  /// True while the change is being saved.
  final bool busy;

  /// What the item is called in the tooltip ("this course").
  final String itemLabel;

  /// Key on the switch (tests tap through it).
  final Key? switchKey;

  const LockSwitch({
    required this.locked,
    required this.onChanged,
    this.busy = false,
    this.itemLabel = "this item",
    this.switchKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 20,
        width: 36,
        child: Center(
          child: SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTokens.accent),
          ),
        ),
      );
    }
    return Tooltip(
      message: locked ? "Unlock $itemLabel" : "Lock $itemLabel",
      child: SizedBox(
        height: 22,
        child: FittedBox(
          child: Switch(
            key: switchKey,
            value: locked,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTokens.accent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppTokens.hairline,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
