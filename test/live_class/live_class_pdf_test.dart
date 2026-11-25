// Firestore mocks implement its sealed classes, as the other repo tests do.
// ignore_for_file: subtype_of_sealed_class

import 'dart:typed_data';

import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

class LiveClassModelFake extends Fake implements LiveClassModel {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// Answers every pick with [file] (null = the admin cancelled).
class FakeFilePicker extends FilePicker {
  PlatformFile? file;
  FileType? lastType;
  List<String>? lastExtensions;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    lastType = type;
    lastExtensions = allowedExtensions;
    final PlatformFile? picked = file;
    return picked == null ? null : FilePickerResult([picked]);
  }
}

const String _url = 'https://storage.example/live_class_pdf/pdf_past?t=1';

LiveClassModel _class(String id, DateTime start,
        {String pdfLink = '', String pdfName = ''}) =>
    LiveClassModel(
      docId: id,
      title: 'Class $id',
      description: '',
      youtubeLink: 'https://www.youtube.com/watch?v=abc',
      teacherName: 'Ravi Kumar',
      subjectNames: const ['Mechanics'],
      subjectCodes: const ['MECH'],
      startDateTime: start,
      endDateTime: start.add(const Duration(hours: 1)),
      pdfLink: pdfLink,
      pdfName: pdfName,
    );

Future<void> _signInAs(String role) async {
  SharedPreferences.setMockInitialValues(
      <String, Object>{adminIdPrefsKey: 'riya', rolePrefsKey: role});
  sharedPreferences = await SharedPreferences.getInstance();
}

