import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The row of small icon buttons at the end of a card (edit, delete, …).
///
/// Fades in when [visible] (hover / compact screens) and ignores taps while
/// hidden. [buttons] are spaced 2px apart.
class CardActions extends StatelessWidget {
  /// Whether the buttons are shown and tappable.
  final bool visible;

  /// The buttons, usually [CardIconButton]s.
  final List<Widget> buttons;

  const CardActions({required this.visible, required this.buttons, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A small tappable icon with a tooltip, used for card actions.
class CardIconButton extends StatelessWidget {
  /// The icon shown.
  final IconData icon;

  /// Shown on hover, e.g. "Edit PDF".
  final String tooltip;

  /// Icon colour.
  final Color color;

  /// Runs when tapped.
  final VoidCallback onTap;

  /// Key on the tappable [InkWell] (tests tap through it).
  final Key? buttonKey;

  const CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.buttonKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

/// Grey pencil button — the usual "Edit …" card action.
class CardEditButton extends StatelessWidget {
  /// Hover text, e.g. "Edit PDF".
  final String tooltip;

  /// Opens the edit screen.
  final VoidCallback onTap;

  /// Key on the tappable [InkWell] (tests tap through it).
  final Key? buttonKey;

  const CardEditButton(
      {required this.tooltip, required this.onTap, this.buttonKey, super.key});

  @override
  Widget build(BuildContext context) {
    return CardIconButton(
      buttonKey: buttonKey,
      icon: Icons.edit_outlined,
      tooltip: tooltip,
      color: AppTokens.inkMuted,
      onTap: onTap,
    );
  }
}

/// Red bin button — the usual "Delete …" card action.
class CardDeleteButton extends StatelessWidget {
  /// Hover text, e.g. "Delete PDF".
  final String tooltip;

  /// Starts the delete (usually with a confirmation).
  final VoidCallback onTap;

  /// Key on the tappable [InkWell] (tests tap through it).
  final Key? buttonKey;

  const CardDeleteButton(
      {required this.tooltip, required this.onTap, this.buttonKey, super.key});

  @override
  Widget build(BuildContext context) {
    return CardIconButton(
      buttonKey: buttonKey,
      icon: Icons.delete_outline,
      tooltip: tooltip,
      color: AppTokens.danger,
      onTap: onTap,
    );
  }
}
