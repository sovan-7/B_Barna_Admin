import 'package:bbarna/core/widgets/app_toast.dart';
import 'package:bbarna/resources/app_colors.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// Small app-wide helpers: toasts, a loader, and the locally stored
/// sidebar / module-access preferences.
class Helper {
  /// Shows [msg] as a toast in the corner of the window: green when
  /// [isSuccess], red otherwise. [level] overrides that for messages that
  /// are neither (e.g. a completed delete is shown as info).
  static Future<void> showSnackBarMessage({
    required String msg,
    required bool isSuccess,
    ToastLevel? level,
  }) async {
    AppToast.show(
      message: msg,
      level: level ?? (isSuccess ? ToastLevel.success : ToastLevel.error),
    );
  }

  /// A message that reports something that happened without calling it a
  /// win or a failure.
  static Future<void> showInfoMessage({required String msg}) async {
    AppToast.show(message: msg, level: ToastLevel.info);
  }

  /// A centred animated loader (hexagon dots) in [color].
  Widget showLoader({Color? color = const Color(0xFF8ADDE1)}) {
    return Center(
        child: LoadingAnimationWidget.hexagonDots(
      color: color ?? AppColorsInApp.colorLightBlue,
      size: 80,
    ));
  }

  /// Whether the navigation rail was last left collapsed.
  ///
  /// `sharedPreferences` is late-initialised and throws anywhere it has not
  /// been set up (widget tests included), so failures read as "not
  /// collapsed" rather than taking the screen down.
  static bool isSidebarCollapsed() {
    try {
      return sharedPreferences.getBool(sidebarCollapsedPrefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Remembers whether the navigation rail is collapsed (best effort).
  static void setSidebarCollapsed(bool collapsed) {
    try {
      sharedPreferences.setBool(sidebarCollapsedPrefsKey, collapsed);
    } catch (_) {
      // Not worth surfacing — the rail still works, it just won't remember.
    }
  }

  /// Positions within [moduleList] the signed-in teacher may see, read
  /// from the module list stored at login.
  ///
  /// Falls back to every index (unrestricted) when nothing was stored —
  /// older sessions/accounts without module access, or when
  /// [sharedPreferences] is not initialised (e.g. widget tests).
  static List<int> allowedModuleIndices() {
    List<String>? access;
    try {
      access = sharedPreferences.getStringList(moduleAccessPrefsKey);
    } catch (_) {
      access = null;
    }
    if (access == null || access.isEmpty) {
      return List<int>.generate(moduleList.length, (i) => i);
    }
    return [
      for (int i = 0; i < moduleList.length; i++)
        if (access.contains(moduleList[i])) i,
    ];
  }
}
