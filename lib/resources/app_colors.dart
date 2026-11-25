import 'package:flutter/material.dart';

/// The app's older brand / accent colours. Newer UI uses [AppTokens];
/// these remain for the login screen, loaders and legacy widgets.
class AppColorsInApp {
  /// Brand red.
  static const colorPrimary = Colors.red;

  /// Green accent.
  static final colorSecondary = Colors.greenAccent[700];

  /// Plain blue.
  static const colorBlue = Colors.blue;

  /// Plain grey.
  static const colorGrey = Colors.grey;

  /// Half-transparent grey.
  static final colorGreyWhite = Colors.grey.withValues(alpha: .5);

  /// Black.
  static const colorBlack1 = Colors.black;

  /// White.
  static const colorWhite = Colors.white;

  /// Dark yellow.
  static final colorYellow = Colors.yellow[800];

  /// Bright yellow.
  static const colorYellow1 = Colors.yellow;

  /// Light teal-blue used by loaders.
  static const colorLightBlue = Color(0xFF8ADDE1);

  /// Brand orange.
  static const colorOrange = Color(0XFFEB7D24);

  /// Soft red.
  static const colorLightRed = Color(0xFFFF7074);
}
