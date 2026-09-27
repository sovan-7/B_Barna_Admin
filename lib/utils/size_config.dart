import 'package:flutter/cupertino.dart';

/// Global cache of the window size, filled by `MyApp.build`.
///
/// Only as fresh as the last rebuild that called [init]; new code should
/// read `MediaQuery.of(context)` instead.
class SizeConfig {
  /// The last MediaQuery read by [init].
  static MediaQueryData? _mediaQueryData;

  /// Window width at the last [init].
  static double? screenWidth;

  /// Window height at the last [init].
  static double? screenHeight;

  /// Stores the current window size from [context].
  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData!.size.width; // full screen width
    screenHeight = _mediaQueryData!.size.height; // full screen height
  }
}
