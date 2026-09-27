import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/repo/topic_repo.dart';
import 'package:bbarna/topic/screen/add_topic.dart';
import 'package:bbarna/topic/screen/edit_topic.dart';
import 'package:bbarna/topic/screen/topic_details.dart';
import 'package:bbarna/topic/screen/topic_list.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/topic/widgets/topic_card.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTopicRepo extends Mock implements TopicRepo {}

class MockCourseRepo extends Mock implements CourseRepo {}

class TopicModelFake extends Fake implements TopicModel {}

TopicModel _topic(
  String docId,
  String code,
  String name, {
  String courseName = "Physics — Class 11",
  String subjectName = "Mechanics",
  String unitName = "Laws of Motion",
  int priority = 1,
  int timeStamp = 0,
  List<String>? unitCodes,
  List<String>? videos,
  List<String>? audios,
  List<String>? pdfs,
  List<String>? quizzes,
}) {
  final TopicModel model = TopicModel(
      code,
      name,
      timeStamp,
      courseName,
      "PHY-11",
      subjectName,
      "MECH",
      unitName,
      "MECH-01",
      priority,
      unitCodes ?? ["MECH-01"]);
  model.docId = docId;
  model.videoCodeList = videos ?? [];
  model.audioCodeList = audios ?? [];
  model.pdfCodeList = pdfs ?? [];
  model.quizCodeList = quizzes ?? [];
  return model;
}

