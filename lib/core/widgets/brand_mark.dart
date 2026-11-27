import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The round "B" in a gold ring — the app's mark on the login brand panel, at the
/// top of the navigation rail and in the compact header, so all three read
/// as one app.
class BrandMark extends StatelessWidget {
  /// Width and height of the mark.
  final double size;

  const BrandMark({this.size = 32, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      // Like the logo: a gold ring around a dark B on white.
      decoration: BoxDecoration(
        color: AppTokens.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppTokens.accent, width: size * 0.08),
      ),
      child: Text(
        "B",
        style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            height: 1,
            color: AppTokens.ink),
      ),
    );
  }
}
