import 'package:flutter/material.dart';

/// Shows [child] centred over a dimmed page, fading and scaling in slightly.
/// Tapping outside closes it. Used for the unit pickers on the student
/// settings screen.
Future<void> showSlideDialog(BuildContext context, Widget child) {
  return showGeneralDialog(
    context: context,
    barrierLabel: "Barrier",
    barrierDismissible: true,
    // Dim the page so the dialog reads as a layer on top of it.
    barrierColor: Colors.black.withValues(alpha: .35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => Center(child: child),
    transitionBuilder: (_, anim, __, dialog) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: .96, end: 1)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: dialog,
      ),
    ),
  );
}
