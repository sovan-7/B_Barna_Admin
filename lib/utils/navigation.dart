import 'dart:async';

/// Helpers for screens that report back whether they changed anything.
///
/// Add/Edit forms close with `Navigator.pop(context, true)` after a
/// successful save or delete, and with a plain `pop` on Cancel / Back.
extension SavedResult on Future<Object?> {
  /// Runs [onSaved] only when the pushed screen closed with `true` — so
  /// cancelling a form does not reload the list behind it.
  Future<void> ifSaved(FutureOr<void> Function() onSaved) => then((result) {
        if (result == true) return onSaved();
      });
}
