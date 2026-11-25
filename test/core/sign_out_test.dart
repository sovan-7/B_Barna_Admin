import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/login/model/login_result.dart';
import 'package:bbarna/login/repo/login_repo.dart';
import 'package:bbarna/login/screen/login_screen.dart';
import 'package:bbarna/login/viewModel/login_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Never called — it only has to exist so [LoginViewModel] does not build
/// the real repo, which reaches for `FirebaseFirestore.instance`.
class _StubLoginRepo implements LoginRepo {
  @override
  Future<LoginResult?> signIn(String username, String password) async => null;
}

/// A stand-in for whatever page the admin was on when they hit sign out.
class _SomePage extends StatelessWidget {
  const _SomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [AppHeader(onTapIcon: () {}, title: "Topics")]),
    );
  }
}

Future<void> _signedIn() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    adminIdPrefsKey: "teacher-doc-1",
    moduleAccessPrefsKey: <String>["banners", "course"],
    sidebarCollapsedPrefsKey: true,
  });
  sharedPreferences = await SharedPreferences.getInstance();
}

/// Taps the header's sign-out icon and waits for the alert to settle.
Future<void> _openAlert(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('app_header_sign_out')));
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<LoginViewModel>(
    // Signing out lands on the login screen, which reads this.
    create: (_) => LoginViewModel(loginRepo: _StubLoginRepo()),
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: const _SomePage(),
    ),
  ));
  await tester.pump();
}

void main() {
  group('Session', () {
    test('reads the id login stored, and reports nobody once cleared',
        () async {
      await _signedIn();
      expect(Session.adminId, "teacher-doc-1");
      expect(Session.isSignedIn, isTrue);

      await Session.signOut();

      expect(Session.adminId, isNull);
      expect(Session.isSignedIn, isFalse);
    });

    test('takes the previous user\'s module access with it', () async {
      await _signedIn();
      await Session.signOut();

      // Left behind, the next sign-in would briefly render the previous
      // user's sidebar.
      expect(sharedPreferences.getStringList(moduleAccessPrefsKey), isNull);
    });

    test('leaves the rail preference alone', () async {
      await _signedIn();
      await Session.signOut();

      // Which browser this is, not who is using it.
      expect(sharedPreferences.getBool(sidebarCollapsedPrefsKey), isTrue);
    });
  });

  group('the sign out button', () {
    testWidgets('asks before doing anything', (tester) async {
      await _signedIn();
      await _pump(tester);

      await _openAlert(tester);

      expect(find.text('Sign out'), findsWidgets);
      expect(find.text('Are you sure want to sign out ?'), findsOneWidget);
      // Named after the action, not "Yes" — and the confirm button is the
      // red one now, where Cancel used to be.
      expect(find.byKey(const Key('remove_alert_confirm')), findsOneWidget);
      // Nothing has happened yet.
      expect(Session.isSignedIn, isTrue);
    });

    testWidgets('cancelling leaves the session and the page as they were',
        (tester) async {
      await _signedIn();
      await _pump(tester);

      await _openAlert(tester);
      await tester.tap(find.byKey(const Key('remove_alert_cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_alert_confirm')), findsNothing);
      expect(Session.isSignedIn, isTrue);
      expect(find.byType(_SomePage), findsOneWidget);
    });

    testWidgets('tapping outside backs out of it', (tester) async {
      await _signedIn();
      await _pump(tester);

      await _openAlert(tester);
      // The old alert set barrierDismissible: false and wrapped itself in
      // PopScope(canPop: false), so there was no way out but the button.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('remove_alert_confirm')), findsNothing);
      expect(Session.isSignedIn, isTrue);
    });

    testWidgets('confirming clears the session and lands on the login screen',
        (tester) async {
      await _signedIn();
      await _pump(tester);

      await _openAlert(tester);
      await tester.tap(find.byKey(const Key('remove_alert_confirm')));
      await tester.pumpAndSettle();

      expect(Session.isSignedIn, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(_SomePage), findsNothing);
    });

    testWidgets('nothing is left on the stack to go back to', (tester) async {
      await _signedIn();
      await _pump(tester);

      await _openAlert(tester);
      await tester.tap(find.byKey(const Key('remove_alert_confirm')));
      await tester.pumpAndSettle();

      // pushAndRemoveUntil, not push: otherwise the browser's back button
      // walks straight back into the signed-out admin's pages.
      expect(navigatorKey.currentState!.canPop(), isFalse);
    });
  });
}
