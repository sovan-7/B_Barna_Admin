import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/repo/video_repo.dart';
import 'package:bbarna/documents/video/screen/add_video.dart';
import 'package:bbarna/documents/video/screen/edit_video.dart';
import 'package:bbarna/documents/video/screen/video_list.dart';
import 'package:bbarna/documents/video/viewModel/video_view_model.dart';
import 'package:bbarna/documents/video/widgets/video_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockVideoRepo extends Mock implements VideoRepo {}

class VideoModelFake extends Fake implements VideoModel {}

VideoModel _video(
  String id,
  String code,
  String title, {
  String link = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
  String type = "FREE",
  int timeStamp = 0,
}) {
  final VideoModel model = VideoModel(
      code, "A description that runs on a bit.", title, link, type, timeStamp);
  model.docId = id;
  return model;
}

List<VideoModel> _fixture() => [
      _video('a', 'INTRO-01', 'Introduction to Kinematics', timeStamp: 300),
      _video('b', 'INTRO-02', 'Newton\'s Laws',
          type: "PAID", timeStamp: 200),
      _video(
          'c',
          'INTRO-03',
          'An extremely long video title that will certainly not fit on one '
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

late MockVideoRepo repo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, VideoViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<VideoViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => registerFallbackValue(VideoModelFake()));

  setUp(() {
    repo = MockVideoRepo();
    when(() => repo.getFirstVideoList(any()))
        .thenAnswer((_) async => _fixture());
    when(() => repo.getVideoListLength()).thenAnswer((_) async => 3);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = VideoViewModel(videoRepo: repo);
        await _pump(tester, size, const Scaffold(body: VideoList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Videos'), findsOneWidget);
        expect(find.byType(VideoCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = VideoViewModel(videoRepo: repo);
        await _pump(tester, size, const AddVideo(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a video'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = VideoViewModel(videoRepo: repo);
        await _pump(tester, size, EditVideo(videoData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit video'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('says how much of the collection is loaded', (tester) async {
      when(() => repo.getVideoListLength()).thenAnswer((_) async => 320);
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: VideoList()), vm);

      expect(find.text('Showing 3 of 320'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsOneWidget);
    });

    testWidgets('load more appends the next page', (tester) async {
      when(() => repo.getVideoListLength()).thenAnswer((_) async => 4);
      when(() => repo.getNextVideoList(any()))
          .thenAnswer((_) async => [_video('d', 'INTRO-04', 'Momentum')]);

      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: VideoList()), vm);

      await tester.tap(find.byKey(const Key('paged_list_load_more')));
      await tester.pump();
      await tester.pump();

      expect(vm.videoList, hasLength(4));
      expect(vm.hasMore, isFalse);
    });

    testWidgets('search runs server-side, uppercased', (tester) async {
      when(() => repo.searchVideo(any()))
          .thenAnswer((_) async => [_fixture().first]);

      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: VideoList()), vm);

      await tester.enterText(find.byType(TextField).first, 'intro-01');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      verify(() => repo.searchVideo('INTRO-01')).called(1);
      expect(find.byType(VideoCard), findsOneWidget);
      expect(vm.hasMore, isFalse, reason: 'paging does not apply to a search');
    });

    testWidgets('a failed search reports it instead of popping the page',
        (tester) async {
      when(() => repo.searchVideo(any())).thenThrow(Exception('offline'));

      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: VideoList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // The old catch called Navigator.pop on failure.
      expect(find.byType(VideoList), findsOneWidget);
      // A failed search is an error with Retry, not "No matches".
      expect(find.text('Search failed'), findsOneWidget);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });

    testWidgets('a video with no link says so', (tester) async {
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: VideoList()), vm);

      expect(find.text('No link set'), findsOneWidget);
    });

    testWidgets('free and paid are told apart', (tester) async {
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: VideoList()), vm);

      expect(find.text('FREE'), findsNWidgets(2));
      expect(find.text('PAID'), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: VideoList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddVideo(), vm);

      await tester.tap(find.byKey(const Key('video_save_button')));
      await tester.pump();

      expect(find.text('Give the video a code'), findsOneWidget);
      expect(find.text('Give the video a title'), findsOneWidget);
      expect(find.text('Add the video link'), findsOneWidget);
      expect(find.text('Choose whether it is free or paid'), findsOneWidget);
      verifyNever(() => repo.addVideo(any()));
    });

    testWidgets('a link that is not a URL is rejected', (tester) async {
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddVideo(), vm);

      // Nothing validated this before, so a typo saved a row the app could
      // never play.
      await tester.enterText(find.byType(TextField).at(3), 'youtube video 3');
      await tester.tap(find.byKey(const Key('video_save_button')));
      await tester.pump();

      expect(find.text('That does not look like a full URL'), findsOneWidget);
    });

    testWidgets('a valid video saves', (tester) async {
      when(() => repo.addVideo(any())).thenAnswer((_) async => 'new-id');
      final vm = VideoViewModel(videoRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddVideo(), vm);

      await tester.enterText(find.byType(TextField).at(0), 'intro-09');
      await tester.enterText(find.byType(TextField).at(1), 'Projectiles');
      await tester.enterText(
          find.byType(TextField).at(3), 'https://youtu.be/abc');
      await tester.tap(find.byKey(const Key('video_type_free')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('video_save_button')));
      await tester.pump();
      await tester.pump();

      final VideoModel saved =
          verify(() => repo.addVideo(captureAny())).captured.single
              as VideoModel;
      expect(saved.code, 'INTRO-09', reason: 'codes are stored upper-cased');
      expect(saved.videoType, 'FREE');
      expect(saved.link, 'https://youtu.be/abc');
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: VideoList()), VideoViewModel(videoRepo: repo));

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
