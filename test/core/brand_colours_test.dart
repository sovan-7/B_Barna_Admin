import 'dart:math' as math;

import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('the one brand colour is the logo gold', () {
    expect(AppTokens.accent, const Color(0xFFDFAA12));
  });

  test('text on gold is dark and readable', () {
    expect(_contrast(AppTokens.onAccent, AppTokens.accent),
        greaterThanOrEqualTo(4.5));
    // White on this gold would not be: the reason text on it is dark.
    expect(_contrast(Colors.white, AppTokens.accent), lessThan(3));
  });

  test('gold text reads on white and on the pale gold', () {
    expect(_contrast(AppTokens.accentInk, AppTokens.surface),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppTokens.accentInk, AppTokens.accentTint),
        greaterThanOrEqualTo(4.5));
  });

  test('the rail is white', () {
    expect(AppTokens.railBackground, AppTokens.surface);
  });
}