List<TopicModel> _fixture() => [
      _topic('a', 'NEWT-01', "Newton's First Law",
          timeStamp: 300, videos: ['VID-1', 'VID-2'], quizzes: ['QZ-1']),
      _topic('b', 'NEWT-02', "Newton's Second Law",
          timeStamp: 200,
          unitCodes: ["MECH-01", "MECH-02", "APP-07"],
          pdfs: ['PDF-1']),
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

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockTopicRepo repo;
late MockCourseRepo courseRepo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, TopicViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<TopicViewModel>.value(value: vm),
      ChangeNotifierProvider<CourseViewModel>(
          create: (_) => CourseViewModel(courseRepo: courseRepo)),
    ],
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue(TopicModelFake());
    registerFallbackValue(ContentKind.video);
  });

  setUp(() {
    repo = MockTopicRepo();
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
    when(() => courseRepo.getCourseList())
        .thenAnswer((_) async => [_course('PHY-11', 'Physics — Class 11')]);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = TopicViewModel(topicRepo: repo);
        await _pump(tester, size, const Scaffold(body: TopicList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Topics'), findsOneWidget);
        expect(find.byType(TopicCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = TopicViewModel(topicRepo: repo);
        await _pump(tester, size, const AddTopic(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a topic'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = TopicViewModel(topicRepo: repo);
        await _pump(tester, size, EditTopic(topicData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit topic'), findsOneWidget);
      });

      testWidgets('the content page lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = TopicViewModel(topicRepo: repo);
        await _pump(
            tester, size, TopicDetails(topicData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text("Newton's First Law"), findsOneWidget);
        // Video, Audio, PDF and Quiz each get their own section.
        expect(find.text('Video'), findsOneWidget);
        expect(find.text('Quiz'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('shows how much of the collection is loaded', (tester) async {
      when(() => repo.getTopicListLength()).thenAnswer((_) async => 320);
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: TopicList()), vm);

      expect(find.text('Showing 3 of 320'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsOneWidget);
    });

    testWidgets('load more appends the next page', (tester) async {
      when(() => repo.getTopicListLength()).thenAnswer((_) async => 5);
      when(() => repo.getNextTopicList(any())).thenAnswer((_) async => [
            _topic('d', 'NEWT-04', 'Gravitation', timeStamp: 50),
            _topic('e', 'NEWT-05', 'Friction', timeStamp: 40),
          ]);

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: TopicList()), vm);

      await tester.tap(find.byKey(const Key('paged_list_load_more')));
      await tester.pump();
      await tester.pump();

      expect(vm.topicList, hasLength(5));
      expect(vm.hasMore, isFalse);
      expect(find.byKey(const Key('paged_list_load_more')), findsNothing);
    });

    testWidgets('no load more when everything already fits', (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: TopicList()), vm);

      expect(find.text('Showing 3 of 3'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsNothing);
    });

    testWidgets('search runs server-side and clearing restores the page',
        (tester) async {
      when(() => repo.searchTopic(any()))
          .thenAnswer((_) async => [_fixture().first]);

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: TopicList()), vm);

      await tester.enterText(find.byType(TextField).first, 'newt-01');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Uppercased for the prefix match, which is how the codes are stored.
      verify(() => repo.searchTopic('NEWT-01')).called(1);
      expect(find.byType(TopicCard), findsOneWidget);
      expect(vm.hasMore, isFalse, reason: 'paging does not apply to a search');

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(TopicCard), findsNWidgets(3));
    });

    testWidgets('a failed search reports it instead of popping the page',
        (tester) async {
      when(() => repo.searchTopic(any())).thenThrow(Exception('offline'));

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: TopicList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // The old catch called Navigator.pop on failure, taking the whole
      // screen off the navigator.
      expect(find.byType(TopicList), findsOneWidget);
      // A failed search is an error with Retry, not "No matches".
      expect(find.text('Search failed'), findsOneWidget);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });

    testWidgets('an empty collection says so', (tester) async {
      when(() => repo.getFirstTopicList(any())).thenAnswer((_) async => []);
      when(() => repo.getTopicListLength()).thenAnswer((_) async => 0);

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: TopicList()), vm);

      expect(find.text('No topics yet'), findsOneWidget);
      expect(find.text('Add a topic'), findsOneWidget);
    });

    testWidgets('the row counts only the content that is there',
        (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: TopicList()), vm);

      // The old strip always printed "Video: 0  Audio: 0  Pdf: 0  Quiz: 0",
      // so an empty topic looked exactly as busy as a full one.
      expect(find.text('Video 2'), findsOneWidget);
      expect(find.text('Quiz 1'), findsOneWidget);
      expect(find.text('PDF 1'), findsOneWidget);
      expect(find.text('Audio 0'), findsNothing);
      expect(find.text('No content yet'), findsOneWidget);
    });

    testWidgets('a shared topic says how many other units it is in',
        (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: TopicList()), vm);

      expect(find.text('Also in 2 more units'), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: TopicList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('delete', () {
    test('drops the row only once the write has gone through', () async {
      when(() => repo.deleteTopic(any())).thenAnswer((_) async {});
      final vm = TopicViewModel(topicRepo: repo);
      await vm.getFirstTopicList();

      expect(await vm.deleteTopic('a'), isTrue);
      expect(vm.topicList.map((t) => t.docId), ['b', 'c']);
      expect(vm.topicLength, 2);
    });

    testWidgets('a failed delete leaves the row alone', (tester) async {
      when(() => repo.deleteTopic(any())).thenThrow(Exception('denied'));
      await tester.pumpWidget(MaterialApp(
          navigatorKey: navigatorKey, home: const Scaffold(body: SizedBox())));

      final vm = TopicViewModel(topicRepo: repo);
      await vm.getFirstTopicList();

      // The old version removed it from the list first and reported
      // success from `whenComplete`, which runs on failure too.
      expect(await vm.deleteTopic('a'), isFalse);
      expect(vm.topicList.map((t) => t.docId), ['a', 'b', 'c']);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddTopic(), vm);

      await tester.tap(find.byKey(const Key('topic_save_button')));
      await tester.pump();

      expect(find.text('Choose the course this belongs to'), findsOneWidget);
      expect(find.text('Choose the subject this belongs to'), findsOneWidget);
      expect(find.text('Choose the unit this belongs to'), findsOneWidget);
      expect(find.text('Give the topic a code'), findsOneWidget);
      expect(find.text('Give the topic a name'), findsOneWidget);
      expect(find.text('Set a display priority'), findsOneWidget);
      verifyNever(() => repo.addTopic(any()));
    });

    testWidgets('the pickers cascade', (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddTopic(), vm);

      expect(find.text('Choose a course first'), findsOneWidget);
      expect(find.text('Choose a subject first'), findsOneWidget);

      final DropdownButton<String> subjectDropdown =
          tester.widget(find.byKey(const Key('topic_subject_dropdown')));
      expect(subjectDropdown.onChanged, isNull);
      final DropdownButton<String> unitDropdown =
          tester.widget(find.byKey(const Key('topic_unit_dropdown')));
      expect(unitDropdown.onChanged, isNull);

      await tester.tap(find.byKey(const Key('topic_course_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physics — Class 11').last);
      await tester.pumpAndSettle();

      verify(() => repo.getSubjectList(courseCode: 'PHY-11')).called(1);

      await tester.tap(find.byKey(const Key('topic_subject_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mechanics').last);
      await tester.pumpAndSettle();

      verify(() => repo.getUnitList(subjectCode: 'MECH')).called(1);
    });

    testWidgets('changing the subject clears the unit under it',
        (tester) async {
      when(() => repo.getSubjectList(courseCode: any(named: 'courseCode')))
          .thenAnswer((_) async =>
              [_subject('MECH', 'Mechanics'), _subject('OPT', 'Optics')]);

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditTopic(topicData: _fixture().first), vm);

      expect(find.text('Laws of Motion'), findsWidgets);

      await tester.tap(find.byKey(const Key('topic_subject_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Optics').last);
      await tester.pumpAndSettle();

      // The old form left the previous unit selected, so a topic could be
      // saved pointing at a unit from a different subject.
      final DropdownButton<String> unitDropdown =
          tester.widget(find.byKey(const Key('topic_unit_dropdown')));
      expect(unitDropdown.value, isNull);
    });

    testWidgets('a non-numeric priority is caught instead of throwing',
        (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditTopic(topicData: _fixture().first), vm);

      // The field only accepts digits now, so an emptied priority is the
      // reachable case.
      final Finder priority = find.widgetWithText(TextField, '1');
      await tester.enterText(priority, '');
      await tester.tap(find.byKey(const Key('topic_save_button')));
      await tester.pump();

      // The old save called `int.parse` straight out of the button.
      expect(find.text('Set a display priority'), findsOneWidget);
      verifyNever(() => repo.updateTopic(any(), any()));
    });

    testWidgets('extra unit codes can be added and removed', (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddTopic(), vm);

      expect(find.byKey(const Key('topic_extra_code_remove_0')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('topic_extra_code_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topic_extra_code_add')));
      await tester.pump();
      expect(
          find.byKey(const Key('topic_extra_code_remove_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('topic_extra_code_remove_0')));
      await tester.pump();
      expect(find.byKey(const Key('topic_extra_code_remove_0')), findsNothing);
    });

    testWidgets('the unit codes saved include the primary one, de-duplicated',
        (tester) async {
      when(() => repo.updateTopic(any(), any())).thenAnswer((_) async {});
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditTopic(topicData: _fixture()[1]), vm);

      await tester.tap(find.byKey(const Key('topic_save_button')));
      await tester.pump();
      await tester.pump();

      final TopicModel saved = verify(() => repo.updateTopic(captureAny(), 'b'))
          .captured
          .single as TopicModel;
      // The old form saved only the extra fields, so a topic with no
      // extras stored an empty array and could not be found under its own
      // unit at all.
      expect(saved.unitCodeList, ['MECH-01', 'MECH-02', 'APP-07']);
    });

    test('saving a topic cannot detach its content', () {
      final TopicModel edited = _topic('a', 'NEWT-01', "Newton's First Law");
      final Map<String, dynamic> map = edited.toMap();

      // The form builds a fresh model that knows nothing about attached
      // content; writing these keys from `toMap` would send four empty
      // arrays over the top of the real ones.
      expect(map.containsKey('video_code_list'), isFalse);
      expect(map.containsKey('audio_code_list'), isFalse);
      expect(map.containsKey('pdf_code_list'), isFalse);
      expect(map.containsKey('quiz_code_list'), isFalse);
      expect(map['unitCodeList'], ['MECH-01']);
    });
  });

  group('the content page', () {
    testWidgets('says what each code points at', (tester) async {
      when(() => repo.resolveContentTitles(ContentKind.video, any()))
          .thenAnswer((_) async => {'VID-1': 'Intro to inertia'});

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          TopicDetails(topicData: _fixture().first), vm);
      await tester.pump();

      expect(find.text('Intro to inertia'), findsOneWidget);
      // VID-2 resolved to nothing, so it is a code pointing at nothing.
      expect(find.text('No video with this code'), findsOneWidget);
    });

    testWidgets('save is disabled until something changes', (tester) async {
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          TopicDetails(topicData: _fixture().first), vm);

      final ElevatedButton before =
          tester.widget(find.byKey(const Key('topic_video_save')));
      expect(before.onPressed, isNull);

      await tester.enterText(
          find.byKey(const Key('topic_video_code_0')), 'VID-9');
      await tester.pump();

      final ElevatedButton after =
          tester.widget(find.byKey(const Key('topic_video_save')));
      expect(after.onPressed, isNotNull);
    });

    testWidgets('saving writes the codes and keeps the page open',
        (tester) async {
      when(() => repo.setContentCodes(any(), any(), any()))
          .thenAnswer((_) async {});

      final TopicModel data = _fixture().first;
      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          Scaffold(body: TopicDetails(topicData: data)), vm);

      await tester.enterText(
          find.byKey(const Key('topic_video_code_1')), 'VID-1');
      await tester.pump();
      await tester.tap(find.byKey(const Key('topic_video_save')));
      await tester.pump();
      await tester.pump();

      // Duplicates are dropped — the old screen would have stored VID-1
      // twice and counted it twice on the row.
      verify(() => repo.setContentCodes('a', ContentKind.video, ['VID-1']))
          .called(1);
      // The old handler popped the navigator twice, closing the loader and
      // then the page itself.
      expect(find.byType(TopicDetails), findsOneWidget);
      expect(data.videoCodeList, ['VID-1']);
    });

    testWidgets('a rejected save keeps the changes on screen', (tester) async {
      when(() => repo.setContentCodes(any(), any(), any()))
          .thenThrow(Exception('denied'));

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          Scaffold(body: TopicDetails(topicData: _fixture().first)), vm);

      await tester.enterText(
          find.byKey(const Key('topic_video_code_0')), 'VID-9');
      await tester.pump();
      await tester.tap(find.byKey(const Key('topic_video_save')));
      await tester.pump();
      await tester.pump();

      // Still dirty, so the admin can try again — the old `.then` cleared
      // the rows and had no failure branch at all.
      final ElevatedButton save =
          tester.widget(find.byKey(const Key('topic_video_save')));
      expect(save.onPressed, isNotNull);
      expect(find.text('VID-9'), findsOneWidget);
    });

    testWidgets('empty rows are dropped on save', (tester) async {
      when(() => repo.setContentCodes(any(), any(), any()))
          .thenAnswer((_) async {});

      final vm = TopicViewModel(topicRepo: repo);
      await _pump(tester, const Size(1024, 900),
          Scaffold(body: TopicDetails(topicData: _fixture().first)), vm);

      await tester.ensureVisible(find.byKey(const Key('topic_video_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('topic_video_add')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('topic_video_save')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.setContentCodes(
          'a', ContentKind.video, ['VID-1', 'VID-2'])).called(1);
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: TopicList()), TopicViewModel(topicRepo: repo));

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
