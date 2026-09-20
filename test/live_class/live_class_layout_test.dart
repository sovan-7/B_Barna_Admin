import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/add_live_class.dart';
import 'package:bbarna/live_class/screen/edit_live_class.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

class LiveClassModelFake extends Fake implements LiveClassModel {}

LiveClassModel _model(String id, String title, DateTime start,
        {String teacher = "Ravi Kumar"}) =>
    LiveClassModel(
      docId: id,
      title: title,
      description:
          "A long description that has to wrap and then be clamped, because "
          "admins paste whole lesson plans into this field.",
      youtubeLink: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      teacherName: teacher,
      startDateTime: start,
      endDateTime: start.add(const Duration(minutes: 90)),
    );

/// One of each bucket, plus the awkward content that breaks layouts: a very
/// long title and a very long teacher name.
List<LiveClassModel> _fixture() {
  final DateTime now = DateTime.now();
  return [
    _model('live', "Trigonometry — Chapter 4 revision",
        now.subtract(const Duration(minutes: 20))),
    _model('up1', "Organic Chemistry: nomenclature drill",
        now.add(const Duration(days: 1))),
    _model(
        'up2',
        "An extremely long class title that will certainly not fit on a "
            "single line of any card at any breakpoint whatsoever",
        now.add(const Duration(days: 3)),
        teacher: "Dr. Subramanian Venkataraghavan Iyer"),
    _model('past', "Algebra recap", now.subtract(const Duration(days: 4))),
  ];
}

/// Widths worth checking: a wide desktop, a laptop, the point the toolbar
/// stacks, and a phone.
const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

