import 'dart:async';

/// A list that is fetched on demand — typically a form dropdown's options
/// (the subjects of the chosen course, the teachers, …) — together with its
/// loading and error state.
///
/// * [load] clears the old options straight away, so a picker never offers
///   options that belong to a previous choice while the new ones load.
/// * Only the newest [load] updates the list: an older response that
///   arrives late is dropped.
/// * A failure leaves the list empty and sets [error], so the screen can say
///   "Couldn't load …" (and offer [retry]) instead of "none found".
class AsyncList<T> {
  /// The options; empty while loading or after a failure.
  List<T> items = [];

  /// True while a load is running.
  bool isLoading = false;

  /// Why the last load failed, or null.
  String? error;

  /// Incremented per load; responses from older loads are ignored.
  int _request = 0;

  /// The last load, so [retry] can run it again.
  Future<void> Function()? _last;

  /// Fetches the options with [fetch]. [onChange] is called whenever the
  /// state changes (usually the view model's `notifyListeners`), and
  /// [onLoaded] after a successful load (for follow-up state).
  Future<void> load(
    Future<List<T>> Function() fetch, {
    required String errorMessage,
    required void Function() onChange,
    void Function(List<T> items)? onLoaded,
  }) {
    _last = () => load(fetch,
        errorMessage: errorMessage, onChange: onChange, onLoaded: onLoaded);
    return _run(fetch, errorMessage, onChange, onLoaded);
  }

  Future<void> _run(
    Future<List<T>> Function() fetch,
    String errorMessage,
    void Function() onChange,
    void Function(List<T> items)? onLoaded,
  ) async {
    final int request = ++_request;
    items = [];
    isLoading = true;
    error = null;
    onChange();
    try {
      final List<T> result = await fetch();
      if (request != _request) return;
      items = result;
      onLoaded?.call(result);
    } catch (e) {
      if (request != _request) return;
      error = errorMessage;
    } finally {
      if (request == _request) {
        isLoading = false;
        onChange();
      }
    }
  }

  /// The dropdown hint for the current state: [loading] while loading, the
  /// error after a failure, [empty] when there are no options, otherwise
  /// [select].
  String hintFor({
    required bool hasOptions,
    required String loading,
    required String empty,
    required String select,
  }) {
    if (isLoading) return loading;
    if (error != null && !hasOptions) return error!;
    return hasOptions ? select : empty;
  }

  /// Runs the last [load] again (e.g. from a "Retry" link).
  Future<void> retry() => _last?.call() ?? Future<void>.value();

  /// Empties the list and forgets any load still in flight.
  void reset() {
    _request++;
    items = [];
    isLoading = false;
    error = null;
  }
}
