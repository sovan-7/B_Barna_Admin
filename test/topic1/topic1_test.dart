// Firestore mocks implement its sealed classes, as the other repo tests do.
// ignore_for_file: subtype_of_sealed_class

import 'dart:typed_data';

import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/core/widgets/app_toast.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic1/model/topic1_copy.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/repo/topic1_repo.dart';
import 'package:bbarna/topic1/screen/add_topic1.dart';
import 'package:bbarna/topic1/screen/edit_topic1.dart';
import 'package:bbarna/topic1/screen/topic1_details.dart';
import 'package:bbarna/topic1/screen/topic1_list.dart';
import 'package:bbarna/topic1/viewModel/topic1_view_model.dart';
import 'package:bbarna/topic1/widgets/topic1_card.dart';
import 'package:bbarna/topic1/widgets/topic1_pdf_section.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTopic1Repo extends Mock implements Topic1Repo {}

class MockCourseRepo extends Mock implements CourseRepo {}

class Topic1ModelFake extends Fake implements Topic1Model {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockWriteBatch extends Mock implements WriteBatch {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

/// A query result holding a document per entry of [docs] (`id -> data`).
MockQuerySnapshot _snapshot(Map<String, Map<String, dynamic>> docs) {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> results = [];
  docs.forEach((String id, Map<String, dynamic> data) {
    final MockQueryDocumentSnapshot doc = MockQueryDocumentSnapshot();
    when(() => doc.id).thenReturn(id);
    when(() => doc.data()).thenReturn(data);
    results.add(doc);
  });
  final MockQuerySnapshot snapshot = MockQuerySnapshot();
  when(() => snapshot.docs).thenReturn(results);
  return snapshot;
}

final Uint8List _bytes = Uint8List.fromList([37, 80, 68, 70]); // %PDF

Topic1Pdf _pdf(String id, {String path = "", String title = "Notes"}) =>
    Topic1Pdf(
      id: id,
      title: title,
      fileName: "$id.pdf",
      link: "https://files/$id",
      storagePath: path.isEmpty ? "topic1_pdf/a/$id.pdf" : path,
      type: "FREE",
      isDownloadable: true,
    );

Topic1Video _video(String id) => Topic1Video(
      id: id,
      title: "Lecture $id",
      link: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      type: "PAID",
    );

Topic1Model _topic(
  String docId,
  String code,
  String name, {
  int timeStamp = 0,
  List<String>? unitCodes,
  List<Topic1Pdf>? pdfs,
  List<Topic1Video>? videos,
  List<String>? audios,
  List<String>? quizzes,
}) {
  final Topic1Model model = Topic1Model(
      code,
      name,
      timeStamp,
      "Physics — Class 11",
      "PHY-11",
      "Mechanics",
      "MECH",
      "Laws of Motion",
      "MECH-01",
      1,
      unitCodes ?? ["MECH-01"]);
  model.docId = docId;
  model.pdfList = pdfs ?? [];
  model.videoList = videos ?? [];
  model.audioCodeList = audios ?? [];
  model.quizCodeList = quizzes ?? [];
  return model;
}

List<Topic1Model> _fixture() => [
      _topic('a', 'NEWT-01', "Newton's First Law",
          timeStamp: 300,
          pdfs: [_pdf('p1'), _pdf('p2')],
          videos: [_video('v1')],
          quizzes: ['QZ-1']),
      _topic('b', 'NEWT-02', "Newton's Second Law",
          timeStamp: 200, unitCodes: ["MECH-01", "MECH-02", "APP-07"]),
      _topic(
          'c',
          'NEWT-03',
          'An extremely long topic name that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          timeStamp: 100),
    ];

SubjectModel _subject(String code, String name) {
  final SubjectModel model = SubjectModel("PHY-11", "Full Course",
      "Physics — Class 11", 0, 0, code, "", name, "", 1, 0, true, false, false);
  model.docId = code;
  return model;
}

UnitModel _unitModel(String code, String name) {
  final UnitModel model = UnitModel("PHY-11", "Physics — Class 11", "MECH",
      "Mechanics", false, code, "", name, "", 1, 0, true, ["MECH"]);
  model.id = code;
  return model;
}

CourseModel _course(String code, String name) {
  final CourseModel model = CourseModel(code, "", name, "", 1, 0, true, false);
  model.docId = code;
  return model;
}

/// Rows on screen: table rows on wide windows, cards on narrow.
Finder _rows() => find.byWidgetPredicate((widget) {
      if (widget is Topic1Card) return true;
      final Key? key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('topic1_row_');
    });

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockTopic1Repo repo;
late MockCourseRepo courseRepo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, Topic1ViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<Topic1ViewModel>.value(value: vm),
      ChangeNotifierProvider<CourseViewModel>(
          create: (_) => CourseViewModel(courseRepo: courseRepo)),
    ],
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// A bare app, so failure toasts have somewhere to show.
Future<void> _pumpShell(WidgetTester tester) => tester.pumpWidget(MaterialApp(
    navigatorKey: navigatorKey, home: const Scaffold(body: SizedBox())));

/// Taps [key] after scrolling it into view.
Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Topic1ModelFake());
    registerFallbackValue(ContentKind.audio);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<Topic1Pdf>[]);
    registerFallbackValue(<Topic1Video>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repo = MockTopic1Repo();
    courseRepo = MockCourseRepo();
    when(() => repo.getFirstTopicList(any()))
        .thenAnswer((_) async => _fixture());
    when(() => repo.getTopicListLength()).thenAnswer((_) async => 3);
    when(() => repo.getSubjectList(courseCode: any(named: 'courseCode')))
        .thenAnswer((_) async => [_subject('MECH', 'Mechanics')]);
    when(() => repo.getUnitList(subjectCode: any(named: 'subjectCode')))
        .thenAnswer((_) async => [_unitModel('MECH-01', 'Laws of Motion')]);
    when(() => repo.resolveContentTitles(any(), any()))
        .thenAnswer((_) async => <String, String>{});
    when(() => repo.deletePdfFiles(any())).thenAnswer((_) async {});
    when(() => courseRepo.getCourseList())
        .thenAnswer((_) async => [_course('PHY-11', 'Physics — Class 11')]);
  });

  group('the model', () {
    test('saving a topic cannot wipe its content', () {
      final Map<String, dynamic> map = _fixture().first.toMap();
      expect(map['topic_code'], 'NEWT-01');
      for (final String field in [
        'pdf_list',
        'video_list',
        'audio_code_list',
        'quiz_code_list',
      ]) {
        expect(map.containsKey(field), isFalse, reason: field);
      }
    });

    test('reads PDFs and videos stored on the document', () {
      final Topic1Model model = Topic1Model.fromMap('x', {
        'topic_code': 'T-1',
        'topic_name': 'Topic',
        'pdf_list': [_pdf('p1').toMap(), 'junk'],
        'video_list': [
          {'video_title': 'No id', 'video_link': 'l', 'video_type': 'FREE'}
        ],
        'audio_code_list': ['AUD-1'],
      });

      expect(model.docId, 'x');
      expect(model.pdfList.single.toMap(), _pdf('p1').toMap());
      expect(model.videoList.single.id, 'video_0',
          reason: 'an entry without an id still gets a stable one');
      expect(model.videoList.single.title, 'No id');
      expect(model.audioCodeList, ['AUD-1']);
      expect(model.quizCodeList, isEmpty);
      expect(model.unitCodeList, isEmpty);
    });

    test('a PDF entry has no locked flag', () {
      final Map<String, dynamic> map = _pdf('p1').toMap();
      expect(map.containsKey('is_locked'), isFalse);
      expect(map['is_downloadable'], isTrue);
    });

    test('content counts follow the screen order', () {
      expect(_fixture().first.contentCounts, [
        (ContentKind.pdf, 2),
        (ContentKind.video, 1),
        (ContentKind.audio, 0),
        (ContentKind.quiz, 1),
      ]);
      expect(_fixture().first.contentCount, 4);
    });

    test('item ids differ even when made together', () {
      expect({for (int i = 0; i < 50; i++) newTopic1ItemId()}, hasLength(50));
    });
  });

  group('the repo', () {
    late MockFirebaseStorage storage;
    late MockDocumentReference doc;
    late Topic1Repo topic1Repo;

    setUp(() {
      registerFallbackValue(<String, dynamic>{});
      storage = MockFirebaseStorage();
      final MockFirebaseFirestore firestore = MockFirebaseFirestore();
      final MockCollectionReference collection = MockCollectionReference();
      doc = MockDocumentReference();
      when(() => firestore.collection(topics)).thenReturn(collection);
      when(() => collection.doc('a')).thenReturn(doc);
      when(() => doc.update(any())).thenAnswer((_) async {});
      topic1Repo = Topic1Repo(firestore: firestore, storage: storage);
    });

    test('every upload gets its own file under the topic', () async {
      final Topic1UploadedPdf first =
          await topic1Repo.uploadPdfFile('a', _bytes);
      final Topic1UploadedPdf second =
          await topic1Repo.uploadPdfFile('a', _bytes);

      expect(first.path, startsWith('topic1_pdf/a/'));
      expect(first.path, endsWith('.pdf'));
      expect(second.path, isNot(first.path),
          reason: 'replacing a file must not overwrite the saved one');
      expect(first.url, await storage.ref().child(first.path).getDownloadURL());
    });

    test('deleting files removes them and ignores ones already gone', () async {
      final Topic1UploadedPdf uploaded =
          await topic1Repo.uploadPdfFile('a', _bytes);

      await topic1Repo
          .deletePdfFiles([uploaded.path, 'topic1_pdf/a/missing.pdf', '']);

      await expectLater(
          () async => storage.ref().child(uploaded.path).getDownloadURL(),
          throwsA(isA<FirebaseException>()));
    });

    test('the PDF and video lists are written as maps', () async {
      await topic1Repo.setPdfList('a', [_pdf('p1')]);
      await topic1Repo.setVideoList('a', [_video('v1')]);

      final List<dynamic> writes =
          verify(() => doc.update(captureAny())).captured;
      expect(writes[0], {
        'pdf_list': [_pdf('p1').toMap()]
      });
      expect(writes[1], {
        'video_list': [_video('v1').toMap()]
      });
    });
  });

  group('copying from Topics', () {
    test('picks the old topics not here yet, by id and by code', () {
      expect(
          oldTopicIdsToCopy({
            'a': {'topic_code': 'NEWT-01'},
            'b': {'topic_code': ' newt-02 '}, // code already here
            'c': {'topic_code': 'NEWT-03'}, // copied before (same id)
            'd': {'topic_code': 'NEWT-01'}, // same code as 'a'
            'e': {}, // no code: matched on id only
          }, existingIds: {
            'c'
          }, existingCodes: {
            'NEWT-02'
          }),
          ['a', 'e']);
    });

    test('attached PDFs and videos become entries on the topic', () {
      int next = 0;
      final ConvertedTopic converted = newTopicFromOld(
        {
          'topic_code': 'NEWT-01',
          'topic_name': "Newton's First Law",
          'timeStamp': 5,
          'course_code': 'PHY-11',
          'unit_code': 'MECH-01',
          'display_priority': 2,
          'unitCodeList': ['MECH-01', 'APP-07'],
          'audio_code_list': ['AU-1'],
          'quiz_code_list': ['QZ-1'],
          'pdf_code_list': ['PDF-2', 'PDF-1', 'PDF-GONE', 'PDF-LOCKED'],
          'video_code_list': ['VID-1', 'VID-VIMEO', 'VID-GONE'],
        },
        pdfByCode: {
          'PDF-1': {
            'pdf_code': 'PDF-1',
            'pdf_title': 'First',
            'pdf_description': 'not carried over',
            'pdf_link': 'https://files/1',
            'pdf_type': 'FREE',
            'is_downloadable': true,
          },
          'PDF-2': {
            'pdf_code': 'PDF-2',
            'pdf_title': 'Second',
            'pdf_link': 'https://files/2',
            'pdf_type': 'PAID',
            'is_downloadable': false,
          },
          'PDF-LOCKED': {
            'pdf_code': 'PDF-LOCKED',
            'pdf_title': 'Locked',
            'pdf_link': 'https://files/3',
            'pdf_type': 'PAID',
            'is_locked': true,
          },
        },
        videoByCode: {
          'VID-1': {
            'video_code': 'VID-1',
            'video_title': 'Lecture',
            'video_link': 'https://youtu.be/dQw4w9WgXcQ',
            'video_type': 'FREE',
          },
          'VID-VIMEO': {
            'video_code': 'VID-VIMEO',
            'video_title': 'Elsewhere',
            'video_link': 'https://vimeo.com/1',
            'video_type': 'FREE',
          },
        },
        newId: () => 'id${next++}',
      );

      expect(converted.leftOut, 4,
          reason: 'missing PDF, locked PDF, non-YouTube and missing video');
      final Map<String, dynamic> data = converted.data;
      expect(data['pdf_list'], [
        {
          'id': 'id0',
          'pdf_title': 'Second',
          'pdf_name': 'PDF-2',
          'pdf_link': 'https://files/2',
          'pdf_path': '',
          'pdf_type': 'PAID',
          'is_downloadable': false,
        },
        {
          'id': 'id1',
          'pdf_title': 'First',
          'pdf_name': 'PDF-1',
          'pdf_link': 'https://files/1',
          'pdf_path': '',
          'pdf_type': 'FREE',
          'is_downloadable': true,
        },
      ]);
      expect(data['video_list'], [
        {
          'id': 'id2',
          'video_title': 'Lecture',
          'video_link': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'video_type': 'FREE',
        },
      ]);
      expect(data['topic_code'], 'NEWT-01');
      expect(data['display_priority'], 2);
      expect(data['unitCodeList'], ['MECH-01', 'APP-07']);
      expect(data['audio_code_list'], ['AU-1']);
      expect(data['quiz_code_list'], ['QZ-1']);
      expect(data.containsKey('pdf_code_list'), isFalse);
      expect(data.containsKey('video_code_list'), isFalse);

      final Topic1Model model = Topic1Model.fromMap('a', data);
      expect(model.pdfList.map((p) => p.storagePath), ['', ''],
          reason: 'the PDFs module still owns the files');
      expect(model.videoList.single.title, 'Lecture');
    });

    group('the repo', () {
      late MockFirebaseFirestore firestore;
      late MockCollectionReference target;
      late MockCollectionReference pdfCollection;
      late MockWriteBatch batch;
      late Topic1Repo topic1Repo;
      final Map<String, MockDocumentReference> targetDocs = {};

      void stubTarget(Map<String, Map<String, dynamic>> docs) {
        final MockQuerySnapshot targetSnapshot = _snapshot(docs);
        when(() => target.get()).thenAnswer((_) async => targetSnapshot);
      }

      setUp(() {
        registerFallbackValue(<String, dynamic>{});
        registerFallbackValue(MockDocumentReference());
        firestore = MockFirebaseFirestore();
        final MockCollectionReference old = MockCollectionReference();
        target = MockCollectionReference();
        pdfCollection = MockCollectionReference();
        final MockCollectionReference videoCollection =
            MockCollectionReference();
        final MockQuery pdfQuery = MockQuery();
        final MockQuery videoQuery = MockQuery();
        batch = MockWriteBatch();
        targetDocs.clear();
        when(() => firestore.collection(topic)).thenReturn(old);
        when(() => firestore.collection(topics)).thenReturn(target);
        when(() => firestore.collection(pdf)).thenReturn(pdfCollection);
        when(() => firestore.collection(video)).thenReturn(videoCollection);
        when(() => firestore.batch()).thenReturn(batch);
        when(() => batch.commit()).thenAnswer((_) async {});
        when(() => target.doc(any())).thenAnswer((invocation) =>
            targetDocs.putIfAbsent(
                invocation.positionalArguments.first as String,
                MockDocumentReference.new));
        final MockQuerySnapshot oldSnapshot = _snapshot({
          'old-a': {
            'topic_code': 'NEWT-01',
            'pdf_code_list': ['PDF-1'],
            'video_code_list': ['VID-1'],
          },
          'old-b': {
            'topic_code': 'NEWT-02',
            'pdf_code_list': ['PDF-9'],
          },
        });
        when(() => old.get()).thenAnswer((_) async => oldSnapshot);
        when(() =>
                pdfCollection.where('pdf_code', whereIn: any(named: 'whereIn')))
            .thenReturn(pdfQuery);
        when(() => videoCollection.where('video_code',
            whereIn: any(named: 'whereIn'))).thenReturn(videoQuery);
        final MockQuerySnapshot pdfSnapshot = _snapshot({
          'p': {
            'pdf_code': 'PDF-1',
            'pdf_title': 'Notes',
            'pdf_link': 'https://files/1',
            'pdf_type': 'FREE',
            'is_downloadable': true,
          },
        });
        final MockQuerySnapshot videoSnapshot = _snapshot({
          'v': {
            'video_code': 'VID-1',
            'video_title': 'Lecture',
            'video_link': 'https://youtu.be/dQw4w9WgXcQ',
            'video_type': 'PAID',
          },
        });
        when(() => pdfQuery.get()).thenAnswer((_) async => pdfSnapshot);
        when(() => videoQuery.get()).thenAnswer((_) async => videoSnapshot);
        topic1Repo = Topic1Repo(firestore: firestore);
      });

      test('converts the missing topics and keeps their ids', () async {
        stubTarget({
          'x': {'topic_code': 'newt-02'},
        });

        expect(await topic1Repo.copyFromTopics(), (copied: 1, leftOut: 0));

        final List<dynamic> asked = verify(() => pdfCollection.where('pdf_code',
            whereIn: captureAny(named: 'whereIn'))).captured;
        expect(
            asked,
            [
              ['PDF-1']
            ],
            reason: 'only the content of topics being copied is read');
        final Map<String, dynamic> written = verify(() => batch
                .set<Map<String, dynamic>>(targetDocs['old-a']!, captureAny()))
            .captured
            .single;
        expect(written['topic_code'], 'NEWT-01');
        expect((written['pdf_list'] as List).single['pdf_path'], '');
        expect((written['video_list'] as List).single['video_link'],
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
        expect(targetDocs.keys, isNot(contains('old-b')),
            reason: 'its code is already here');
        verify(() => batch.commit()).called(1);
      });

      test('reads and writes nothing more when every topic is here', () async {
        stubTarget({'old-a': {}, 'old-b': {}});

        expect(await topic1Repo.copyFromTopics(), (copied: 0, leftOut: 0));
        verifyNever(() => firestore.batch());
        verifyNever(
            () => pdfCollection.where(any(), whereIn: any(named: 'whereIn')));
      });
    });

    test('the view model reloads the list after copying', () async {
      when(() => repo.copyFromTopics())
          .thenAnswer((_) async => (copied: 2, leftOut: 1));
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);

      final Future<TopicsCopyResult?> copying = vm.copyFromTopics();
      expect(vm.copying, isTrue);
      expect(await copying, (copied: 2, leftOut: 1));
      expect(vm.copying, isFalse);
      verify(() => repo.getFirstTopicList(any())).called(1);
    });

    test('the view model skips the reload when nothing was copied', () async {
      when(() => repo.copyFromTopics())
          .thenAnswer((_) async => (copied: 0, leftOut: 0));
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);

      expect(await vm.copyFromTopics(), (copied: 0, leftOut: 0));
      verifyNever(() => repo.getFirstTopicList(any()));
    });

    testWidgets('a failed copy reports null and stops copying', (tester) async {
      await _pumpShell(tester);
      when(() => repo.copyFromTopics()).thenThrow(Exception('denied'));
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);

      expect(await vm.copyFromTopics(), isNull);
      expect(vm.copying, isFalse);
      expect(AppToast.messages,
          contains('Error while copying topics from Topics'));
      AppToast.dismissAll();
    });

    test('the result toast counts topics and left-out items', () {
      expect(Topic1List.copyResultMessage((copied: 0, leftOut: 0)),
          'Nothing to copy: every topic is already here');
      expect(Topic1List.copyResultMessage((copied: 1, leftOut: 0)),
          'Copied 1 topic from Topics');
      expect(
          Topic1List.copyResultMessage((copied: 3, leftOut: 2)),
          'Copied 3 topics from Topics · 2 PDFs/videos left out '
          '(missing, locked or not YouTube)');
    });

    testWidgets('the list button asks first, then copies and says how many',
        (tester) async {
      when(() => repo.copyFromTopics())
          .thenAnswer((_) async => (copied: 2, leftOut: 1));
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: Topic1List(showCopyButton: true)), vm);

      expect(find.text('COPY FROM TOPICS'), findsOneWidget);
      await tester.tap(find.byKey(const Key('topic1_copy_button')));
      await tester.pumpAndSettle();
      expect(find.text('Copy topics from Topics?'), findsOneWidget);
      verifyNever(() => repo.copyFromTopics());

      await tester.tap(find.byKey(const Key('topic1_copy_confirm')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.copyFromTopics()).called(1);
      expect(
          AppToast.messages,
          contains('Copied 2 topics from Topics · 1 PDF/video left out '
              '(missing, locked or not YouTube)'));
      AppToast.dismissAll();
    });

    testWidgets('cancelling the dialog copies nothing', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(380, 820),
          const Scaffold(body: Topic1List(showCopyButton: true)), vm);

      await tester.tap(find.byKey(const Key('topic1_copy_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => repo.copyFromTopics());
    });

    testWidgets('the copy button is hidden by default', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: Topic1List()), vm);

      expect(find.byKey(const Key('topic1_copy_button')), findsNothing);
      expect(find.text('COPY FROM TOPICS'), findsNothing);
      expect(find.text('NEW TOPIC'), findsOneWidget);
    });
  });

  group('saving PDFs', () {
    test('uploads only new files and cleans up the ones no longer used',
        () async {
      int uploads = 0;
      when(() => repo.uploadPdfFile(any(), any())).thenAnswer((_) async {
        uploads++;
        return (url: 'https://files/new$uploads', path: 'new$uploads');
      });
      when(() => repo.setPdfList(any(), any())).thenAnswer((_) async {});
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);
      final Topic1Model topic = _fixture().first; // p1, p2

      final bool ok = await vm.savePdfs(topic, [
        // p2 kept as it is, now first.
        Topic1PdfDraft(
            id: 'p2',
            title: 'Renamed',
            type: 'PAID',
            isDownloadable: false,
            existing: _pdf('p2')),
        // p1's file replaced.
        Topic1PdfDraft(
            id: 'p1',
            title: 'Notes',
            type: 'FREE',
            isDownloadable: true,
            existing: _pdf('p1'),
            newBytes: _bytes,
            newFileName: 'v2.pdf'),
        // A brand-new PDF.
        Topic1PdfDraft(
            id: 'p3',
            title: 'Extra',
            type: 'FREE',
            isDownloadable: false,
            newBytes: _bytes,
            newFileName: 'extra.pdf'),
      ]);

      expect(ok, isTrue);
      expect(uploads, 2);
      final List<Topic1Pdf> saved =
          verify(() => repo.setPdfList('a', captureAny())).captured.single;
      expect(saved.map((p) => p.id), ['p2', 'p1', 'p3']);
      expect(saved[0].title, 'Renamed');
      expect(saved[0].link, 'https://files/p2');
      expect(saved[0].isDownloadable, isFalse,
          reason: 'an edited switch is saved');
      expect(saved[1].link, 'https://files/new1');
      expect(saved[1].storagePath, 'new1');
      expect(saved[1].fileName, 'v2.pdf');
      expect(saved[2].fileName, 'extra.pdf');
      expect(topic.pdfList, saved, reason: 'the list updates in place');
      // p1's old file is no longer used by anything.
      verify(() => repo.deletePdfFiles(['topic1_pdf/a/p1.pdf'])).called(1);
    });

    testWidgets('a failed save deletes what it uploaded and changes nothing',
        (tester) async {
      await _pumpShell(tester);
      when(() => repo.uploadPdfFile(any(), any()))
          .thenAnswer((_) async => (url: 'https://files/new', path: 'new'));
      when(() => repo.setPdfList(any(), any())).thenThrow(Exception('denied'));
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);
      final Topic1Model topic = _fixture().first;
      final List<Topic1Pdf> before = topic.pdfList;

      final bool ok = await vm.savePdfs(topic, [
        Topic1PdfDraft(
            id: 'p9',
            title: 'New',
            type: 'FREE',
            isDownloadable: false,
            newBytes: _bytes,
            newFileName: 'n.pdf'),
      ]);

      expect(ok, isFalse);
      expect(topic.pdfList, same(before));
      verify(() => repo.deletePdfFiles(['new'])).called(1);
      verifyNever(() => repo.deletePdfFiles(['topic1_pdf/a/p1.pdf']));
    });

    testWidgets('a failed upload stops before writing the list',
        (tester) async {
      await _pumpShell(tester);
      int uploads = 0;
      when(() => repo.uploadPdfFile(any(), any())).thenAnswer((_) async {
        if (++uploads == 2) throw Exception('offline');
        return (url: 'https://files/new', path: 'new1');
      });
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);

      Topic1PdfDraft fresh(String id) => Topic1PdfDraft(
          id: id,
          title: id,
          type: 'FREE',
          isDownloadable: false,
          newBytes: _bytes,
          newFileName: '$id.pdf');

      expect(
          await vm.savePdfs(_fixture()[1], [fresh('x'), fresh('y')]), isFalse);
      verifyNever(() => repo.setPdfList(any(), any()));
      verify(() => repo.deletePdfFiles(['new1'])).called(1);
    });
  });

  group('saving videos', () {
    test('writes the list and updates the topic in place', () async {
      when(() => repo.setVideoList(any(), any())).thenAnswer((_) async {});
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);
      final Topic1Model topic = _fixture()[1];

      expect(await vm.saveVideos(topic, [_video('v9')]), isTrue);
      expect(topic.videoList.single.id, 'v9');
    });

    testWidgets('a failed save leaves the topic alone', (tester) async {
      await _pumpShell(tester);
      when(() => repo.setVideoList(any(), any()))
          .thenThrow(Exception('denied'));
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);
      final Topic1Model topic = _fixture().first;

      expect(await vm.saveVideos(topic, []), isFalse);
      expect(topic.videoList.single.id, 'v1');
    });
  });

  group('delete', () {
    test('drops the row once the write has gone through, then its files',
        () async {
      when(() => repo.deleteTopic(any())).thenAnswer((_) async {});
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);
      await vm.getFirstTopicList();

      expect(await vm.deleteTopic(vm.topicList.first), isTrue);
      expect(vm.topicList.map((t) => t.docId), ['b', 'c']);
      expect(vm.topicLength, 2);
      verify(() => repo
              .deletePdfFiles(['topic1_pdf/a/p1.pdf', 'topic1_pdf/a/p2.pdf']))
          .called(1);
    });

    testWidgets('a failed delete leaves the row and its files alone',
        (tester) async {
      await _pumpShell(tester);
      when(() => repo.deleteTopic(any())).thenThrow(Exception('denied'));
      final Topic1ViewModel vm = Topic1ViewModel(topic1Repo: repo);
      await vm.getFirstTopicList();

      expect(await vm.deleteTopic(vm.topicList.first), isFalse);
      expect(vm.topicList.map((t) => t.docId), ['a', 'b', 'c']);
      verifyNever(() => repo.deletePdfFiles(any()));
    });
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = Topic1ViewModel(topic1Repo: repo);
        await _pump(tester, size, const Scaffold(body: Topic1List()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('New Topics'), findsOneWidget);
        expect(_rows(), size.width < 900 ? findsWidgets : findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = Topic1ViewModel(topic1Repo: repo);
        await _pump(tester, size, const AddTopic1(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a topic'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = Topic1ViewModel(topic1Repo: repo);
        await _pump(tester, size, EditTopic1(topicData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit topic'), findsOneWidget);
        expect(find.text('2 PDF · 1 video · 1 quiz'), findsOneWidget);
      });

      testWidgets('the content page lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = Topic1ViewModel(topic1Repo: repo);
        await _pump(
            tester, size, Topic1Details(topicData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text("Newton's First Law"), findsOneWidget);
        expect(find.text('PDFs'), findsOneWidget);
        expect(find.text('Videos'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('Quiz'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('the row counts only the content that is there',
        (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: Topic1List()), vm);

      expect(find.text('PDF 2'), findsOneWidget);
      expect(find.text('Video 1'), findsOneWidget);
      expect(find.text('Quiz 1'), findsOneWidget);
      expect(find.text('Audio 0'), findsNothing);
      expect(find.text('No content yet'), findsNWidgets(2));
    });

    testWidgets('search runs on the topic code', (tester) async {
      when(() => repo.searchTopic(any()))
          .thenAnswer((_) async => [_fixture().first]);
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: Topic1List()), vm);

      await tester.enterText(find.byType(TextField).first, 'newt-01');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      verify(() => repo.searchTopic('NEWT-01')).called(1);
      expect(_rows(), findsOneWidget);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1024, 900), const AddTopic1(), vm);

      await tester.tap(find.byKey(const Key('topic1_save_button')));
      await tester.pump();

      expect(find.text('Choose the course this belongs to'), findsOneWidget);
      expect(find.text('Give the topic a code'), findsOneWidget);
      expect(find.text('Set a display priority'), findsOneWidget);
      verifyNever(() => repo.addTopic(any()));
    });

    testWidgets('editing saves the topic fields', (tester) async {
      when(() => repo.updateTopic(any(), any())).thenAnswer((_) async {});
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1024, 900),
          EditTopic1(topicData: _fixture()[1]), vm);

      await tester.tap(find.byKey(const Key('topic1_save_button')));
      await tester.pump();
      await tester.pump();

      final Topic1Model saved =
          verify(() => repo.updateTopic(captureAny(), 'b')).captured.single;
      expect(saved.code, 'NEWT-02');
      expect(saved.unitCodeList, ["MECH-01", "MECH-02", "APP-07"]);
    });
  });

  group('the PDF editor', () {
    PickedPdf? nextPick;
    Future<PickedPdf?> fakePick() async => nextPick;

    setUp(() => nextPick = (bytes: _bytes, name: 'chapter-1.pdf'));

    testWidgets('a new PDF needs a title, a file and an access type',
        (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1200),
          Topic1Details(topicData: _fixture()[1], pickFile: fakePick), vm);

      expect(find.text('No PDFs uploaded to this topic.'), findsOneWidget);
      await _tap(tester, const Key('topic1_pdf_add'));
      await _tap(tester, const Key('topic1_pdf_save'));

      expect(find.text('Give the PDF a title'), findsOneWidget);
      expect(find.text('Choose a PDF file'), findsOneWidget);
      expect(find.text('Choose whether it is free or paid'), findsOneWidget);
      verifyNever(() => repo.uploadPdfFile(any(), any()));
      verifyNever(() => repo.setPdfList(any(), any()));
    });

    testWidgets('a PDF row offers Downloadable but not Locked', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1200),
          Topic1Details(topicData: _fixture()[1], pickFile: fakePick), vm);

      await _tap(tester, const Key('topic1_pdf_add'));

      expect(
          find.byKey(const Key('topic1_pdf_downloadable_0')), findsOneWidget);
      expect(find.text('Downloadable'), findsOneWidget);
      expect(find.text('Locked'), findsNothing);
    });

    testWidgets('a picked file is uploaded and saved on Save', (tester) async {
      when(() => repo.uploadPdfFile(any(), any())).thenAnswer(
          (_) async => (url: 'https://files/up', path: 'topic1_pdf/b/up.pdf'));
      when(() => repo.setPdfList(any(), any())).thenAnswer((_) async {});
      final Topic1Model topic = _fixture()[1];
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1200),
          Topic1Details(topicData: topic, pickFile: fakePick), vm);

      await _tap(tester, const Key('topic1_pdf_add'));
      await tester.enterText(
          find.byKey(const Key('topic1_pdf_title_0')), 'Chapter 1 notes');
      await _tap(tester, const Key('topic1_pdf_choose_0'));
      await tester.pump();
      expect(find.text('chapter-1.pdf'), findsOneWidget);
      await _tap(tester, const Key('topic1_pdf_0_type_paid'));
      await _tap(tester, const Key('topic1_pdf_save'));
      await tester.pump();

      verify(() => repo.uploadPdfFile('b', _bytes)).called(1);
      final List<Topic1Pdf> saved =
          verify(() => repo.setPdfList('b', captureAny())).captured.single;
      expect(saved.single.title, 'Chapter 1 notes');
      expect(saved.single.type, 'PAID');
      expect(saved.single.fileName, 'chapter-1.pdf');
      expect(saved.single.link, 'https://files/up');
      expect(topic.pdfList.single.link, 'https://files/up');
      expect(find.text('Saved'), findsWidgets);
    });

    testWidgets('removing a saved PDF saves the shorter list', (tester) async {
      when(() => repo.setPdfList(any(), any())).thenAnswer((_) async {});
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1400),
          Topic1Details(topicData: _fixture().first, pickFile: fakePick), vm);

      await _tap(tester, const Key('topic1_pdf_remove_0'));
      await _tap(tester, const Key('topic1_pdf_save'));
      await tester.pump();

      final List<Topic1Pdf> saved =
          verify(() => repo.setPdfList('a', captureAny())).captured.single;
      expect(saved.map((p) => p.id), ['p2']);
      verifyNever(() => repo.uploadPdfFile(any(), any()));
      verify(() => repo.deletePdfFiles(['topic1_pdf/a/p1.pdf'])).called(1);
    });

    testWidgets('saved PDFs open folded and unfold on tap', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1400),
          Topic1Details(topicData: _fixture().first, pickFile: fakePick), vm);

      expect(find.byKey(const Key('topic1_pdf_title_0')), findsNothing);
      expect(find.byKey(const Key('topic1_pdf_title_1')), findsNothing);
      expect(find.text('Free · p1.pdf · Downloadable'), findsOneWidget);

      await _tap(tester, const Key('topic1_pdf_toggle_0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic1_pdf_title_0')), findsOneWidget);
      expect(find.byKey(const Key('topic1_pdf_title_1')), findsNothing);

      await _tap(tester, const Key('topic1_pdf_toggle_0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic1_pdf_title_0')), findsNothing);
    });

    testWidgets('a new PDF opens unfolded beside folded saved ones',
        (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1400),
          Topic1Details(topicData: _fixture().first, pickFile: fakePick), vm);

      await _tap(tester, const Key('topic1_pdf_add'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('topic1_pdf_title_2')), findsOneWidget);
      expect(find.text('Untitled PDF'), findsOneWidget);
      expect(find.byKey(const Key('topic1_pdf_title_0')), findsNothing);
    });

    testWidgets('a folded PDF with a problem unfolds on Save', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1400),
          Topic1Details(topicData: _fixture().first, pickFile: fakePick), vm);

      await _tap(tester, const Key('topic1_pdf_toggle_0'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('topic1_pdf_title_0')), '');
      await _tap(tester, const Key('topic1_pdf_toggle_0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic1_pdf_title_0')), findsNothing);

      await _tap(tester, const Key('topic1_pdf_save'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('topic1_pdf_title_0')), findsOneWidget);
      expect(find.text('Give the PDF a title'), findsOneWidget);
      expect(find.byKey(const Key('topic1_pdf_title_1')), findsNothing);
      verifyNever(() => repo.setPdfList(any(), any()));

      // Folded again, the row says it needs fixing.
      await _tap(tester, const Key('topic1_pdf_toggle_0'));
      await tester.pumpAndSettle();
      expect(find.text('Needs fixing · Free · p1.pdf · Downloadable'),
          findsOneWidget);
    });
  });

  group('the video editor', () {
    testWidgets('only a YouTube video link is accepted', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1200),
          Topic1Details(topicData: _fixture()[1]), vm);

      await _tap(tester, const Key('topic1_video_add'));
      await tester.enterText(
          find.byKey(const Key('topic1_video_title_0')), 'Lecture');
      await tester.enterText(find.byKey(const Key('topic1_video_link_0')),
          'https://example.com/video');
      await _tap(tester, const Key('topic1_video_0_type_free'));
      await _tap(tester, const Key('topic1_video_save'));

      expect(find.text('Not a YouTube video link'), findsOneWidget);
      verifyNever(() => repo.setVideoList(any(), any()));
    });

    testWidgets('a short link is saved in the full form', (tester) async {
      when(() => repo.setVideoList(any(), any())).thenAnswer((_) async {});
      final Topic1Model topic = _fixture()[1];
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(
          tester, const Size(1440, 1200), Topic1Details(topicData: topic), vm);

      await _tap(tester, const Key('topic1_video_add'));
      await tester.enterText(
          find.byKey(const Key('topic1_video_title_0')), 'Lecture');
      await tester.enterText(find.byKey(const Key('topic1_video_link_0')),
          'https://youtu.be/dQw4w9WgXcQ?si=share');
      await tester.pump();
      expect(find.text('YouTube video · dQw4w9WgXcQ'), findsOneWidget);
      await _tap(tester, const Key('topic1_video_0_type_free'));
      await _tap(tester, const Key('topic1_video_save'));
      await tester.pump();

      final List<Topic1Video> saved =
          verify(() => repo.setVideoList('b', captureAny())).captured.single;
      expect(saved.single.link, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(saved.single.type, 'FREE');
      expect(topic.videoList.single.title, 'Lecture');
    });

    testWidgets('saved videos open folded and unfold on tap', (tester) async {
      final vm = Topic1ViewModel(topic1Repo: repo);
      await _pump(tester, const Size(1440, 1400),
          Topic1Details(topicData: _fixture().first), vm);

      expect(find.byKey(const Key('topic1_video_link_0')), findsNothing);
      expect(find.text('Lecture v1'), findsOneWidget);
      expect(find.text('Paid · YouTube · dQw4w9WgXcQ'), findsOneWidget);

      await _tap(tester, const Key('topic1_video_toggle_0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic1_video_link_0')), findsOneWidget);

      await _tap(tester, const Key('topic1_video_toggle_0'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic1_video_link_0')), findsNothing);
    });
  });
}
