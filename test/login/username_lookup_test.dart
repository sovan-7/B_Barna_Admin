import 'dart:typed_data';

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTeacherRepo extends Mock implements TeacherRepo {}

class TeacherModelFake extends Fake implements TeacherModel {}

/// Creating a teacher and signing in as one have to agree on the username.
///
/// They did not. `TeacherViewModel.addTeacher` lowercased the username before
/// storing it — as the doc id and as the `username` field — while
/// `LoginRepo.signIn` queried `where('username', isEqualTo: <typed text>)`
/// with the case the teacher typed. So a teacher created as "Ravi_Kumar" was
/// stored as "ravi_kumar" and could never sign in: the query matched no
/// document, and the login screen says "That username and password do not
/// match" for a miss of either field, which reads as a rejected password.
///
/// Both sides now go through `normalizeUsername`. These tests pin the stored
/// value (captured from the real addTeacher path) to the value the login
/// lookup builds, so the two cannot drift apart again.
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
    when(() => repo.generateStorageKey()).thenReturn('key-1');
    when(() => repo.uploadTeacherImage(any(), any()))
        .thenAnswer((_) async => 'https://example.com/photo.jpg');
    when(() => repo.addTeacher(any())).thenAnswer((_) async {});
  });

  /// Runs the real creation path and returns the document that would be
  /// written to Firestore.
  Future<TeacherModel> createdWith(String username) async {
    await viewModel.addTeacher(
      name: 'Ravi Kumar',
      username: username,
      password: 'password123',
      image: Uint8List.fromList([1, 2, 3]),
      moduleAccess: const ['COURSES'],
      role: roleSubadmin,
    );
    return verify(() => repo.addTeacher(captureAny())).captured.single
        as TeacherModel;
  }

  test('a mixed-case username is stored lowercased, and looked up lowercased',
      () async {
    const typed = 'Ravi_Kumar';
    final stored = await createdWith(typed);

    expect(stored.username, 'ravi_kumar');
    // What LoginRepo.signIn now puts in the where() clause.
    expect(normalizeUsername(typed), stored.username,
        reason: 'the login query must match the stored username');
  });

  test('the raw typed text would NOT have matched — this is the regression',
      () async {
    const typed = 'Ravi_Kumar';
    final stored = await createdWith(typed);

    // The old login lookup passed the typed text straight through.
    expect(typed, isNot(stored.username),
        reason: 'why sign-in failed before the fix');
  });

  test('an all-lowercase username was never affected', () async {
    const typed = 'ravi_kumar';
    final stored = await createdWith(typed);

    expect(normalizeUsername(typed), stored.username);
    // Unchanged behaviour for accounts that already worked.
    expect(typed, stored.username);
  });

  test('surrounding whitespace resolves to the same account', () {
    expect(normalizeUsername('  Ravi_Kumar  '), 'ravi_kumar');
  });

  test('the doc id and the username field stay the same string', () async {
    final stored = await createdWith('Ravi_Kumar');

    // TeacherRepo.addTeacher writes to .doc(model.username), so a mismatch
    // here would orphan the document from its own lookup key.
    expect(stored.docId, stored.username);
  });
}
