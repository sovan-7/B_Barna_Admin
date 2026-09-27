import 'dart:typed_data';

import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/repo/audio_repo.dart';
import 'package:bbarna/documents/audio/screen/add_audio.dart';
import 'package:bbarna/documents/audio/screen/audio_list.dart';
import 'package:bbarna/documents/audio/screen/edit_audio.dart';
import 'package:bbarna/documents/audio/viewModel/audio_view_model.dart';
import 'package:bbarna/documents/audio/widgets/audio_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAudioRepo extends Mock implements AudioRepo {}

class AudioModelFake extends Fake implements AudioModel {}

AudioModel _audio(
  String id,
  String code,
  String title, {
  String link = "https://example.com/a.mp3",
  String type = "FREE",
  int timeStamp = 0,
}) {
  final AudioModel model = AudioModel(
      code, "A description that runs on a bit.", title, link, type, timeStamp);
  model.docId = id;
  return model;
}

List<AudioModel> _fixture() => [
      _audio('a', 'LECTURE-01', 'Kinematics lecture', timeStamp: 300),
      _audio('b', 'LECTURE-02', 'Newton\'s Laws lecture',
          type: "PAID", timeStamp: 200),
      _audio(
          'c',
          'LECTURE-03',
          'An extremely long audio title that will certainly not fit on one '
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

late MockAudioRepo repo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, AudioViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<AudioViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue(AudioModelFake());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = MockAudioRepo();
    when(() => repo.getFirstAudioList(any()))
        .thenAnswer((_) async => _fixture());
    when(() => repo.getAudioListLength()).thenAnswer((_) async => 3);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = AudioViewModel(audioRepo: repo);
        await _pump(tester, size, const Scaffold(body: AudioList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Audio'), findsOneWidget);
        expect(find.byType(AudioCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = AudioViewModel(audioRepo: repo);
        await _pump(tester, size, const AddAudio(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a clip'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = AudioViewModel(audioRepo: repo);
        await _pump(tester, size, EditAudio(audioData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit audio'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('says how much of the collection is loaded', (tester) async {
      when(() => repo.getAudioListLength()).thenAnswer((_) async => 90);
      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: AudioList()), vm);

      expect(find.text('Showing 3 of 90'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsOneWidget);
    });

    testWidgets('a clip with no file says so', (tester) async {
      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: AudioList()), vm);

      expect(find.text('No file uploaded'), findsOneWidget);
      expect(find.text('Play the file'), findsNWidgets(2));
    });

    testWidgets('search runs server-side, uppercased', (tester) async {
      when(() => repo.searchAudio(any()))
          .thenAnswer((_) async => [_fixture().first]);

      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: AudioList()), vm);

      await tester.enterText(find.byType(TextField).first, 'lecture-01');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      verify(() => repo.searchAudio('LECTURE-01')).called(1);
      expect(find.byType(AudioCard), findsOneWidget);
    });

    testWidgets('a failed search reports it instead of popping the page',
        (tester) async {
      when(() => repo.searchAudio(any())).thenThrow(Exception('offline'));

      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: AudioList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(AudioList), findsOneWidget);
      // A failed search is an error with Retry, not "No matches".
      expect(find.text('Search failed'), findsOneWidget);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: AudioList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('createAudio keeps the collection clean', () {
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('uploads against the new document id', () async {
      when(() => repo.addAudio(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadAudio(any(), any())).thenAnswer((_) async {});

      final vm = AudioViewModel(audioRepo: repo);
      final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
      expect(await vm.createAudio(_audio('', 'LECTURE-09', 'Clip'), bytes),
          isTrue);

      // Keyed by document id, not audio code — two clips sharing a code
      // used to overwrite each other's file in storage.
      verify(() => repo.uploadAudio(bytes, 'new-id')).called(1);
    });

    testWidgets('a failed upload takes the empty document with it',
        (tester) async {
      when(() => repo.addAudio(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadAudio(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deleteAudio(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = AudioViewModel(audioRepo: repo);
      expect(
          await vm.createAudio(
              _audio('', 'LECTURE-09', 'Clip'), Uint8List.fromList([1])),
          isFalse);

      verify(() => repo.deleteAudio('new-id')).called(1);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddAudio(), vm);

      await tester.tap(find.byKey(const Key('audio_save_button')));
      await tester.pump();

      expect(find.text('Give the clip a code'), findsOneWidget);
      expect(find.text('Give the clip a title'), findsOneWidget);
      expect(find.text('Choose an audio file to upload'), findsOneWidget);
      expect(find.text('Choose whether it is free or paid'), findsOneWidget);
      verifyNever(() => repo.addAudio(any()));
    });

    testWidgets('editing does not demand a new file', (tester) async {
      when(() => repo.updateAudio(any(), any())).thenAnswer((_) async {});
      final vm = AudioViewModel(audioRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditAudio(audioData: _fixture().first), vm);

      await tester.tap(find.byKey(const Key('audio_save_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose an audio file to upload'), findsNothing);
      verify(() => repo.updateAudio(any(), 'a')).called(1);
      verifyNever(() => repo.uploadAudio(any(), any()));
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: AudioList()), AudioViewModel(audioRepo: repo));

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
