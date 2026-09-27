import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';

/// The confirmation every destructive action in the panel goes through: a
/// card over a dimmed page, with a neutral Cancel and a red confirm button.
class RemoveAlert {
  const RemoveAlert._();

  /// Shows the confirmation for [title].
  ///
  /// The returned future completes when the dialog closes, so it can be
  /// awaited. [onPressYes] must close the dialog itself.
  static Future<void> showRemoveAlert({
    required String title,
    required String description,
    required Function onPressYes,
    String confirmLabel = "Delete",
  }) async {
    final BuildContext? context = navigatorKey.currentContext;
    // Nothing mounted to host the dialog yet — do nothing.
    if (context == null) return;

    return showGeneralDialog<void>(
      context: context,
      // Escape and a tap outside both cancel — backing out of a confirmation
      // never destroys anything.
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
class _RemoveAlert extends StatefulWidget {
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
  State<_RemoveAlert> createState() => _RemoveAlertState();
}

class _RemoveAlertState extends State<_RemoveAlert> {
  /// True from the first confirm tap until the action finishes: both
  /// buttons are disabled so a double tap cannot run it twice.
  bool _busy = false;

  /// Runs the action once. If it finishes without closing the dialog
  /// (it failed and already said so), the buttons come back to retry.
  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Object? result = widget.onPressYes();
      if (result is Future) await result;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escape and the barrier do nothing while the action is running.
    return PopScope(canPop: !_busy, child: _card(context));
  }

  /// The card: icon, texts and the action bar.
  Widget _card(BuildContext context) {
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
                          widget.title,
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
                        Text(widget.description,
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
              onPressed: _busy ? null : () => Navigator.pop(context),
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
              onPressed: _busy ? null : _confirm,
              style: ElevatedButton.styleFrom(
                // Red is the destructive action, not the way out of it.
                backgroundColor: AppTokens.danger,
                foregroundColor: Colors.white,
                // Stays red while the action runs (only the spinner shows).
                disabledBackgroundColor: AppTokens.danger,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(widget.confirmLabel,
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
