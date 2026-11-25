import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bbarna/question1/model/question1.dart';
import 'package:bbarna/question1/repo/question1_repo.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockAggregateQuery extends Mock implements AggregateQuery {}

class MockAggregateQuerySnapshot extends Mock
    implements AggregateQuerySnapshot {}

class DocumentSnapshotFake extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {}

Question1 _sampleQuestion({String questionCode = 'Q1'}) => Question1(
      questionCode: questionCode,
      question: 'What is 2+2?',
      questionBody: 'body',
      hints: 'hint',
      solution: 'solution',
      answer: '4',
      option1: '3',
      option2: '4',
      option3: '5',
      option4: '6',
      timeStamp: 1000,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(DocumentSnapshotFake());
  });

  late MockFirebaseFirestore firestore;
  late MockCollectionReference collection;
  late Question1Repo repo;

  setUp(() {
    firestore = MockFirebaseFirestore();
    collection = MockCollectionReference();
    when(() => firestore.collection('question')).thenReturn(collection);
    repo = Question1Repo(firestore: firestore);
  });

  group('addQuestion', () {
    test('adds the toMap() shape to the question collection', () async {
      final docRef = MockDocumentReference();
      when(() => collection.add(any())).thenAnswer((_) async => docRef);

      final question = _sampleQuestion();
      await repo.addQuestion(question);

      verify(() => collection.add(question.toMap())).called(1);
    });
  });

  group('updateQuestion', () {
    test('updates the doc at docId with toMap()', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('doc-1')).thenReturn(docRef);
      when(() => docRef.update(any())).thenAnswer((_) async {});

      final question = _sampleQuestion();
      await repo.updateQuestion('doc-1', question);

      verify(() => docRef.update(question.toMap())).called(1);
    });
  });

  group('deleteQuestion', () {
    test('deletes the doc at the given id', () async {
      final docRef = MockDocumentReference();
      when(() => collection.doc('doc-1')).thenReturn(docRef);
      when(() => docRef.delete()).thenAnswer((_) async {});

      await repo.deleteQuestion('doc-1');

      verify(() => docRef.delete()).called(1);
    });
  });

  group('getQuestionCount', () {
    test('returns the aggregate count', () async {
      final aggregateQuery = MockAggregateQuery();
      final aggregateSnapshot = MockAggregateQuerySnapshot();
      when(() => collection.count()).thenReturn(aggregateQuery);
      when(() => aggregateQuery.get())
          .thenAnswer((_) async => aggregateSnapshot);
      when(() => aggregateSnapshot.count).thenReturn(7);

      final result = await repo.getQuestionCount();

      expect(result, 7);
    });
  });

  group('getPage', () {
    test(
        'first page orders by timeStamp desc and does not call startAfterDocument',
        () async {
      final querySnapshot = MockQuerySnapshot();
      final doc = MockQueryDocumentSnapshot();
      when(() => doc.id).thenReturn('doc-1');
      when(() => doc.data()).thenReturn(_sampleQuestion().toMap());
      when(() => querySnapshot.docs).thenReturn([doc]);
      when(() => collection.orderBy('timeStamp', descending: true))
          .thenReturn(collection);
      when(() => collection.limit(any())).thenReturn(collection);
      when(() => collection.get()).thenAnswer((_) async => querySnapshot);

      final page = await repo.getPage(limit: 50);

      expect(page.items, hasLength(1));
      expect(page.items.first.docId, 'doc-1');
      expect(page.docs, [doc]);
      verifyNever(() => collection.startAfterDocument(any()));
    });

    test('subsequent page passes the given cursor to startAfterDocument',
        () async {
      final querySnapshot = MockQuerySnapshot();
      when(() => querySnapshot.docs).thenReturn([]);
      final cursor = DocumentSnapshotFake();
      when(() => collection.orderBy('timeStamp', descending: true))
          .thenReturn(collection);
      when(() => collection.limit(any())).thenReturn(collection);
      when(() => collection.startAfterDocument(cursor)).thenReturn(collection);
      when(() => collection.get()).thenAnswer((_) async => querySnapshot);

      final page = await repo.getPage(limit: 50, startAfter: cursor);

      expect(page.items, isEmpty);
      verify(() => collection.startAfterDocument(cursor)).called(1);
    });
  });

  group('searchByCode', () {
    test('queries a [prefix, prefix+z) range on question_code', () async {
      final querySnapshot = MockQuerySnapshot();
      final doc = MockQueryDocumentSnapshot();
      when(() => doc.id).thenReturn('doc-1');
      when(() => doc.data())
          .thenReturn(_sampleQuestion(questionCode: 'ABC').toMap());
      when(() => querySnapshot.docs).thenReturn([doc]);
      when(() =>
              collection.where('question_code', isGreaterThanOrEqualTo: 'ABC'))
          .thenReturn(collection);
      when(() => collection.where('question_code', isLessThan: 'ABCz'))
          .thenReturn(collection);
      when(() => collection.get()).thenAnswer((_) async => querySnapshot);

      final result = await repo.searchByCode('ABC');

      expect(result, hasLength(1));
      expect(result.first.questionCode, 'ABC');
    });
  });
}
