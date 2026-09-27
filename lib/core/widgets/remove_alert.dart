import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';

/// The confirmation every destructive action in the panel goes through.
///
/// It used to sit flat on the page: `barrierColor: Colors.transparent`, so
/// nothing behind it dimmed and the card read as part of the screen rather
/// than over it. Its two buttons were 25px-tall boxes with **Cancel in red
/// and Yes in blue** — the safe action painted as the dangerous one and the
/// dangerous one painted as safe. And it could not be dismissed at all:
/// `barrierDismissible: false` with `PopScope(canPop: false)` meant no
/// Escape, no tap-outside, only the button.
///
/// **The dialog still does not close itself.** Every caller pops it as the
/// first line of [onPressYes] — that is the contract, and 26 call sites
/// depend on it. Cancel, Escape and the barrier close it as you would
/// expect; only confirming is the caller's to unwind.
class RemoveAlert {
  const RemoveAlert._();

  /// Shows the confirmation.
  ///
  /// [title] is what is being acted on — an item's name, not a sentence.
  /// [confirmLabel] names the action rather than answering a question:
  /// "Delete" is what 24 of the 26 callers mean, and the two sign-out
  /// flows pass their own.
  ///
  /// The returned future completes when the dialog closes, so it can be
  /// awaited. The old one resolved 100ms *before* the dialog even opened.
  static Future<void> showRemoveAlert({
    required String title,
    required String description,
    required Function onPressYes,
    String confirmLabel = "Delete",
  }) async {
    final BuildContext? context = navigatorKey.currentContext;
    // Nothing mounted to host it. The old version did
    // `navigatorKey.currentContext!` and threw.
    if (context == null) return;

    return showGeneralDialog<void>(
      context: context,
      // Escape and a tap outside both cancel. Nothing is destroyed by
      // backing out of a confirmation, so trapping the admin inside it was
      // only ever a way to make a misclick feel expensive.
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: .45),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => _RemoveAlert(
        title: title,
        description: description,
        confirmLabel: confirmLabel,
        onPressYes: onPressYes,
      ),
      transitionBuilder: (context, animation, secondary, child) {
        final CurvedAnimation curve =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        // Rises into place rather than appearing. The scale starts near 1
        // so it reads as the card settling, not as a zoom.
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}

/// The confirmation card itself: icon, title, description, Cancel and the
/// red confirm button.
class _RemoveAlert extends StatelessWidget {
  /// What is being deleted (shown bold).
  final String title;

  /// The question, e.g. "Are you sure want to delete ?".
  final String description;

  /// Text of the red button.
  final String confirmLabel;

  /// Runs when confirmed; it must close the dialog itself.
  final Function onPressYes;

  const _RemoveAlert({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.onPressYes,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppTokens.surface,
                borderRadius: BorderRadius.circular(16),
                // Two shadows rather than one big blur: a tight contact
                // shadow to seat the card, and a wide soft one to lift it
                // off the dimmed page.
                //
                // The wide one carries a negative spread. Without it the
                // blur extends past the card on every side and, against a
                // dimmed backdrop, reads as a second grey slab sitting
                // underneath rather than as depth.
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x26101828),
                      blurRadius: 36,
                      spreadRadius: -8,
                      offset: Offset(0, 12)),
                  BoxShadow(
                      color: Color(0x14101828),
                      blurRadius: 6,
                      spreadRadius: -2,
                      offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // Stretch, not start: the block below centres its children,
                // and it can only do that against the card's full width.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _icon(),
                        const SizedBox(height: AppTokens.gapMd),
                        Text(
                          title,
                          // Not uppercased any more: this is the item's own
                          // name, and shouting a name back at the admin
                          // makes a long one unreadable as well as loud.
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: AppTokens.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(description,
                            textAlign: TextAlign.center, style: AppTokens.body),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.gapLg),
                  _actions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Red bin icon in a tinted circle.
  Widget _icon() {
    return Container(
      height: 44,
      width: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTokens.danger.withValues(alpha: .10),
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.danger.withValues(alpha: .18)),
      ),
      child: const Icon(Icons.warning_amber_rounded,
          size: 22, color: AppTokens.danger),
    );
  }

  /// Cancel and confirm buttons.
  Widget _actions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        color: AppTokens.surfaceMuted,
        border: Border(top: BorderSide(color: AppTokens.hairline)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('remove_alert_cancel'),
              // Focused by default: on a dialog that destroys something,
              // the key that is already under the admin's finger should be
              // the one that does nothing.
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTokens.ink,
                backgroundColor: AppTokens.surface,
                side: const BorderSide(color: AppTokens.hairline),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              ),
              child: const Text("Cancel",
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          Expanded(
            child: ElevatedButton(
              key: const Key('remove_alert_confirm'),
              onPressed: () => onPressYes(),
              style: ElevatedButton.styleFrom(
                // Red is the destructive action, not the way out of it.
                backgroundColor: AppTokens.danger,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              ),
              child: Text(confirmLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
