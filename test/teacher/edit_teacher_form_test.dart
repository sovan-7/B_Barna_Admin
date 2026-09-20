import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';
import 'package:bbarna/teacher/screen/edit_teacher.dart';
import 'package:bbarna/teacher/widgets/teacher_form.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';

class MockTeacherRepo extends Mock implements TeacherRepo {}

class TeacherModelFake extends Fake implements TeacherModel {}

final TeacherModel _existingTeacher = TeacherModel(
  docId: 'jane_doe',
  name: 'Jane Doe',
  imageUrl: 'https://example.com/original.jpg',
  username: 'jane_doe',
  password: 'original-hash',
  phoneNumber: '9876543210',
  timeStamp: 1700000000000,
  moduleAccess: const ['COURSES', 'SUBJECT'],
  role: roleSubadmin,
);

Future<void> pumpEditTeacher(
    WidgetTester tester, TeacherViewModel viewModel,
    {TeacherModel? teacherData}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<TeacherViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: EditTeacher(teacherData: teacherData ?? _existingTeacher),
      ),
    ),
  );
  // The avatar attempts to load teacherData.imageUrl over the network; let
  // that fail and settle (DecorationImage's onError swallows it) before
  // interacting with the form.
  await tester.pump(const Duration(milliseconds: 100));
}

final Uint8List _validPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

void selectFakeImage(WidgetTester tester,
    {String name = 'photo.png', int size = 1024}) {
  final state = tester.state<TeacherFormTestHooks>(find.byType(TeacherForm));
  state.setSelectedImageForTest(
    PlatformFile(name: name, size: size, bytes: _validPngBytes),
  );
}

Future<void> checkModule(WidgetTester tester, String module) async {
  await tester.ensureVisible(find.byKey(Key('module_checkbox_$module')));
  await tester.tap(find.byKey(Key('module_checkbox_$module')));
  await tester.pump();
}

Future<void> selectRole(WidgetTester tester, String role) async {
  await tester.ensureVisible(find.byKey(Key('role_option_$role')));
  await tester.tap(find.byKey(Key('role_option_$role')));
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(TeacherModelFake());
    registerFallbackValue(Uint8List(0));
  });

  late MockTeacherRepo repo;
  late TeacherViewModel viewModel;

  setUp(() {
    repo = MockTeacherRepo();
    viewModel = TeacherViewModel(teacherRepo: repo);
    when(() => repo.updateTeacher(any())).thenAnswer((_) async {});
  });

  testWidgets('prefills name and username from the given teacher',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);

    expect(
        find.widgetWithText(TextField, 'Jane Doe', skipOffstage: false),
        findsOneWidget);
    expect(
        find.widgetWithText(TextField, 'jane_doe', skipOffstage: false),
        findsOneWidget);
    expect(
        find.widgetWithText(TextField, '9876543210', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('username field is disabled', (tester) async {
    await pumpEditTeacher(tester, viewModel);

    // The username is the Firestore document id, so it cannot change once
    // the teacher exists.
    final TextField usernameField =
        tester.widget<TextField>(find.byKey(const Key('teacher_username_field')));
    expect(usernameField.enabled, isFalse);
  });

  testWidgets(
      'preselects the existing role and modules, so saving untouched keeps them',
      (tester) async {
    // Asserted through what gets written rather than through the widget
    // types the chips happen to be built from — the old version reached for
    // ChoiceChip and FilterChip directly.
    await pumpEditTeacher(tester, viewModel);
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    final captured =
        verify(() => repo.updateTeacher(captureAny())).captured.single
            as TeacherModel;
    expect(captured.role, roleSubadmin);
    expect(captured.moduleAccess, ['COURSES', 'SUBJECT']);
  });

  testWidgets('unticking a preselected module drops it on save',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await checkModule(tester, 'COURSES');
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    final captured =
        verify(() => repo.updateTeacher(captureAny())).captured.single
            as TeacherModel;
    expect(captured.moduleAccess, ['SUBJECT']);
  });

  testWidgets('keeps the current password when the field is left blank',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    final captured =
        verify(() => repo.updateTeacher(captureAny())).captured.single
            as TeacherModel;
    expect(captured.password, 'original-hash');
  });

  testWidgets('blocks submission when a new password is shorter than 8 chars',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await tester.enterText(
        find.byKey(const Key('teacher_password_field')), 'short1');
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    verifyNever(() => repo.updateTeacher(any()));
  });

  testWidgets('blocks submission when the phone number is edited to fewer than 10 digits',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await tester.enterText(
        find.byKey(const Key('teacher_phone_field')), '12345');
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    verifyNever(() => repo.updateTeacher(any()));
  });

  testWidgets('saves the edited phone number', (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await tester.enterText(
        find.byKey(const Key('teacher_phone_field')), '1234567890');
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    final captured =
        verify(() => repo.updateTeacher(captureAny())).captured.single
            as TeacherModel;
    expect(captured.phoneNumber, '1234567890');
  });

  testWidgets('blocks submission when every module is unchecked',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await checkModule(tester, 'COURSES');
    await checkModule(tester, 'SUBJECT');
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    verifyNever(() => repo.updateTeacher(any()));
  });

  testWidgets('saves the switched role and edited module selection',
      (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await selectRole(tester, roleAdmin);
    await checkModule(tester, 'SUBJECT');
    await checkModule(tester, 'QUIZ');
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    final captured =
        verify(() => repo.updateTeacher(captureAny())).captured.single
            as TeacherModel;
    expect(captured.role, roleAdmin);
    expect(captured.moduleAccess, ['COURSES', 'QUIZ']);
  });

  testWidgets('preserves docId and username on save', (tester) async {
    await pumpEditTeacher(tester, viewModel);
    await tester.ensureVisible(find.byKey(const Key('teacher_save_button')));
    await tester.tap(find.byKey(const Key('teacher_save_button')));
    await tester.pumpAndSettle();

    final captured =
        verify(() => repo.updateTeacher(captureAny())).captured.single
            as TeacherModel;
    expect(captured.docId, 'jane_doe');
    expect(captured.username, 'jane_doe');
  });
}