Future<void> _pumpList(WidgetTester tester, LiveClassViewModel vm,
    {bool pastTab = true}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<LiveClassViewModel>.value(
    value: vm,
    child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: LiveClassList())),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (pastTab) {
    await tester.tap(find.byKey(const Key('live_class_tab_past')));
    await tester.pump();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(LiveClassModelFake());
    registerFallbackValue(Uint8List(0));
  });

  group('model', () {
    final DateTime t = DateTime(2026, 4, 2, 18);

    test('reads pdfLink / pdfName from the document', () {
      final MockDocumentSnapshot doc = MockDocumentSnapshot();
      when(() => doc.id).thenReturn('c1');
      when(() => doc.data()).thenReturn({
        'title': 'Kinematics',
        'startTime': t.millisecondsSinceEpoch,
        'endTime': t.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'pdfLink': _url,
        'pdfName': 'Kinematics notes.pdf',
      });
      final LiveClassModel model = LiveClassModel.fromDocumentSnapshot(doc);
      expect(model.pdfLink, _url);
      expect(model.pdfName, 'Kinematics notes.pdf');
      expect(model.hasPdf, isTrue);
    });

    test('a class saved without a PDF has none', () {
      final MockDocumentSnapshot doc = MockDocumentSnapshot();
      when(() => doc.id).thenReturn('c2');
      when(() => doc.data()).thenReturn({'title': 'Optics'});
      final LiveClassModel model = LiveClassModel.fromDocumentSnapshot(doc);
      expect(model.pdfLink, '');
      expect(model.hasPdf, isFalse);
    });

    test('never written by the panel, so an edit cannot wipe it', () {
      final Map<String, dynamic> map =
          _class('c', t, pdfLink: _url, pdfName: 'a.pdf').toMap();
      expect(map.containsKey('pdfLink'), isFalse);
      expect(map.containsKey('pdfName'), isFalse);
    });
  });

  group('repo', () {
    late MockFirebaseFirestore firestore;
    late MockDocumentReference doc;
    late MockFirebaseStorage storage;
    late LiveClassRepo repo;
    final Uint8List bytes = Uint8List.fromList([37, 80, 68, 70]);

    setUp(() {
      registerFallbackValue(<String, dynamic>{});
      firestore = MockFirebaseFirestore();
      final MockCollectionReference collection = MockCollectionReference();
      doc = MockDocumentReference();
      when(() => firestore.collection(liveClasses)).thenReturn(collection);
      when(() => collection.doc('c1')).thenReturn(doc);
      when(() => doc.update(any())).thenAnswer((_) async {});
      when(() => doc.delete()).thenAnswer((_) async {});
      storage = MockFirebaseStorage();
      repo = LiveClassRepo(firestore: firestore, storage: storage);
    });

    Reference file() =>
        storage.ref().child('live_class_pdf').child('pdf_c1');

    test('upload stores one file per class and saves its link and name',
        () async {
      final String url = await repo.uploadClassPdf('c1', bytes, ' a.pdf ');

      expect(url, await file().getDownloadURL());
      final Map<Object, Object?> written =
          verify(() => doc.update(captureAny())).captured.single;
      expect(written['pdfLink'], url);
      expect(written['pdfName'], 'a.pdf');
    });

    test('deleting the class deletes its PDF too', () async {
      await repo.uploadClassPdf('c1', bytes, 'a.pdf');
      await repo.deleteLiveClass('c1');

      verify(() => doc.delete()).called(1);
      await expectLater(() async => file().getDownloadURL(),
          throwsA(isA<FirebaseException>()));
    });

    test('deleting a class that never had a PDF still works', () async {
      await repo.deleteLiveClass('c1');
      verify(() => doc.delete()).called(1);
    });
  });

  group('view model', () {
    late MockLiveClassRepo repo;
    final Uint8List bytes = Uint8List.fromList([37, 80, 68, 70]); // %PDF

    setUp(() {
      repo = MockLiveClassRepo();
    });

    test('a successful upload updates the class in place', () async {
      when(() => repo.uploadClassPdf(any(), any(), any()))
          .thenAnswer((_) async => _url);
      final vm = LiveClassViewModel(liveClassRepo: repo);
      final LiveClassModel c = _class('past', DateTime(2026));

      expect(await vm.uploadClassPdf(c, bytes, ' notes.pdf '), isTrue);
      verify(() => repo.uploadClassPdf('past', bytes, ' notes.pdf '))
          .called(1);
      expect(c.pdfLink, _url);
      expect(c.pdfName, 'notes.pdf');
      expect(vm.isUploadingPdf('past'), isFalse);
    });

    test('a failed upload leaves the class as it was', () async {
      when(() => repo.uploadClassPdf(any(), any(), any()))
          .thenThrow(Exception('offline'));
      final vm = LiveClassViewModel(liveClassRepo: repo);
      final LiveClassModel c = _class('past', DateTime(2026));

      expect(await vm.uploadClassPdf(c, bytes, 'notes.pdf'), isFalse);
      expect(c.hasPdf, isFalse);
      expect(vm.isUploadingPdf('past'), isFalse);
    });

    test('a file over the limit is refused without uploading', () async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      final LiveClassModel c = _class('past', DateTime(2026));
      final Uint8List huge =
          Uint8List(LiveClassViewModel.maxClassPdfBytes + 1);

      expect(await vm.uploadClassPdf(c, huge, 'big.pdf'), isFalse);
      verifyNever(() => repo.uploadClassPdf(any(), any(), any()));
    });

    test('deleting the chat keeps the PDF', () async {
      when(() => repo.requestChatDelete(any())).thenAnswer((_) async {});
      final vm = LiveClassViewModel(liveClassRepo: repo);
      final LiveClassModel c =
          _class('past', DateTime(2026), pdfLink: _url, pdfName: 'a.pdf');

      expect(await vm.deleteChat(c), isTrue);
      expect(c.pdfLink, _url);
      verifyNever(() => repo.deleteLiveClass(any()));
      verifyNever(() => repo.uploadClassPdf(any(), any(), any()));
    });
  });

  group('card', () {
    late MockLiveClassRepo repo;
    late FakeFilePicker picker;
    final DateTime now = DateTime.now();
    late LiveClassModel past;
    late LiveClassModel pastWithPdf;
    late LiveClassModel upcoming;

    setUp(() async {
      await _signInAs(roleAdmin);
      past = _class('past', now.subtract(const Duration(days: 2)));
      pastWithPdf = _class('done', now.subtract(const Duration(days: 3)),
          pdfLink: _url, pdfName: 'Algebra notes.pdf');
      upcoming = _class('up', now.add(const Duration(days: 1)));
      repo = MockLiveClassRepo();
      when(() => repo.getLiveClassList())
          .thenAnswer((_) async => [past, pastWithPdf, upcoming]);
      when(() => repo.getTeachers()).thenAnswer((_) async => const []);
      when(() => repo.getSubjects()).thenAnswer((_) async => const []);
      picker = FakeFilePicker();
      FilePicker.platform = picker;
    });

    testWidgets('an admin gets Upload PDF on a past class without one',
        (tester) async {
      await _pumpList(tester, LiveClassViewModel(liveClassRepo: repo));

      expect(
          find.descendant(
              of: find.byKey(const Key('live_class_upload_pdf_past')),
              matching: find.text('Upload PDF')),
          findsOneWidget);
      // The class that already has its PDF shows it instead.
      expect(find.byKey(const Key('live_class_upload_pdf_done')), findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const Key('live_class_pdf_done')),
              matching: find.text('Algebra notes.pdf')),
          findsOneWidget);
      expect(find.byKey(const Key('live_class_pdf_replace_done')),
          findsOneWidget);
      expect(find.byKey(const Key('live_class_pdf_past')), findsNothing);
    });

    testWidgets('no Upload PDF before the class is over', (tester) async {
      await _pumpList(tester, LiveClassViewModel(liveClassRepo: repo),
          pastTab: false);

      expect(find.byKey(const Key('live_class_upload_pdf_up')), findsNothing);
    });

    testWidgets('a subadmin can open the PDF but not upload or replace',
        (tester) async {
      await _signInAs(roleSubadmin);
      await _pumpList(tester, LiveClassViewModel(liveClassRepo: repo));

      expect(find.byKey(const Key('live_class_upload_pdf_past')), findsNothing);
      expect(find.byKey(const Key('live_class_pdf_open_done')), findsOneWidget);
      expect(find.byKey(const Key('live_class_pdf_replace_done')),
          findsNothing);
    });

    testWidgets('picking a PDF uploads it and shows it on the card',
        (tester) async {
      final Uint8List bytes = Uint8List.fromList([37, 80, 68, 70]);
      picker.file = PlatformFile(name: 'Lesson 4.pdf', size: 4, bytes: bytes);
      when(() => repo.uploadClassPdf(any(), any(), any()))
          .thenAnswer((_) async => _url);
      await _pumpList(tester, LiveClassViewModel(liveClassRepo: repo));

      await tester.tap(find.byKey(const Key('live_class_upload_pdf_past')));
      await tester.pump();
      await tester.pump();

      expect(picker.lastType, FileType.custom);
      expect(picker.lastExtensions, ['pdf']);
      verify(() => repo.uploadClassPdf('past', bytes, 'Lesson 4.pdf'))
          .called(1);
      expect(find.byKey(const Key('live_class_upload_pdf_past')), findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const Key('live_class_pdf_past')),
              matching: find.text('Lesson 4.pdf')),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // let the toast go
    });

    testWidgets('Replace uploads over the same class', (tester) async {
      final Uint8List bytes = Uint8List.fromList([37, 80, 68, 70, 10]);
      picker.file = PlatformFile(name: 'v2.pdf', size: 5, bytes: bytes);
      when(() => repo.uploadClassPdf(any(), any(), any()))
          .thenAnswer((_) async => '$_url&v=2');
      await _pumpList(tester, LiveClassViewModel(liveClassRepo: repo));

      await tester.tap(find.byKey(const Key('live_class_pdf_replace_done')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.uploadClassPdf('done', bytes, 'v2.pdf')).called(1);
      expect(pastWithPdf.pdfLink, '$_url&v=2');
      expect(find.text('v2.pdf'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('cancelling the picker uploads nothing', (tester) async {
      picker.file = null;
      await _pumpList(tester, LiveClassViewModel(liveClassRepo: repo));

      await tester.tap(find.byKey(const Key('live_class_upload_pdf_past')));
      await tester.pump();

      verifyNever(() => repo.uploadClassPdf(any(), any(), any()));
      expect(find.byKey(const Key('live_class_upload_pdf_past')),
          findsOneWidget);
    });
  });
}
