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
        // Paid / locked: outlined, so it reads apart from the filled gold.
        border: tone == StatusTone.warning
            ? Border.all(color: AppTokens.accent)
            : null,
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
    // The key sits on this box in both states, so a test (or a tap) finds
    // the control whether it shows the switch or the spinner.
    return SizedBox(
      key: switchKey,
      height: 22,
      width: 40,
      child: busy
          ? const Center(
              child: SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTokens.accent),
              ),
            )
          : Tooltip(
              message: locked ? "Unlock $itemLabel" : "Lock $itemLabel",
              child: FittedBox(
                child: Switch(
                  value: locked,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTokens.accent,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppTokens.hairline,
                  trackOutlineColor:
                      WidgetStateProperty.all(Colors.transparent),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
    );
  }
}

/// A yes/no flag as one icon button in a table cell (Popular star,
/// Downloadable arrow): filled and tinted when on, faint when off, a
/// spinner while [busy].
class FlagIconToggle extends StatelessWidget {
  /// The flag's value.
  final bool on;

  /// Icon while on.
  final IconData onIcon;

  /// Icon while off.
  final IconData offIcon;

  /// Tint while on.
  final Color onColor;

  /// What tapping does while on / off.
  final String onTooltip;
  final String offTooltip;

  /// Flips the flag.
  final VoidCallback onTap;

  /// True while the change is being saved.
  final bool busy;

  /// Key on the tappable button (tests tap through it).
  final Key? buttonKey;

  const FlagIconToggle({
    required this.on,
    required this.onIcon,
    required this.offIcon,
    required this.onColor,
    required this.onTooltip,
    required this.offTooltip,
    required this.onTap,
    this.busy = false,
    this.buttonKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Keyed in both states, like [LockSwitch].
    return SizedBox(
      key: buttonKey,
      height: 28,
      width: 28,
      child: busy
          ? Center(
              child: SizedBox(
                height: 16,
                width: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: onColor),
              ),
            )
          : Tooltip(
              message: on ? onTooltip : offTooltip,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                onTap: onTap,
                child: Icon(on ? onIcon : offIcon,
                    size: 20, color: on ? onColor : AppTokens.inkFaint),
              ),
            ),
    );
  }
}
