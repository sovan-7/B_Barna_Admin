import 'dart:typed_data';

import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/repo/pdf_repo.dart';
import 'package:bbarna/documents/pdf/screen/add_pdf.dart';
import 'package:bbarna/documents/pdf/screen/edit_pdf.dart';
import 'package:bbarna/documents/pdf/screen/pdf_list.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/documents/pdf/widgets/pdf_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockPdfRepo extends Mock implements PdfRepo {}

class PdfModelFake extends Fake implements PdfModel {}

PdfModel _pdf(
  String id,
  String code,
  String title, {
  String link = "https://example.com/a.pdf",
  String type = "FREE",
  bool downloadable = true,
  bool locked = false,
  int timeStamp = 0,
}) {
  final PdfModel model = PdfModel(code, "A description that runs on a bit.",
      title, link, downloadable, type, timeStamp, locked);
  model.docId = id;
  return model;
}

List<PdfModel> _fixture() => [
      _pdf('a', 'NOTES-01', 'Kinematics formula sheet', timeStamp: 300),
      _pdf('b', 'NOTES-02', 'Newton\'s Laws worksheet',
          type: "PAID", downloadable: false, locked: true, timeStamp: 200),
      _pdf(
          'c',
          'NOTES-03',
          'An extremely long PDF title that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          link: "",
          timeStamp: 100),
    ];

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockPdfRepo repo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, PdfViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<PdfViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue(PdfModelFake());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = MockPdfRepo();
    when(() => repo.getFirstPdfList(any())).thenAnswer((_) async => _fixture());
    when(() => repo.getPdfListLength()).thenAnswer((_) async => 3);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = PdfViewModel(pdfRepo: repo);
        await _pump(tester, size, const Scaffold(body: PDFList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('PDFs'), findsOneWidget);
        expect(find.byType(PdfCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = PdfViewModel(pdfRepo: repo);
        await _pump(tester, size, const AddPdf(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a PDF'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = PdfViewModel(pdfRepo: repo);
        await _pump(tester, size, EditPdf(pdfData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit PDF'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('says how much of the collection is loaded', (tester) async {
      when(() => repo.getPdfListLength()).thenAnswer((_) async => 120);
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);

      expect(find.text('Showing 3 of 120'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsOneWidget);
    });

    testWidgets('a PDF with no file says so', (tester) async {
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);

      // Exactly what an orphaned row from a failed upload looks like.
      expect(find.text('No file uploaded'), findsOneWidget);
      expect(find.text('Open the file'), findsNWidgets(2));
    });

    testWidgets('the two flags are labelled, not bare icons', (tester) async {
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);

      expect(find.text('Downloadable'), findsNWidgets(2));
      expect(find.text('View only'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
      expect(find.text('Unlocked'), findsNWidgets(2));
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1024, 768), const Scaffold(body: PDFList()), vm);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a search survives the round trip to Add', (tester) async {
      when(() => repo.searchPdf(any()))
          .thenAnswer((_) async => [_fixture().first]);
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);

      await tester.enterText(find.byType(TextField).first, 'notes-01');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(PdfCard), findsOneWidget);

      await tester.tap(find.text('NEW PDF'));
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // Coming back re-runs the search rather than loading the first page
      // under a search box that still says "notes-01".
      verify(() => repo.searchPdf('NOTES-01')).called(2);
      verify(() => repo.getFirstPdfList(any())).called(1);
      expect(find.widgetWithText(TextField, 'notes-01'), findsOneWidget);
      expect(find.byType(PdfCard), findsOneWidget);
    });

    testWidgets('a search result that arrives late does not replace a newer one',
        (tester) async {
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);

      when(() => repo.searchPdf('OLD')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return [_fixture().last];
      });
      when(() => repo.searchPdf('NEW'))
          .thenAnswer((_) async => [_fixture().first]);

      vm.searchText = 'old';
      final Future<void> slow = vm.refresh();
      vm.searchText = 'new';
      await vm.refresh();
      await tester.pump(const Duration(seconds: 2));
      await slow;

      expect(vm.pdfList.map((p) => p.docId).toList(), ['a']);
    });
  });

  group('the flag toggles', () {
    testWidgets('lock goes through the repo and updates in place',
        (tester) async {
      when(() => repo.setPdfFlag(any(), any(), any()))
          .thenAnswer((_) async {});

      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);
      clearInteractions(repo);

      await tester.tap(find.byKey(const Key('pdf_lock_a')));
      await tester.pump();
      await tester.pump();

      // It used to write to Firestore from the widget and do nothing else
      // at all — not even a refetch — so the padlock did not change until
      // you left the screen.
      verify(() => repo.setPdfFlag('a', 'is_locked', true)).called(1);
      expect(vm.pdfList.firstWhere((p) => p.docId == 'a').isLocked, isTrue);
      expect(find.text('Locked'), findsNWidgets(2));
    });

    testWidgets('downloadable toggles too', (tester) async {
      when(() => repo.setPdfFlag(any(), any(), any()))
          .thenAnswer((_) async {});

      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: PDFList()), vm);

      await tester.tap(find.byKey(const Key('pdf_downloadable_a')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.setPdfFlag('a', 'is_downloadable', false)).called(1);
      expect(vm.pdfList.firstWhere((p) => p.docId == 'a').isDownloadable,
          isFalse);
    });
  });

  group('createPdf keeps the collection clean', () {
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('uploads against the new document id', () async {
      when(() => repo.addPdf(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadPdf(any(), any())).thenAnswer((_) async {});

      final vm = PdfViewModel(pdfRepo: repo);
      final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
      expect(await vm.createPdf(_pdf('', 'NOTES-09', 'Sheet'), bytes), isTrue);

      // Keyed by document id, not PDF code — two documents sharing a code
      // used to overwrite each other's file in storage.
      verify(() => repo.uploadPdf(bytes, 'new-id')).called(1);
    });

    testWidgets('a failed upload takes the empty document with it',
        (tester) async {
      when(() => repo.addPdf(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadPdf(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deletePdf(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = PdfViewModel(pdfRepo: repo);
      expect(
          await vm.createPdf(
              _pdf('', 'NOTES-09', 'Sheet'), Uint8List.fromList([1])),
          isFalse);

      verify(() => repo.deletePdf('new-id')).called(1);
    });
  });

  group('updatePdf', () {
    test('leaves the existing file alone when none was picked', () async {
      when(() => repo.updatePdf(any(), any())).thenAnswer((_) async {});

      final vm = PdfViewModel(pdfRepo: repo);
      expect(await vm.updatePdf(_pdf('a', 'NOTES-01', 'Sheet'), 'a'), isTrue);

      verifyNever(() => repo.uploadPdf(any(), any()));
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddPdf(), vm);

      await tester.tap(find.byKey(const Key('pdf_save_button')));
      await tester.pump();

      expect(find.text('Give the PDF a code'), findsOneWidget);
      expect(find.text('Give the PDF a title'), findsOneWidget);
      expect(find.text('Choose a PDF file to upload'), findsOneWidget);
      expect(find.text('Choose whether it is free or paid'), findsOneWidget);
      verifyNever(() => repo.addPdf(any()));
    });

    testWidgets('editing does not demand a new file', (tester) async {
      when(() => repo.updatePdf(any(), any())).thenAnswer((_) async {});
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditPdf(pdfData: _fixture().first), vm);

      await tester.tap(find.byKey(const Key('pdf_save_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a PDF file to upload'), findsNothing);
      verify(() => repo.updatePdf(any(), 'a')).called(1);
      verifyNever(() => repo.uploadPdf(any(), any()));
    });

    testWidgets('the edit form carries the existing flags', (tester) async {
      final vm = PdfViewModel(pdfRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditPdf(pdfData: _fixture()[1]), vm);

      final List<Switch> switches =
          tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(2));
      expect(switches[0].value, isFalse, reason: 'not downloadable');
      expect(switches[1].value, isTrue, reason: 'locked');
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: PDFList()), PdfViewModel(pdfRepo: repo));

    final Iterable<SelectableLabel> labels =
        tester.widgetList<SelectableLabel>(find.byType(SelectableLabel));
    expect(labels, isNotEmpty);
    for (final SelectableLabel label in labels) {
      expect(label.data.trim(), isNotEmpty);
    }
    // Drag-select and Ctrl/Cmd-C come from the SelectableText each builds.
    expect(
      find.descendant(
        of: find.byType(SelectableLabel),
        matching: find.byType(SelectableText),
      ),
      findsWidgets,
    );
  });

  });
}
