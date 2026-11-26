import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_agenda.dart';
import 'package:bbarna/live_class/widgets/live_class_agenda_view.dart';
import 'package:bbarna/live_class/widgets/live_class_card.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

LiveClassModel _model(
  String id,
  DateTime start, {
  Duration length = const Duration(hours: 1),
  String link = "https://www.youtube.com/watch?v=abc",
  String pdfLink = "",
  DateTime? chatDeletedAt,
}) =>
    LiveClassModel(
      docId: id,
      title: "Class $id",
      description: "",
      youtubeLink: link,
      teacherName: "Ravi Kumar",
      subjectNames: const ['Mechanics'],
      subjectCodes: const ['MECH'],
      startDateTime: start,
      endDateTime: start.add(length),
      pdfLink: pdfLink,
      chatDeletedAt: chatDeletedAt,
    );

/// [days] after today's date at [hour]:00 — never near midnight, so the
/// day a class lands on does not depend on when the test runs.
DateTime _at(int days, int hour) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour);
}

Future<void> _signInAs(String role) async {
  SharedPreferences.setMockInitialValues(
      <String, Object>{adminIdPrefsKey: 'riya', rolePrefsKey: role});
  sharedPreferences = await SharedPreferences.getInstance();
}

Future<void> _pump(
    WidgetTester tester, Size size, LiveClassViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<LiveClassViewModel>.value(
    value: vm,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: LiveClassList()),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('groupByDay', () {
    test('groups by start date and keeps the order given', () {
      final a = _model('a', DateTime(2026, 11, 26, 10));
      final b = _model('b', DateTime(2026, 11, 26, 15));
      final c = _model('c', DateTime(2026, 11, 27, 9));

      final List<LiveClassDay> soonestFirst = groupByDay([a, b, c]);
      expect(soonestFirst.map((d) => d.day),
          [DateTime(2026, 11, 26), DateTime(2026, 11, 27)]);
      expect(soonestFirst.first.classes, [a, b]);

      // Past is most-recent-first; that order survives.
      final List<LiveClassDay> latestFirst = groupByDay([c, b, a]);
      expect(latestFirst.map((d) => d.day),
          [DateTime(2026, 11, 27), DateTime(2026, 11, 26)]);
      expect(latestFirst.last.classes, [b, a]);
    });

    test('an empty list has no days', () {
      expect(groupByDay(const []), isEmpty);
    });
  });

  group('dayHeading', () {
    // Late in the evening, where an off-by-one would show first.
    final DateTime now = DateTime(2026, 11, 26, 23, 30);

    test('names today, tomorrow and yesterday', () {
      expect(LiveClassFormat.dayHeading(DateTime(2026, 11, 26), now: now),
          "Today · Thu 26 Nov");
      expect(LiveClassFormat.dayHeading(DateTime(2026, 11, 27), now: now),
          "Tomorrow · Fri 27 Nov");
      expect(LiveClassFormat.dayHeading(DateTime(2026, 11, 25), now: now),
          "Yesterday · Wed 25 Nov");
    });

    test('other days are just the date, with the year when it differs', () {
      expect(LiveClassFormat.dayHeading(DateTime(2026, 11, 28), now: now),
          "Sat 28 Nov");
      expect(LiveClassFormat.dayHeading(DateTime(2025, 12, 31), now: now),
          "Wed 31 Dec 2025");
    });

    test('tomorrow works across a month end', () {
      expect(
          LiveClassFormat.dayHeading(DateTime(2026, 12, 1),
              now: DateTime(2026, 11, 30, 9)),
          "Tomorrow · Tue 1 Dec");
    });
  });

  group('stats and running classes', () {
    late MockLiveClassRepo repo;
    final DateTime now = DateTime(2026, 11, 26, 12);

    setUp(() {
      repo = MockLiveClassRepo();
      when(() => repo.getLiveClassList()).thenAnswer((_) async => [
            // Finished this morning: no notes, chat still there.
            _model('morning', DateTime(2026, 11, 26, 9)),
            // Running now.
            _model('noon', DateTime(2026, 11, 26, 11, 30)),
            // Later today.
            _model('evening', DateTime(2026, 11, 26, 18)),
            // Within the week.
            _model('soon', DateTime(2026, 12, 2, 10)),
            // Past the week.
            _model('later', DateTime(2026, 12, 4, 10)),
            // Finished, with notes and the chat cleared.
            _model('done', DateTime(2026, 11, 20, 10),
                pdfLink: 'https://x/notes.pdf',
                chatDeletedAt: DateTime(2026, 11, 21)),
          ]);
    });

    test('counts every class, whatever the search', () async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await vm.getLiveClassList();
      vm.searchLiveClass(searchText: 'nothing matches this');

      final LiveClassStats stats = vm.statsAt(now);
      expect(stats.today, 3);
      expect(stats.nextWeek, 2);
      expect(stats.missingNotes, 1);
      expect(stats.chatsToClear, 1);
    });

    test('running classes are soonest-ending first', () async {
      when(() => repo.getLiveClassList()).thenAnswer((_) async => [
            _model('long', DateTime(2026, 11, 26, 11),
                length: const Duration(hours: 3)),
            _model('short', DateTime(2026, 11, 26, 11, 30)),
            _model('upcoming', DateTime(2026, 11, 26, 15)),
          ]);
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await vm.getLiveClassList();

      expect(
          vm.runningClasses(now: now).map((c) => c.docId), ['short', 'long']);
    });
  });

  group('the list', () {
    late MockLiveClassRepo repo;

    List<LiveClassModel> fixture({bool withLive = true}) => [
          if (withLive)
            _model('live', DateTime.now().subtract(const Duration(minutes: 20)),
                length: const Duration(minutes: 90)),
          _model('up1', _at(1, 10)),
          _model('up2', _at(1, 14), link: ""),
          _model('up3', _at(3, 10)),
          _model('past', _at(-4, 10)),
        ];

    setUp(() async {
      await _signInAs(roleAdmin);
      repo = MockLiveClassRepo();
      when(() => repo.getLiveClassList()).thenAnswer((_) async => fixture());
    });

    testWidgets('wide: a box per day with a row per class', (tester) async {
      await _pump(tester, const Size(1440, 900),
          LiveClassViewModel(liveClassRepo: repo));

      expect(tester.takeException(), isNull);
      expect(find.byType(LiveClassAgendaRow), findsNWidgets(3));
      expect(find.byType(LiveClassCard), findsNothing);

      final DateTime tomorrow = _at(1, 0);
      expect(find.byKey(liveClassDayKey(tomorrow)), findsOneWidget);
      expect(find.text(LiveClassFormat.dayHeading(tomorrow)), findsOneWidget);
      expect(find.text('2 classes'), findsOneWidget);
      expect(find.byKey(liveClassDayKey(_at(3, 0))), findsOneWidget);
      expect(find.text('1 class'), findsOneWidget);
    });

    testWidgets('narrow: day headings over cards', (tester) async {
      await _pump(tester, const Size(380, 1600),
          LiveClassViewModel(liveClassRepo: repo));

      expect(tester.takeException(), isNull);
      expect(find.byType(LiveClassCard), findsNWidgets(3));
      expect(find.byType(LiveClassAgendaRow), findsNothing);
      expect(find.byKey(liveClassDayKey(_at(1, 0))), findsOneWidget);
    });

    testWidgets('the Past tab lists the latest day first', (tester) async {
      when(() => repo.getLiveClassList()).thenAnswer((_) async => [
            _model('older', _at(-6, 10)),
            _model('recent', _at(-2, 10)),
          ]);
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      await tester.tap(find.byKey(const Key('live_class_tab_past')));
      await tester.pump();

      final double recentTop =
          tester.getTopLeft(find.byKey(liveClassDayKey(_at(-2, 0)))).dy;
      final double olderTop =
          tester.getTopLeft(find.byKey(liveClassDayKey(_at(-6, 0)))).dy;
      expect(recentTop, lessThan(olderTop));
    });

    testWidgets('a running class gets a banner that opens the Live tab',
        (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      final Finder banner = find.byKey(const Key('live_class_live_banner'));
      expect(banner, findsOneWidget);
      expect(find.descendant(of: banner, matching: find.text('Class live')),
          findsOneWidget);
      expect(
          find.byKey(const Key('live_class_open_stream_live')), findsOneWidget);

      await tester.tap(banner);
      await tester.pump();

      expect(vm.selectedStatus, LiveClassStatus.live);
      // The Live tab lists the class itself, so the banner steps aside.
      expect(banner, findsNothing);
      expect(find.byType(LiveClassAgendaRow), findsOneWidget);
    });

    testWidgets('no banner when nothing is running', (tester) async {
      when(() => repo.getLiveClassList())
          .thenAnswer((_) async => fixture(withLive: false));
      await _pump(tester, const Size(1440, 900),
          LiveClassViewModel(liveClassRepo: repo));

      expect(find.byKey(const Key('live_class_live_banner')), findsNothing);
    });

    testWidgets('the stats strip counts the week and the clean-up',
        (tester) async {
      await _pump(tester, const Size(1440, 900),
          LiveClassViewModel(liveClassRepo: repo));

      Finder stat(String key, String value) =>
          find.descendant(of: find.byKey(Key(key)), matching: find.text(value));

      expect(stat('live_class_stat_next_week', '3'), findsOneWidget);
      expect(stat('live_class_stat_missing_notes', '1'), findsOneWidget);
      expect(stat('live_class_stat_chats', '1'), findsOneWidget);
    });

    testWidgets('a subadmin does not get the chats tile', (tester) async {
      await _signInAs(roleSubadmin);
      await _pump(tester, const Size(1440, 900),
          LiveClassViewModel(liveClassRepo: repo));

      expect(find.byKey(const Key('live_class_stat_missing_notes')),
          findsOneWidget);
      expect(find.byKey(const Key('live_class_stat_chats')), findsNothing);
    });
  });
}
