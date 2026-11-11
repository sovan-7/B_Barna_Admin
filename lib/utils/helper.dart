import 'package:bbarna/core/widgets/app_toast.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/session.dart';

/// Small app-wide helpers: toasts and the locally stored
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

  /// Positions within [moduleList] the signed-in teacher may see.
  ///
  /// An admin sees every module. Their stored module list is deliberately
  /// not consulted: it was saved when their account was last edited, so a
  /// module added to the panel since then (Books, say) would otherwise
  /// stay hidden from the very person who has to grant it to others.
  ///
  /// Anyone else sees only the modules in the list stored at login, and
  /// never Teachers: managing accounts (and so creating admins) is the
  /// admin's alone, whatever the list says. An empty or missing list, or a
  /// store that cannot be read, grants nothing.
  ///
  /// Nobody sees a module in [hiddenModuleIndices].
  static List<int> allowedModuleIndices() {
    if (Session.isAdmin) {
      return [
        for (int i = 0; i < moduleList.length; i++)
          if (!hiddenModuleIndices.contains(i)) i,
      ];
    }

    List<String> access;
    try {
      access = sharedPreferences.getStringList(moduleAccessPrefsKey) ?? [];
    } catch (_) {
      access = [];
    }
    return [
      for (int i = 0; i < moduleList.length; i++)
        if (i != teacherModuleIndex &&
            i != transactionModuleIndex &&
            !hiddenModuleIndices.contains(i) &&
            access.contains(moduleList[i]))
          i,
    ];
  }
}
