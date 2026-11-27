import 'package:flutter/material.dart';

/// Whether the person has changed anything on an add/edit page since it
/// opened. One per page, owned by `FormPageBody`.
class FormDirtyController extends ChangeNotifier {
  bool _dirty = false;

  /// Set once the page has gone, so a late mark is ignored.
  bool _disposed = false;

  /// True once a field was changed.
  bool get dirty => _dirty;

  /// Records a change (notifies only the first time).
  void markDirty() {
    if (_dirty || _disposed) return;
    _dirty = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Hands a page's [FormDirtyController] to its fields (which mark it when
/// the person edits them) and to the action bar (which then says
/// "Unsaved changes").
///
/// Every helper tolerates a missing scope, so the shared fields also work
/// outside a form page (dialogs, tests).
class FormDirtyScope extends InheritedNotifier<FormDirtyController> {
  const FormDirtyScope({
    required FormDirtyController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The page's controller, or null outside a form page. Does not rebuild
  /// the caller when the state changes.
  static FormDirtyController? _controller(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FormDirtyScope>()?.notifier;

  /// Records a change on the page [context] sits in. Call it from event
  /// handlers (taps, typing), not from build.
  static void markDirty(BuildContext context) =>
      _controller(context)?.markDirty();

  /// Records a change after this frame — for a field that learns of the
  /// change while building (a newly picked image arriving as new bytes).
  static void markDirtyAfterFrame(BuildContext context) {
    final FormDirtyController? controller = _controller(context);
    if (controller == null || controller.dirty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.markDirty());
  }

  /// Whether the page has unsaved changes; rebuilds the caller when that
  /// changes. False outside a form page.
  static bool isDirty(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FormDirtyScope>()
          ?.notifier
          ?.dirty ??
      false;
}
