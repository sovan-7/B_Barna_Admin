import 'package:flutter/widgets.dart';

/// Wraps [provider] so the image is decoded no larger than needed for a
/// square box of [side] logical pixels, instead of at its full stored size.
///
/// Photos are shown with `BoxFit.cover`, whose shorter side must still fill
/// the box, so the decode fits within 3× the box: sharp for aspect ratios up
/// to 3:1, while a 4000px photo in a 40px thumbnail is no longer decoded
/// at 4000px. Smaller images are never scaled up.
ImageProvider sizedForBox(
    BuildContext context, ImageProvider provider, double side) {
  final int pixels =
      (side * MediaQuery.devicePixelRatioOf(context) * 3).round();
  return ResizeImage(provider,
      width: pixels, height: pixels, policy: ResizeImagePolicy.fit);
}
