import 'dart:async';

import 'package:bbarna/core/viewModel/async_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a successful load fills the list and clears loading', () async {
    final AsyncList<int> list = AsyncList<int>();
    int changes = 0;
    await list.load(() async => [1, 2],
        errorMessage: 'failed', onChange: () => changes++);

    expect(list.items, [1, 2]);
    expect(list.isLoading, isFalse);
    expect(list.error, isNull);
    expect(changes, 2); // started, finished
  });

  test('a failure sets the error, and retry runs the same load again',
      () async {
    final AsyncList<int> list = AsyncList<int>();
    bool fail = true;
    await list.load(() async {
      if (fail) throw Exception('offline');
      return [7];
    }, errorMessage: "Couldn't load", onChange: () {});

    expect(list.items, isEmpty);
    expect(list.error, "Couldn't load");

    fail = false;
    await list.retry();
    expect(list.items, [7]);
    expect(list.error, isNull);
  });

  test('an older response that arrives late is ignored', () async {
    final AsyncList<String> list = AsyncList<String>();
    final Completer<List<String>> slow = Completer<List<String>>();

    final Future<void> first =
        list.load(() => slow.future, errorMessage: 'failed', onChange: () {});
    await list.load(() async => ['new'],
        errorMessage: 'failed', onChange: () {});
    slow.complete(['old']);
    await first;

    expect(list.items, ['new']);
    expect(list.isLoading, isFalse);
  });

  test('hintFor picks loading, error, empty or select', () {
    final AsyncList<int> list = AsyncList<int>();
    String hint(bool hasOptions) => list.hintFor(
        hasOptions: hasOptions,
        loading: 'Loading…',
        empty: 'None',
        select: 'Select');

    list.isLoading = true;
    expect(hint(false), 'Loading…');
    list.isLoading = false;
    list.error = "Couldn't load";
    expect(hint(false), "Couldn't load");
    list.error = null;
    expect(hint(false), 'None');
    expect(hint(true), 'Select');
  });
}
