import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockTransaction extends Mock implements Transaction {}

class DocumentReferenceFake extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(const Duration(seconds: 30));
    registerFallbackValue(DocumentReferenceFake());
  });

  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late TeacherRepo repo;

  setUp(() {
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    when(() => firestore.collection('teacher')).thenReturn(collection);
    repo = TeacherRepo(firestore: firestore, storage: MockFirebaseStorage());
  });

  group('getTeacherList', () {
    test('maps each Firestore doc to a TeacherModel', () async {
      final querySnapshot = MockQuerySnapshot();
      final doc1 = MockQueryDocumentSnapshot();
      when(() => doc1.id).thenReturn('jane_doe');
      when(() => doc1.data()).thenReturn({
        'name': 'Jane Doe',
        'image_url': 'https://example.com/jane.jpg',
        'username': 'jane_doe',
        'password': 'hash1',
        'timeStamp': 1,
      });
      when(() => querySnapshot.docs).thenReturn([doc1]);
      when(() => collection.get()).thenAnswer((_) async => querySnapshot);

      final result = await repo.getTeacherList();

      expect(result, hasLength(1));
      expect(result.first.docId, 'jane_doe');
      expect(result.first.name, 'Jane Doe');
    });
  });

  group('deleteTeacher', () {
    test('deletes the doc at the given username', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('jane_doe')).thenReturn(docRef);
      when(() => docRef.delete()).thenAnswer((_) async {});

      await repo.deleteTeacher('jane_doe');

      verify(() => docRef.delete()).called(1);
    });
  });

  group('addTeacher (transactional uniqueness)', () {
    test('creates the doc when the username is not already taken', () async {
      final docRef = MockDocumentReference();
      final transaction = MockTransaction();
      final existingSnapshot = MockDocumentSnapshot();

      when(() => collection.doc('jane_doe')).thenReturn(docRef);
      when(() => existingSnapshot.exists).thenReturn(false);
      when(() => transaction.get(docRef)).thenAnswer((_) async => existingSnapshot);
      when(() => transaction.set<Map<String, dynamic>>(
              any<DocumentReference<Map<String, dynamic>>>(),
              any<Map<String, dynamic>>()))
          .thenReturn(transaction);
      when(() => firestore.runTransaction<void>(any(),
              timeout: any(named: 'timeout'),
              maxAttempts: any(named: 'maxAttempts')))
          .thenAnswer((invocation) async {
        final handler = invocation.positionalArguments[0]
            as Future<void> Function(Transaction);
        await handler(transaction);
      });

      final model = TeacherModel(
        docId: 'jane_doe',
        name: 'Jane Doe',
        imageUrl: 'https://example.com/jane.jpg',
        username: 'jane_doe',
        password: 'hash1',
        phoneNumber: '9876543210',
        timeStamp: 1,
        moduleAccess: const ['COURSES'],
        role: 'admin',
      );

      await repo.addTeacher(model);

      final captured = verify(() => transaction.set<Map<String, dynamic>>(
              captureAny<DocumentReference<Map<String, dynamic>>>(),
              captureAny<Map<String, dynamic>>(),
              any()))
          .captured;
      expect(captured[0], same(docRef));
      // Map's default `==` is identity, not content — compare contents explicitly.
      expect(captured[1], model.toMap());
    });

    test(
        'throws UsernameTakenException and never overwrites when the username already exists',
        () async {
      final docRef = MockDocumentReference();
      final transaction = MockTransaction();
      final existingSnapshot = MockDocumentSnapshot();

      when(() => collection.doc('jane_doe')).thenReturn(docRef);
      when(() => existingSnapshot.exists).thenReturn(true);
      when(() => transaction.get(docRef)).thenAnswer((_) async => existingSnapshot);
      when(() => firestore.runTransaction<void>(any(),
              timeout: any(named: 'timeout'),
              maxAttempts: any(named: 'maxAttempts')))
          .thenAnswer((invocation) async {
        final handler = invocation.positionalArguments[0]
            as Future<void> Function(Transaction);
        await handler(transaction);
      });

      final model = TeacherModel(
        docId: 'jane_doe',
        name: 'Jane Doe',
        imageUrl: 'https://example.com/jane.jpg',
        username: 'jane_doe',
        password: 'hash1',
        phoneNumber: '9876543210',
        timeStamp: 1,
        moduleAccess: const ['COURSES'],
        role: 'admin',
      );

      await expectLater(
        () => repo.addTeacher(model),
        throwsA(isA<UsernameTakenException>()),
      );
      verifyNever(() => transaction.set<Map<String, dynamic>>(
          any<DocumentReference<Map<String, dynamic>>>(),
          any<Map<String, dynamic>>(),
          any()));
    });
  });

  group('updateTeacher', () {
    test('updates the doc at docId with the model\'s full field map',
        () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('jane_doe')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      final model = TeacherModel(
        docId: 'jane_doe',
        name: 'Jane Doe Updated',
        imageUrl: 'https://example.com/jane.jpg',
        username: 'jane_doe',
        password: 'hash1',
        phoneNumber: '9876543210',
        timeStamp: 1,
        moduleAccess: const ['COURSES', 'SUBJECT'],
        role: 'admin',
      );

      await repo.updateTeacher(model);

      verify(() => docRef.update(model.toMap())).called(1);
    });
  });

  group('uploadTeacherImage / generateStorageKey', () {
    setUp(() {
      // Each call to collection.doc() with no args simulates Firestore's
      // client-side auto-ID generation — a fresh, distinct ID every time.
      int counter = 0;
      when(() => collection.doc()).thenAnswer((_) {
        final docRef = MockDocumentReference();
        when(() => docRef.id).thenReturn('generated-id-${counter++}');
        return docRef;
      });
    });

    test('generateStorageKey() never produces the same value twice', () {
      final keys = List.generate(20, (_) => repo.generateStorageKey());
      expect(keys.toSet(), hasLength(20));
    });

    test(
        'two uploads with different storage keys never collide, even if usernames would',
        () async {
      final keyA = repo.generateStorageKey();
      final keyB = repo.generateStorageKey();
      expect(keyA, isNot(equals(keyB)));

      final urlA =
          await repo.uploadTeacherImage(Uint8List.fromList([1, 2, 3]), keyA);
      final urlB =
          await repo.uploadTeacherImage(Uint8List.fromList([4, 5, 6]), keyB);

      expect(urlA, isNot(equals(urlB)));
    });
  });
}
