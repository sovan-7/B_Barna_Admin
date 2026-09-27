import 'dart:async';

import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, Function onPressYes) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(),
    ));
    RemoveAlert.showRemoveAlert(
        title: "Physics", description: "Delete?", onPressYes: onPressYes);
    await tester.pumpAndSettle();
  }

  testWidgets('confirm runs once and spins until the action is done',
      (tester) async {
    final Completer<void> deleting = Completer<void>();
    int calls = 0;
    await open(tester, () async {
      calls++;
      await deleting.future;
      Navigator.pop(navigatorKey.currentContext!);
    });

    await tester.tap(find.byKey(const Key('remove_alert_confirm')));
    await tester.pump();
    // A double tap used to delete twice.
    await tester.tap(find.byKey(const Key('remove_alert_confirm')));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final OutlinedButton cancel =
        tester.widget(find.byKey(const Key('remove_alert_cancel')));
    expect(cancel.onPressed, isNull);

    deleting.complete();
    await tester.pumpAndSettle();
    expect(find.text("Physics"), findsNothing);
  });

  testWidgets('an action that fails without closing can be retried',
      (tester) async {
    int calls = 0;
    // Like enrolment removal: on failure it toasts and leaves the dialog.
    await open(tester, () async {
      calls++;
    });

    await tester.tap(find.byKey(const Key('remove_alert_confirm')));
    await tester.pump();

    final ElevatedButton confirm =
        tester.widget(find.byKey(const Key('remove_alert_confirm')));
    expect(confirm.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('remove_alert_confirm')));
    await tester.pump();
    expect(calls, 2);
  });
}
