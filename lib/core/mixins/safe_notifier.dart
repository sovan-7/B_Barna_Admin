import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Makes a [ChangeNotifier] safe to notify from anywhere in the frame.
///
/// Every list screen is mounted from `Sidebar.screenList[selectedIndex]`
/// *during* a build. A view model that notifies synchronously at that
/// moment makes Flutter throw "setState() or markNeedsBuild() called during
/// build". This mixin fixes that in one place for every view model:
///
/// * While the framework is building (the `persistentCallbacks` phase) the
///   notification is postponed to the end of the current frame.
/// * Outside a build it notifies straight away, exactly like
///   [ChangeNotifier.notifyListeners].
/// * After [dispose] every notification is dropped, so an async call that
///   finishes after the screen has gone does not throw
///   "used after being disposed".
///
/// Usage: `class FooViewModel extends ChangeNotifier with SafeNotifier`.
mixin SafeNotifier on ChangeNotifier {
  /// Set by [dispose]; once true, [notifyListeners] does nothing.
  bool _disposed = false;

  /// Whether this notifier has been disposed.
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    // The screen that owned us is gone — nobody is listening any more.
    if (_disposed) return;

    // Mid-build: wait until the frame has finished, then notify (unless we
    // were disposed in the meantime).
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        super.notifyListeners();
      });
      return;
    }

    // Any other time: notify right away.
    super.notifyListeners();
  }
}
