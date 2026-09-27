import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// A square picture from [imageUrl], clipped to [radius].
///
/// When there is no URL, or the image fails to load, it shows [initial]
/// (upper-cased) on a grey tile instead, so a card never shows a broken
/// image.
class ImageOrInitial extends StatelessWidget {
  /// Network image; empty/blank means "no picture".
  final String imageUrl;

  /// Fallback letter (or "?").
  final String initial;

  /// Width and height.
  final double size;

  /// Corner radius (use `AppTokens.radiusPill` for a circle).
  final double radius;

  /// Font size of the fallback letter.
  final double fontSize;

  const ImageOrInitial({
    required this.imageUrl,
    required this.initial,
    required this.size,
    this.radius = AppTokens.radiusSm,
    this.fontSize = 16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: size,
        width: size,
        child: imageUrl.trim().isEmpty
            ? _fallback()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _fallback(),
              ),
      ),
    );
  }

  /// The grey tile with the letter.
  Widget _fallback() => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppTokens.inkFaint),
        ),
      );
}
