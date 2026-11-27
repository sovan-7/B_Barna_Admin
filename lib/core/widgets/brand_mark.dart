import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The rounded cyan "B" — the app's mark on the login brand panel, at the
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
      decoration: BoxDecoration(
        color: AppTokens.brandMark,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      // Navy, not white: white on this cyan is about 1.7:1.
      child: Text(
        "B",
        style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            height: 1,
            color: AppTokens.onBrandMark),
      ),
    );
  }
}
