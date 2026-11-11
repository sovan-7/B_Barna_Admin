import 'package:bbarna/core/widgets/app_toast.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester,
    {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigatorKey,
    home: const Scaffold(body: SizedBox.expand()),
  ));
  await tester.pump();
}

/// Runs the entry animation out.
Future<void> _settleIn(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  tearDown(AppToast.dismissAll);

  group('showing', () {
    testWidgets('puts the message on screen with its level', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Topic added successfully", isSuccess: true);
      await _settleIn(tester);

      expect(find.text('Topic added successfully'), findsOneWidget);
      expect(find.text('Success'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('a failure reads as one', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Could not save", isSuccess: false);
      await _settleIn(tester);

      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('a completed delete is neither', (tester) async {
      await _pumpApp(tester);

      // These used to go through `isSuccess: false`, so every successful
      // delete was reported in the same red as a failure.
      Helper.showInfoMessage(msg: "Topic deleted successfully");
      await _settleIn(tester);

      expect(find.text('Notice'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('level overrides the flag', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(
          msg: "Removed", isSuccess: false, level: ToastLevel.info);
      await _settleIn(tester);

      expect(find.text('Notice'), findsOneWidget);
    });

    testWidgets('two messages stack rather than queue', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "First", isSuccess: true);
      Helper.showSnackBarMessage(msg: "Second", isSuccess: false);
      await _settleIn(tester);

      // ScaffoldMessenger showed one snackbar at a time and queued the
      // rest, so the second was four seconds away.
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('the same message twice does not stack a copy',
        (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Check the highlighted field", isSuccess: false);
      await _settleIn(tester);
      Helper.showSnackBarMessage(msg: "Check the highlighted field", isSuccess: false);
      await _settleIn(tester);

      expect(find.text('Check the highlighted field'), findsOneWidget);
      expect(AppToast.messages, hasLength(1));
    });

    testWidgets('beyond the cap the oldest is dropped', (tester) async {
      await _pumpApp(tester);

      for (int i = 0; i < AppToast.maxVisible + 2; i++) {
        Helper.showSnackBarMessage(msg: "Message $i", isSuccess: true);
      }
      await _settleIn(tester);

      expect(AppToast.messages, hasLength(AppToast.maxVisible));
      expect(find.text('Message 0'), findsNothing);
      expect(find.text('Message 5'), findsOneWidget);
    });

    testWidgets('with no app mounted it does nothing instead of throwing',
        (tester) async {
      // The old version reached straight for `navigatorKey.currentContext!`.
      Helper.showSnackBarMessage(msg: "Nowhere to put this", isSuccess: false);
      expect(AppToast.messages, isEmpty);
    });
  });

  group('dismissing', () {
    testWidgets('goes on its own after the timeout', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Saved", isSuccess: true);
      await _settleIn(tester);
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(AppToast.duration);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Saved'), findsNothing);
      expect(AppToast.messages, isEmpty);
    });

    testWidgets('the close button takes it away', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Saved", isSuccess: true);
      await _settleIn(tester);

      // The snackbar had no visible way to dismiss it — only an undisclosed
      // swipe-up gesture.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('the pointer resting on it holds it open', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Read me", isSuccess: true);
      await _settleIn(tester);

      final TestGesture pointer =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(find.text('Read me')));
      await tester.pump();

      // Well past the timeout, and still up.
      await tester.pump(AppToast.duration * 2);
      expect(find.text('Read me'), findsOneWidget);

      // Moving away lets the countdown finish.
      await pointer.moveTo(Offset.zero);
      await tester.pump();
      await tester.pump(AppToast.duration);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Read me'), findsNothing);
    });

    testWidgets('dismissAll clears the lot', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "One", isSuccess: true);
      Helper.showSnackBarMessage(msg: "Two", isSuccess: true);
      await _settleIn(tester);

      AppToast.dismissAll();
      await tester.pump();

      expect(find.text('One'), findsNothing);
      expect(find.text('Two'), findsNothing);
    });
  });

  group('layout', () {
    testWidgets('sits in the top-right on a wide window', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(msg: "Saved", isSuccess: true);
      await _settleIn(tester);

      final Rect card = tester.getRect(find
          .ancestor(of: find.text('Saved'), matching: find.byType(ClipRRect))
          .first);
      expect(card.top, lessThan(120));
      expect(card.right, greaterThan(1280 - 60));
      // Bounded, not the full width the old snackbar took.
      expect(card.width, lessThanOrEqualTo(400));
    });

    testWidgets('goes full width on a phone', (tester) async {
      await _pumpApp(tester, size: const Size(380, 820));

      Helper.showSnackBarMessage(msg: "Saved", isSuccess: true);
      await _settleIn(tester);

      final Rect card = tester.getRect(find
          .ancestor(of: find.text('Saved'), matching: find.byType(ClipRRect))
          .first);
      expect(card.width, greaterThan(300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long message is bounded instead of growing', (tester) async {
      await _pumpApp(tester);

      Helper.showSnackBarMessage(
          msg: "An extremely long failure message that goes on well past "
              "anything that would fit in a corner of the window, repeated "
              "again and again and again so that it cannot possibly fit in "
              "four lines of text at this width whatsoever.",
          isSuccess: false);
      await _settleIn(tester);

      expect(tester.takeException(), isNull);
      final Rect card = tester.getRect(find
          .ancestor(
              of: find.textContaining('An extremely long'),
              matching: find.byType(ClipRRect))
          .first);
      expect(card.height, lessThan(200));
    });
  });
}
