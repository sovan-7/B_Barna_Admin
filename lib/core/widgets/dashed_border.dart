import 'dart:ui';

import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// Paints a dashed rounded outline — the "drop / browse here" look of the
/// image pickers and the Upload a banner tile.
class DashedBorderPainter extends CustomPainter {
  /// Outline colour.
  final Color color;

  /// Corner radius.
  final double radius;

  const DashedBorderPainter({
    this.color = AppTokens.inkFaint,
    this.radius = AppTokens.radiusMd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final Path outline = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.7), Radius.circular(radius)));
    for (final PathMetric metric in outline.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
