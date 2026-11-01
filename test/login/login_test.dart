import 'dart:async';

import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/repo/banners_repo.dart';
import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/login/model/login_result.dart';
import 'package:bbarna/login/repo/login_repo.dart';
import 'package:bbarna/login/screen/login_screen.dart';
import 'package:bbarna/login/viewModel/login_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLoginRepo extends Mock implements LoginRepo {}

class MockBannersRepo extends Mock implements BannersRepo {}

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockLoginRepo repo;
late MockBannersRepo bannersRepo;

Future<void> _emptyStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sharedPreferences = await SharedPreferences.getInstance();
}

Future<LoginViewModel> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final LoginViewModel vm = LoginViewModel(loginRepo: repo);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<LoginViewModel>.value(value: vm),
      // Signing in lands on the Sidebar, whose first screen is the banner
      // list — so the route it pushes has to be able to build.
      ChangeNotifierProvider<BannersViewModel>(
          create: (_) => BannersViewModel(bannersRepo: bannersRepo)),
    ],
    child: MaterialApp(navigatorKey: navigatorKey, home: const LoginScreen()),
  ));
  await tester.pump();
  return vm;
}

void main() {
  setUp(() async {
    repo = MockLoginRepo();
    bannersRepo = MockBannersRepo();
    when(() => repo.signIn(any(), any())).thenAnswer((_) async => null);
    when(() => bannersRepo.getBannersList())
        .thenAnswer((_) async => <BannersModel>[]);
    await _emptyStore();
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}', (tester) async {
        await _pump(tester, size);

        expect(tester.takeException(), isNull);
        expect(find.text('Sign in'), findsWidgets);
      });
    }

    testWidgets('the brand panel is dropped on a narrow window',
        (tester) async {
      await _pump(tester, const Size(1440, 900));
      expect(find.text('BBARNA'), findsOneWidget);

      await _pump(tester, const Size(700, 900));
      // Nothing to put it beside — the form takes the whole width.
      expect(find.text('BBARNA'), findsNothing);
    });

    testWidgets('the brand mark keeps its shape on a narrow window',
        (tester) async {
      await _pump(tester, const Size(380, 820));

      // The form column stretches its children, so an unaligned square
      // mark gets pulled out to the full width.
      final Size mark = tester.getSize(find.ancestor(
          of: find.text('B'), matching: find.byType(Container)).first);
      expect(mark.width, mark.height);
    });

    testWidgets('a short window still reaches the button', (tester) async {
      // The old page had no scroll view at all, so the button was simply
      // off-screen here.
      await _pump(tester, const Size(1024, 380));

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_submit')), findsOneWidget);
    });
  });

  group('the password field', () {
    testWidgets('is obscured to begin with', (tester) async {
      await _pump(tester, const Size(1024, 768));

      // The shared CustomTextField passed its `passwordVisible` flag
      // straight to `obscureText`, so this screen used to open with the
      // password in plain text.
      final TextField password =
          tester.widget(find.byKey(const Key('login_password')));
      expect(password.obscureText, isTrue);
    });

    testWidgets('the eye button reveals it', (tester) async {
      await _pump(tester, const Size(1024, 768));

      await tester.tap(find.byKey(const Key('login_password_visibility')));
      await tester.pump();

      final TextField password =
          tester.widget(find.byKey(const Key('login_password')));
      expect(password.obscureText, isFalse);
    });
  });

  group('validation', () {
    testWidgets('an empty submit marks both fields and asks for nothing',
        (tester) async {
      await _pump(tester, const Size(1024, 768));

      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();

      expect(find.text('Enter your username'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      verifyNever(() => repo.signIn(any(), any()));
    });

    testWidgets('typing clears the field it is about', (tester) async {
      await _pump(tester, const Size(1024, 768));

      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('login_username')), 'a');
      await tester.pump();

      expect(find.text('Enter your username'), findsNothing);
      expect(find.text('Enter your password'), findsOneWidget);
    });
  });

  group('signing in', () {
    testWidgets('trims the username', (tester) async {
      await _pump(tester, const Size(1024, 768));

      await tester.enterText(
          find.byKey(const Key('login_username')), '  admin  ');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.pump();

      // A trailing space pasted in with the username used to make the
      // lookup miss, reported as a wrong password.
      verify(() => repo.signIn('admin', 'pw')).called(1);
    });

    testWidgets('wrong credentials report on the form, not in a snackbar',
        (tester) async {
      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'nope');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('login_error')), findsOneWidget);
      expect(find.text('That username and password do not match.'),
          findsOneWidget);
      expect(Session.isSignedIn, isFalse);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('an outage says something different from a bad password',
        (tester) async {
      when(() => repo.signIn(any(), any())).thenThrow(Exception('offline'));
      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      await tester.pump();

      // The old screen caught both in one `try` and reported them the same
      // way, so an outage looked like bad credentials.
      expect(
          find.text(
              'Could not reach the server. Check your connection and try again.'),
          findsOneWidget);
    });

    testWidgets('the button stays put and shows progress', (tester) async {
      final Completer<LoginResult?> pending = Completer<LoginResult?>();
      when(() => repo.signIn(any(), any())).thenAnswer((_) => pending.future);
      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();

      // The old screen removed the button from the tree while this ran.
      final ElevatedButton button =
          tester.widget(find.byKey(const Key('login_submit')));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(null);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('a success starts the session and lands on the shell',
        (tester) async {
      when(() => repo.signIn(any(), any())).thenAnswer((_) async =>
          const LoginResult(
              adminId: 'teacher-1', moduleAccess: ['banners', 'course']));

      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(Session.adminId, 'teacher-1');
      expect(sharedPreferences.getStringList(moduleAccessPrefsKey),
          ['banners', 'course']);
      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('a success remembers the role, so an admin sees every module',
        (tester) async {
      // An admin whose module list was saved before Books existed.
      when(() => repo.signIn(any(), any())).thenAnswer((_) async =>
          const LoginResult(
              adminId: 'teacher-1',
              moduleAccess: ['BANNERS', 'COURSES'],
              role: roleAdmin));

      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(sharedPreferences.getString(rolePrefsKey), roleAdmin);
      expect(Session.isAdmin, isTrue);
      expect(Helper.allowedModuleIndices(), hasLength(moduleList.length));
    });

    testWidgets('nothing is left on the stack to go back to', (tester) async {
      when(() => repo.signIn(any(), any())).thenAnswer((_) async =>
          const LoginResult(adminId: 'teacher-1', moduleAccess: []));

      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(navigatorKey.currentState!.canPop(), isFalse);
    });

    testWidgets('Enter in the password field submits', (tester) async {
      await _pump(tester, const Size(1024, 768));

      await tester.enterText(find.byKey(const Key('login_username')), 'admin');
      await tester.enterText(find.byKey(const Key('login_password')), 'pw');
      // The old form built two FocusNodes and wired neither to anything.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();

      verify(() => repo.signIn('admin', 'pw')).called(1);
    });
  });
}