Future<void> _pump(WidgetTester tester, Size size, Widget home,
    LiveClassViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<LiveClassViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  // pump, not pumpAndSettle: the LIVE badge's dot pulses forever, so there
  // is no settled state to wait for whenever a live class is on screen.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => registerFallbackValue(LiveClassModelFake()));

  late MockLiveClassRepo repo;

  setUp(() {
    repo = MockLiveClassRepo();
    when(() => repo.getLiveClassList()).thenAnswer((_) async => _fixture());
    when(() => repo.getTeachers()).thenAnswer((_) async => const [
          LiveClassTeacher(id: 'anita', name: 'Anita Desai'),
          LiveClassTeacher(id: 'ravi', name: 'Ravi Kumar'),
        ]);
    when(() => repo.getSubjects()).thenAnswer((_) async => const [
          LiveClassSubject(code: 'MECH', name: 'Mechanics'),
          LiveClassSubject(code: 'ORG', name: 'Organic Chemistry'),
        ]);
  });

  for (final Size size in _sizes) {
    testWidgets('list lays out at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, size, const Scaffold(body: LiveClassList()), vm);

      expect(tester.takeException(), isNull);
      expect(find.text('Live Classes'), findsOneWidget);
      // Upcoming is the default tab and the fixture puts two classes in it.
      expect(find.text('Organic Chemistry: nomenclature drill'), findsOneWidget);
    });

    testWidgets('add form lays out at ${size.width.toInt()}', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, size, const AddLiveClass(), vm);

      expect(tester.takeException(), isNull);
      expect(find.text('Schedule a class'), findsOneWidget);
      expect(find.byKey(const Key('live_class_save_button')), findsOneWidget);
    });

    testWidgets('edit form lays out at ${size.width.toInt()}', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(
        tester,
        size,
        EditLiveClass(liveClassData: _fixture().first),
        vm,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Edit class'), findsOneWidget);
    });
  }

  group('classes the app cannot read', () {
    /// A class in the panel's original shape: no `startTime`, so the app
    /// reads 0 and files it under Past however far ahead it is scheduled.
    LiveClassModel legacy() {
      final LiveClassModel model = _model('legacy', "Old class",
          DateTime.now().add(const Duration(days: 2)));
      model.needsAppSync = true;
      return model;
    }

    testWidgets('a healthy list says nothing', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: LiveClassList()), vm);

      expect(find.byKey(const Key('live_class_app_sync_banner')), findsNothing);
    });

    testWidgets('an out-of-date class is called out', (tester) async {
      when(() => repo.getLiveClassList())
          .thenAnswer((_) async => [..._fixture(), legacy()]);

      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: LiveClassList()), vm);

      // The only previous symptom was the class sitting in the wrong list
      // on a device the admin was not holding.
      expect(
          find.text('1 class is not showing correctly in the app'),
          findsOneWidget);
    });

    testWidgets('updating them rewrites each one and clears the banner',
        (tester) async {
      when(() => repo.getLiveClassList())
          .thenAnswer((_) async => [legacy(), legacy()]);
      when(() => repo.migrateToAppSchema(any())).thenAnswer((_) async {});

      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: LiveClassList()), vm);

      expect(find.text('2 classes are not showing correctly in the app'),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('live_class_app_sync_button')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repo.migrateToAppSchema(any())).called(2);
      expect(find.byKey(const Key('live_class_app_sync_banner')), findsNothing);
      // No refetch — the rows already on screen are updated in place.
      verify(() => repo.getLiveClassList()).called(1);
    });

    testWidgets('one failure does not strand the rest', (tester) async {
      final LiveClassModel bad = legacy()..docId = 'bad';
      when(() => repo.getLiveClassList())
          .thenAnswer((_) async => [bad, legacy()]);
      when(() => repo.migrateToAppSchema(any())).thenAnswer((invocation) async {
        final LiveClassModel model =
            invocation.positionalArguments.first as LiveClassModel;
        if (model.docId == 'bad') throw Exception('permission denied');
      });

      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: LiveClassList()), vm);

      await tester.tap(find.byKey(const Key('live_class_app_sync_button')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The good one landed; the banner stays up for the one that did not.
      expect(vm.classesNeedingAppSync, hasLength(1));
      expect(find.text('1 class is not showing correctly in the app'),
          findsOneWidget);
    });
  });

  testWidgets('each tab renders its own bucket', (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: LiveClassList()), vm);

    await tester.tap(find.byKey(const Key('live_class_tab_live')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Trigonometry — Chapter 4 revision'), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_class_tab_past')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Algebra recap'), findsOneWidget);
  });

  testWidgets('an empty bucket offers a way out', (tester) async {
    when(() => repo.getLiveClassList()).thenAnswer((_) async => []);
    final vm = LiveClassViewModel(liveClassRepo: repo);
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: LiveClassList()), vm);

    expect(tester.takeException(), isNull);
    expect(find.text('Nothing scheduled yet'), findsOneWidget);
    expect(find.text('Schedule a class'), findsOneWidget);

    // Past is a filing bucket, not something you can act on — no CTA there.
    await tester.tap(find.byKey(const Key('live_class_tab_past')));
    await tester.pump();
    expect(find.text('No finished classes'), findsOneWidget);
    expect(find.text('Schedule a class'), findsNothing);
  });

  testWidgets('an invalid submit marks the offending fields', (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    await _pump(tester, const Size(1024, 768), const AddLiveClass(), vm);

    await tester.tap(find.byKey(const Key('live_class_save_button')));
    await tester.pump();

    expect(find.text('Give the class a title'), findsOneWidget);
    expect(find.text('Choose the subject this class is for'), findsOneWidget);
    expect(find.text('Pick the class date'), findsOneWidget);
    expect(find.text('Pick a start time'), findsOneWidget);
    expect(find.text('Pick an end time'), findsOneWidget);
    verifyNever(() => repo.addLiveClass(any()));

    // Fixing one field clears just that message.
    await tester.enterText(
        find.byType(TextField).first, "Integration by parts");
    await tester.pump();
    expect(find.text('Give the class a title'), findsNothing);
    expect(find.text('Pick the class date'), findsOneWidget);
  });

  group('a class is confined to one day', () {
    testWidgets('the quick chips and duration chips fill the schedule',
        (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddLiveClass(), vm);

      // No start time yet, so a duration has nothing to measure from.
      expect(find.text('Duration — pick a start time first'), findsOneWidget);

      await tester.ensureVisible(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pump();
      expect(find.text('Duration — pick a start time first'), findsOneWidget);

      // Pick a start time through the real clock dialog's input mode.
      await _setTime(tester, 'live_class_start_time_field', const TimeOfDay(hour: 18, minute: 0));
      expect(find.text('Duration'), findsOneWidget);

      await tester.ensureVisible(find.text('1h 30m'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1h 30m'));
      await tester.pump();

      // 6:00 PM + 1h 30m, on tomorrow's date.
      final DateTime tomorrow =
          DateTime.now().add(const Duration(days: 1));
      expect(find.textContaining('7:30 PM'), findsWidgets);
      expect(
          find.textContaining(DateFormat('d MMM yyyy').format(tomorrow)),
          findsWidgets);
    });

    testWidgets('saving writes a start and end on the same date',
        (tester) async {
      when(() => repo.addLiveClass(any())).thenAnswer((_) async {});
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddLiveClass(), vm);

      await tester.enterText(find.byType(TextField).first, "Kinematics");
      await tester.ensureVisible(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pump();
      await _setTime(tester, 'live_class_start_time_field', const TimeOfDay(hour: 21, minute: 0));
      await tester.ensureVisible(find.text('1h'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1h'));
      await tester.pump();

      // Subject and teacher both come from dropdowns.
      await _pickFromDropdown(tester, 'live_class_subject_dropdown', 'Mechanics');
      await _pickFromDropdown(tester, 'live_class_teacher_dropdown', 'Ravi Kumar');

      await tester.tap(find.byKey(const Key('live_class_save_button')));
      await tester.pump();
      await tester.pump();

      final LiveClassModel saved = verify(() => repo.addLiveClass(captureAny()))
          .captured
          .single as LiveClassModel;
      expect(saved.startDateTime.year, saved.endDateTime.year);
      expect(saved.startDateTime.month, saved.endDateTime.month);
      expect(saved.startDateTime.day, saved.endDateTime.day);
      expect(saved.endDateTime.isAfter(saved.startDateTime), isTrue);
      expect(saved.startDateTime.hour, 21);
      expect(saved.endDateTime.hour, 22);

      // The app needs the ids, not just the labels: it prints the subject
      // on the class card and matches teacherId against the uid a
      // participant joined the live room under.
      expect(saved.subject, 'Mechanics');
      expect(saved.subjectCode, 'MECH');
      expect(saved.teacherName, 'Ravi Kumar');
      expect(saved.teacherId, 'ravi');
    });

    testWidgets('an end at or before the start is rejected', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddLiveClass(), vm);

      await tester.enterText(find.byType(TextField).first, "Kinematics");
      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pump();
      await _setTime(tester, 'live_class_start_time_field', const TimeOfDay(hour: 18, minute: 0));
      await _setTime(tester, 'live_class_end_time_field', const TimeOfDay(hour: 17, minute: 0));

      await tester.tap(find.byKey(const Key('live_class_save_button')));
      await tester.pump();

      expect(find.text('The end time must be after the start time'),
          findsOneWidget);
      verifyNever(() => repo.addLiveClass(any()));
    });

    testWidgets('moving the start drags the end along', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddLiveClass(), vm);

      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pump();
      await _setTime(tester, 'live_class_start_time_field', const TimeOfDay(hour: 18, minute: 0));
      await tester.ensureVisible(find.text('1h'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1h'));
      await tester.pump();
      expect(find.textContaining('7:00 PM'), findsWidgets);

      // Shift the start back an hour; the class keeps its length.
      await _setTime(tester, 'live_class_start_time_field', const TimeOfDay(hour: 17, minute: 0));
      expect(find.textContaining('6:00 PM'), findsWidgets);
      expect(find.text('1h'), findsOneWidget);
    });

    testWidgets('a legacy class that spanned midnight says so on open',
        (tester) async {
      final DateTime start = DateTime(2026, 3, 12, 23, 0);
      final LiveClassModel crossMidnight = LiveClassModel(
        docId: 'legacy',
        title: "Late revision",
        description: "d",
        youtubeLink: "l",
        teacherName: "Ravi Kumar",
        startDateTime: start,
        endDateTime: start.add(const Duration(hours: 2)),
      );

      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditLiveClass(liveClassData: crossMidnight), vm);

      expect(
          find.textContaining('used to end on a different day'), findsOneWidget);
    });
  });

  testWidgets('the teacher dropdown has no yellow error underline',
      (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    await _pump(tester, const Size(1024, 900),
        EditLiveClass(liveClassData: _fixture().first), vm);

    // DropdownButton takes `style` verbatim instead of merging it, so a
    // style inherited from above the Scaffold's Material drags WidgetsApp's
    // yellow double-underline error decoration into the menu.
    final DropdownButton<String> dropdown = tester.widget(
        find.byKey(const Key('live_class_teacher_dropdown')));
    expect(dropdown.style?.decoration, TextDecoration.none);

    for (final Element element in find.text('Ravi Kumar').evaluate()) {
      final TextStyle effective = DefaultTextStyle.of(element)
          .style
          .merge((element.widget as Text).style);
      expect(effective.decoration ?? TextDecoration.none, TextDecoration.none);
    }
  });

  // Regression: DropdownButton asserts there is exactly one item per value.
  // Two subject (or teacher) docs sharing a display name used to build one
  // DropdownMenuItem per doc, so opening a class whose subject/teacher name
  // was duplicated in Firestore crashed the whole form.
  testWidgets(
      'editing a class does not crash when two subjects share a display name',
      (tester) async {
    when(() => repo.getSubjects()).thenAnswer((_) async => const [
          LiveClassSubject(code: 'BEN1', name: 'Bengali'),
          LiveClassSubject(code: 'BEN2', name: 'Bengali'),
        ]);

    final vm = LiveClassViewModel(liveClassRepo: repo);
    await _pump(tester, const Size(1024, 900),
        EditLiveClass(liveClassData: _fixture().first), vm);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'editing a class does not crash when two teachers share a display name',
      (tester) async {
    when(() => repo.getTeachers()).thenAnswer((_) async => const [
          LiveClassTeacher(id: 'ravi1', name: 'Ravi Kumar'),
          LiveClassTeacher(id: 'ravi2', name: 'Ravi Kumar'),
        ]);

    final vm = LiveClassViewModel(liveClassRepo: repo);
    await _pump(tester, const Size(1024, 900),
        EditLiveClass(liveClassData: _fixture().first), vm);

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pickFromDropdown(
    WidgetTester tester, String key, String value) async {
  final Finder dropdown = find.byKey(Key(key));
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

/// Drives the real time picker. At these widths the form opens it in typed
/// entry mode, so the test fills the hour/minute fields directly.
Future<void> _setTime(
    WidgetTester tester, String fieldKey, TimeOfDay time) async {
  final Finder field = find.byKey(Key(fieldKey));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();

  // Scoped to the dialog: an unscoped TextField finder picks up the form's
  // own title field first, and the picker silently keeps its initial value.
  expect(find.byType(TimePickerDialog), findsOneWidget);
  final Finder fields = find.descendant(
      of: find.byType(TimePickerDialog), matching: find.byType(TextField));
  expect(fields, findsNWidgets(2));
  final int hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  await tester.enterText(fields.first, '$hour12');
  await tester.enterText(
      fields.at(1), time.minute.toString().padLeft(2, '0'));
  await tester.tap(find.text(time.period == DayPeriod.am ? 'AM' : 'PM'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
