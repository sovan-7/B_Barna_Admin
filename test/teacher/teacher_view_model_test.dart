import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';

class MockTeacherRepo extends Mock implements TeacherRepo {}

class TeacherModelFake extends Fake implements TeacherModel {}

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
  });

  // addTeacher's success path never touches Helper.showSnackBarMessage or
  // LoaderDialogs (both require a live navigatorKey.currentContext), so it's
  // safely testable with a plain `test()` — no widget pump needed.
  group('addTeacher (success path, plain unit tests)', () {
    test('hashes the password with sha256 before it ever reaches the repo',
        () async {
      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any())).thenAnswer((_) async {});

      const rawPassword = 'plaintext-password-123';
      await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: rawPassword,
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      final captured =
          verify(() => repo.addTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.password, isNot(equals(rawPassword)));
      expect(captured.password,
          sha256.convert(utf8.encode(rawPassword)).toString());
    });

    test('normalizes username to lowercase before it reaches the repo',
        () async {
      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any())).thenAnswer((_) async {});

      await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'Jane_Doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      final captured =
          verify(() => repo.addTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.username, 'jane_doe');
      expect(captured.docId, 'jane_doe');
    });

    test('uploads the image before creating the Firestore doc (never the reverse)',
        () async {
      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any())).thenAnswer((_) async {});

      await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      verifyInOrder([
        () => repo.uploadTeacherImage(any(), any()),
        () => repo.addTeacher(any()),
      ]);
    });

    test('returns true and includes the uploaded image URL in the model',
        () async {
      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any())).thenAnswer((_) async {});

      final result = await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      expect(result, isTrue);
      final captured =
          verify(() => repo.addTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.imageUrl, 'https://example.com/photo.jpg');
    });

    test('passes the selected moduleAccess through to the persisted model',
        () async {
      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any())).thenAnswer((_) async {});

      await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES', 'SUBJECT'],
        role: roleSubadmin,
      );

      final captured =
          verify(() => repo.addTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.moduleAccess, ['COURSES', 'SUBJECT']);
    });

    test('passes the selected role through to the persisted model', () async {
      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any())).thenAnswer((_) async {});

      await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleAdmin,
      );

      final captured =
          verify(() => repo.addTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.role, roleAdmin);
    });
  });

  // Failure paths call Helper.showSnackBarMessage, which needs a real
  // navigatorKey.currentContext — so these are testWidgets, pumping a
  // minimal MaterialApp wired to the app's real navigatorKey.
  group('addTeacher (failure paths, need a live navigator context)', () {
    testWidgets('never creates a Firestore doc if the image upload fails',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));

      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenThrow(Exception('storage failure'));

      final result = await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      expect(result, isFalse);
      verifyNever(() => repo.addTeacher(any()));
    });

    testWidgets('returns false when the username is already taken',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));

      when(() => repo.generateStorageKey()).thenReturn('key-1');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/photo.jpg');
      when(() => repo.addTeacher(any()))
          .thenThrow(UsernameTakenException('jane_doe'));

      final result = await viewModel.addTeacher(
        name: 'Jane Doe',
        username: 'jane_doe',
        password: 'password123',
        phoneNumber: '9876543210',
        image: Uint8List.fromList([1, 2, 3]),
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      expect(result, isFalse);
    });
  });

  group('updateTeacher (success path, plain unit tests)', () {
    final original = TeacherModel(
      docId: 'jane_doe',
      name: 'Jane Doe',
      imageUrl: 'https://example.com/original.jpg',
      username: 'jane_doe',
      password: 'original-hash',
      phoneNumber: '9876543210',
      timeStamp: 1700000000000,
      moduleAccess: const ['COURSES'],
      role: roleSubadmin,
    );

    test('keeps the original password hash when newPassword is omitted',
        () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.password, 'original-hash');
    });

    test('keeps the original password hash when newPassword is empty',
        () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        newPassword: '',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.password, 'original-hash');
    });

    test('hashes newPassword with sha256 when provided', () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      const rawPassword = 'new-plaintext-password';
      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        newPassword: rawPassword,
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.password,
          sha256.convert(utf8.encode(rawPassword)).toString());
    });

    test('keeps the original photo when newImage is omitted, never uploads',
        () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      verifyNever(() => repo.uploadTeacherImage(any(), any()));
      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.imageUrl, 'https://example.com/original.jpg');
    });

    test('uploads and uses the new photo URL when newImage is provided',
        () async {
      when(() => repo.generateStorageKey()).thenReturn('key-2');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenAnswer((_) async => 'https://example.com/new.jpg');
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
        newImage: Uint8List.fromList([1, 2, 3]),
      );

      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.imageUrl, 'https://example.com/new.jpg');
    });

    test('preserves docId, username and timeStamp from the original model',
        () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe Renamed',
        phoneNumber: '9876543210',
        moduleAccess: const ['SUBJECT'],
        role: roleAdmin,
      );

      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.docId, original.docId);
      expect(captured.username, original.username);
      expect(captured.timeStamp, original.timeStamp);
    });

    test('passes through the edited name, moduleAccess and role', () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe Renamed',
        phoneNumber: '9876543210',
        moduleAccess: const ['SUBJECT', 'TOPIC'],
        role: roleAdmin,
      );

      final captured =
          verify(() => repo.updateTeacher(captureAny())).captured.single
              as TeacherModel;
      expect(captured.name, 'Jane Doe Renamed');
      expect(captured.moduleAccess, ['SUBJECT', 'TOPIC']);
      expect(captured.role, roleAdmin);
    });

    test('returns true on success', () async {
      when(() => repo.updateTeacher(any())).thenAnswer((_) async {});

      final result = await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      expect(result, isTrue);
    });
  });

  // Failure paths call Helper.showSnackBarMessage, which needs a real
  // navigatorKey.currentContext — same rationale as addTeacher's above.
  group('updateTeacher (failure paths, need a live navigator context)', () {
    final original = TeacherModel(
      docId: 'jane_doe',
      name: 'Jane Doe',
      imageUrl: 'https://example.com/original.jpg',
      username: 'jane_doe',
      password: 'original-hash',
      phoneNumber: '9876543210',
      timeStamp: 1700000000000,
      moduleAccess: const ['COURSES'],
      role: roleSubadmin,
    );

    testWidgets(
        'never calls repo.updateTeacher if the new image upload fails',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));

      when(() => repo.generateStorageKey()).thenReturn('key-2');
      when(() => repo.uploadTeacherImage(any(), any()))
          .thenThrow(Exception('storage failure'));

      final result = await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
        newImage: Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isFalse);
      verifyNever(() => repo.updateTeacher(any()));
    });

    testWidgets('returns false when the repo write fails', (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));

      when(() => repo.updateTeacher(any()))
          .thenThrow(Exception('firestore failure'));

      final result = await viewModel.updateTeacher(
        original: original,
        name: 'Jane Doe',
        phoneNumber: '9876543210',
        moduleAccess: const ['COURSES'],
        role: roleSubadmin,
      );

      expect(result, isFalse);
    });
  });

  group('searchTeacher (plain unit tests, no navigator dependency)', () {
    setUp(() {
      viewModel.teacherList = [
        TeacherModel(
          docId: 'jane_doe',
          name: 'Jane Doe',
          imageUrl: 'x',
          username: 'jane_doe',
          password: 'x',
          phoneNumber: '9876543210',
          timeStamp: 1,
          moduleAccess: const ['COURSES'],
          role: roleSubadmin,
        ),
        TeacherModel(
          docId: 'john_smith',
          name: 'John Smith',
          imageUrl: 'x',
          username: 'john_smith',
          password: 'x',
          phoneNumber: '9876543210',
          timeStamp: 2,
          moduleAccess: const ['SUBJECT'],
          role: roleAdmin,
        ),
      ];
      viewModel.copyTeacherList = viewModel.teacherList;
    });

    test('filters by name, case-insensitively', () {
      viewModel.searchTeacher(searchText: 'jane');
      expect(viewModel.teacherList, hasLength(1));
      expect(viewModel.teacherList.first.name, 'Jane Doe');
    });

    test('filters by username, case-insensitively', () {
      viewModel.searchTeacher(searchText: 'SMITH');
      expect(viewModel.teacherList, hasLength(1));
      expect(viewModel.teacherList.first.username, 'john_smith');
    });

    test('empty search text restores the full list', () {
      viewModel.searchTeacher(searchText: 'jane');
      viewModel.searchTeacher(searchText: '');
      expect(viewModel.teacherList, hasLength(2));
    });

    test('notifies listeners on search', () {
      var notified = false;
      viewModel.addListener(() => notified = true);
      viewModel.searchTeacher(searchText: 'jane');
      expect(notified, isTrue);
    });
  });
}
