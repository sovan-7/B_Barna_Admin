import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/login/model/login_result.dart';
import 'package:bbarna/login/repo/login_repo.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/material.dart';

/// State for the login screen: submits the credentials and holds the
/// in-flight flag and the error message shown on the form.
class LoginViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final LoginRepo _loginRepo;
  LoginViewModel({LoginRepo? loginRepo})
      : _loginRepo = loginRepo ?? LoginRepo();

  /// True while the lookup is in flight (the button shows a spinner and
  /// repeated submits are ignored).
  bool isSubmitting = false;

  /// Why the last attempt failed, or null. Shown on the form rather than
  /// in a snackbar floating at the top of the window.
  String? errorMessage;

  /// Hides the error message (called when the user edits a field).
  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  /// Attempts a sign-in and, on success, starts the session.
  ///
  /// Returns true only when there is a session to route on.
  Future<bool> signIn(
      {required String username, required String password}) async {
    if (isSubmitting) return false;

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final LoginResult? result = await _loginRepo.signIn(username, password);
      if (result == null) {
        // Deliberately does not say which of the two was wrong.
        errorMessage = "That username and password do not match.";
        return false;
      }
      await Session.signIn(result);
      return true;
    } catch (e) {
      // A failed lookup (network / server) — reported differently from a
      // wrong password so an outage does not look like bad credentials.
      errorMessage = "Could not reach the server. Check your connection "
          "and try again.";
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
