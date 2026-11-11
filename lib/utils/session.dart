import 'package:bbarna/login/model/login_result.dart';
import 'package:bbarna/resources/constant.dart';

/// The signed-in admin's session: the teacher document id, their module
/// list and their role, all kept in SharedPreferences. All reads and writes
/// of those keys go through here so signing in and out always handle every
/// one of them.
class Session {
  const Session._();

  /// The signed-in teacher's document id, or null when nobody is signed in.
  ///
  /// Guarded like [Helper.allowedModuleIndices]: `sharedPreferences` is
  /// late-initialized and throws anywhere it has not been set up, widget
  /// tests included.
  static String? get adminId {
    try {
      return sharedPreferences.getString(adminIdPrefsKey);
    } catch (_) {
      return null;
    }
  }

  /// Whether someone is signed in.
  static bool get isSignedIn => adminId != null;

  /// Whether the signed-in user has the [roleAdmin] role.
  ///
  /// False for a session started before the role was stored (it has no
  /// role key); such a session keeps its module list until the next
  /// sign-in.
  static bool get isAdmin {
    try {
      return sharedPreferences.getString(rolePrefsKey) == roleAdmin;
    } catch (_) {
      return false;
    }
  }

  /// Starts a session for the user [result] identifies (writes every
  /// session key; the counterpart of [signOut]).
  static Future<void> signIn(LoginResult result) async {
    try {
      await sharedPreferences.setString(adminIdPrefsKey, result.adminId);
      await sharedPreferences.setStringList(
          moduleAccessPrefsKey, result.moduleAccess);
      await sharedPreferences.setString(rolePrefsKey, result.role);
    } catch (_) {
      // No store to write to. The sign-in still stands for this session;
      // it just will not survive a reload.
    }
  }

  /// Clears the session.
  ///
  /// Only the session keys go: `sidebar_collapsed` is a preference about
  /// this browser, not about who is using it, so the rail stays how it was
  /// left for whoever signs in next. Module access and role, on the other
  /// hand, are the previous user's — leaving them behind would let the
  /// next sign-in briefly render their sidebar.
  static Future<void> signOut() async {
    try {
      await sharedPreferences.remove(adminIdPrefsKey);
      await sharedPreferences.remove(moduleAccessPrefsKey);
      await sharedPreferences.remove(rolePrefsKey);
    } catch (_) {
      // Nothing to clear — there was no store to clear it from.
    }
  }
}
