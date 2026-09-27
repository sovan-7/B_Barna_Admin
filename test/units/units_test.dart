import 'dart:typed_data';

import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/repo/unit_repo.dart';
import 'package:bbarna/units/screen/add_unit.dart';
import 'package:bbarna/units/screen/edit_unit.dart';
import 'package:bbarna/units/screen/unit_list.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/units/widgets/unit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockUnitRepo extends Mock implements UnitRepo {}

class MockCourseRepo extends Mock implements CourseRepo {}

class UnitModelFake extends Fake implements UnitModel {}

UnitModel _unit(
  String id,
  String code,
  String name, {
  String courseName = "Physics — Class 11",
  String subjectName = "Mechanics",
  int priority = 1,
  int timeStamp = 0,
  bool willShow = true,
  bool locked = false,
  List<String>? subjectCodes,
}) {
  final UnitModel model = UnitModel(
      "PHY-11",
      courseName,
      "MECH",
      subjectName,
      locked,
      code,
      "A description.",
      name,
      "",
      priority,
      timeStamp,
      willShow,
      subjectCodes ?? ["MECH"]);
  model.id = id;
  return model;
}

List<UnitModel> _fixture() => [
      _unit('a', 'MECH-01', 'Laws of Motion', timeStamp: 300),
      _unit('b', 'MECH-02', 'Work, Energy and Power',
          timeStamp: 200, locked: true, subjectCodes: ["MECH", "ENG", "APP"]),
      _unit(
          'c',
          'MECH-03',
          'An extremely long unit name that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          timeStamp: 100,
          willShow: false),
    ];

SubjectModel _subject(String code, String name) {
  final SubjectModel model = SubjectModel("PHY-11", "Full Course",
      "Physics — Class 11", 0, 0, code, "", name, "", 1, 0, true, false, false);
  model.docId = code;
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

late MockUnitRepo repo;
late MockCourseRepo courseRepo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, UnitViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<UnitViewModel>.value(value: vm),
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
    registerFallbackValue(UnitModelFake());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = MockUnitRepo();
    courseRepo = MockCourseRepo();
    when(() => repo.getFirstUnitList(any())).thenAnswer((_) async => _fixture());
    when(() => repo.getUnitListLength()).thenAnswer((_) async => 3);
    when(() => repo.getSubjectListByCourseCode(any()))
        .thenAnswer((_) async => [_subject('MECH', 'Mechanics')]);
    when(() => courseRepo.getCourseList())
        .thenAnswer((_) async => [_course('PHY-11', 'Physics — Class 11')]);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = UnitViewModel(unitRepo: repo);
        await _pump(tester, size, const Scaffold(body: UnitList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Units'), findsOneWidget);
        expect(find.byType(UnitCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = UnitViewModel(unitRepo: repo);
        await _pump(tester, size, const AddUnit(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a unit'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = UnitViewModel(unitRepo: repo);
        await _pump(tester, size, EditUnit(unitData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit unit'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('shows how much of the collection is loaded', (tester) async {
      when(() => repo.getUnitListLength()).thenAnswer((_) async => 320);
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);

      expect(find.text('Showing 3 of 320'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsOneWidget);
    });

    testWidgets('load more appends the next page', (tester) async {
      when(() => repo.getUnitListLength()).thenAnswer((_) async => 5);
      when(() => repo.getNextUnitList(any())).thenAnswer((_) async => [
            _unit('d', 'MECH-04', 'Gravitation', timeStamp: 50),
            _unit('e', 'MECH-05', 'Fluids', timeStamp: 40),
          ]);

      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);

      await tester.tap(find.byKey(const Key('paged_list_load_more')));
      await tester.pump();
      await tester.pump();

      expect(vm.unitList, hasLength(5));
      // Everything is loaded, so there is nothing left to load.
      expect(vm.hasMore, isFalse);
      expect(find.byKey(const Key('paged_list_load_more')), findsNothing);
    });

    testWidgets('no load more when everything already fits', (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);

      expect(find.text('Showing 3 of 3'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsNothing);
    });

    testWidgets('search runs server-side and clearing restores the page',
        (tester) async {
      when(() => repo.searchUnit(any()))
          .thenAnswer((_) async => [_fixture().first]);

      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);

      await tester.enterText(find.byType(TextField).first, 'mech-01');
      // The query is debounced.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Uppercased for the prefix match, which is how the codes are stored.
      verify(() => repo.searchUnit('MECH-01')).called(1);
      expect(find.byType(UnitCard), findsOneWidget);
      expect(vm.hasMore, isFalse, reason: 'paging does not apply to a search');

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(UnitCard), findsNWidgets(3));
    });

    testWidgets('a failed search reports it instead of popping the page',
        (tester) async {
      when(() => repo.searchUnit(any())).thenThrow(Exception('offline'));

      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: UnitList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // The old catch called Navigator.pop on failure, taking the whole
      // screen off the navigator.
      expect(find.byType(UnitList), findsOneWidget);
      // A failed search is an error with Retry, not "No matches".
      expect(find.text('Search failed'), findsOneWidget);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });

    testWidgets('an empty collection says so', (tester) async {
      when(() => repo.getFirstUnitList(any())).thenAnswer((_) async => []);
      when(() => repo.getUnitListLength()).thenAnswer((_) async => 0);

      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: UnitList()), vm);

      expect(find.text('No units yet'), findsOneWidget);
      expect(find.text('Add a unit'), findsOneWidget);
    });

    testWidgets('visibility reflects the flag', (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);

      // The old row rendered `const ActiveButton()` with no argument, so
      // every unit showed the same green "ACTIVE" badge.
      expect(find.text('Visible'), findsNWidgets(2));
      expect(find.text('Hidden'), findsOneWidget);
    });

    testWidgets('a shared unit says how many other subjects it is in',
        (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);

      expect(find.text('Also in 2 more subjects'), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: UnitList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('the lock toggle', () {
    testWidgets('goes through the repo and updates in place', (tester) async {
      when(() => repo.setUnitFlag(any(), any(), any()))
          .thenAnswer((_) async {});

      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: UnitList()), vm);
      clearInteractions(repo);

      await tester.tap(find.byKey(const Key('unit_lock_a')));
      await tester.pump();
      await tester.pump();

      // It used to call FirebaseFirestore.instance straight from the widget
      // and then reload the first page, throwing away every page after it.
      verify(() => repo.setUnitFlag('a', 'lock_status', true)).called(1);
      expect(vm.unitList.firstWhere((u) => u.id == 'a').lockStatus, isTrue);
      verifyNever(() => repo.getFirstUnitList(any()));
    });
  });

  group('createUnit keeps the collection clean', () {
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('uploads against the new document id', () async {
      when(() => repo.addUnit(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadUnitImage(any(), any())).thenAnswer((_) async {});

      final vm = UnitViewModel(unitRepo: repo);
      final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
      expect(
          await vm.createUnit(_unit('', 'MECH-01', 'Laws of Motion'), bytes),
          isTrue);

      // Keyed by document id, not unit code — two units sharing a code
      // used to overwrite each other's image in storage.
      verify(() => repo.uploadUnitImage(bytes, 'new-id')).called(1);
    });

    testWidgets('a failed upload takes the empty document with it',
        (tester) async {
      when(() => repo.addUnit(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadUnitImage(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deleteUnit(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = UnitViewModel(unitRepo: repo);
      expect(
          await vm.createUnit(
              _unit('', 'MECH-01', 'Laws'), Uint8List.fromList([1])),
          isFalse);

      verify(() => repo.deleteUnit('new-id')).called(1);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddUnit(), vm);

      await tester.tap(find.byKey(const Key('unit_save_button')));
      await tester.pump();

      expect(find.text('Choose the course this belongs to'), findsOneWidget);
      expect(find.text('Choose the subject this belongs to'), findsOneWidget);
      // These used to read "Please fill topic code" / "topic name".
      expect(find.text('Give the unit a code'), findsOneWidget);
      expect(find.text('Give the unit a name'), findsOneWidget);
      expect(find.text('Set a display priority'), findsOneWidget);
      expect(find.text('Choose a unit image'), findsOneWidget);
      verifyNever(() => repo.addUnit(any()));
    });

    testWidgets('the subject picker waits for a course', (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddUnit(), vm);

      expect(find.text('Choose a course first'), findsOneWidget);

      final DropdownButton<String> subjectDropdown =
          tester.widget(find.byKey(const Key('unit_subject_dropdown')));
      expect(subjectDropdown.onChanged, isNull,
          reason: 'disabled until a course is chosen');
    });

    testWidgets('choosing a course fetches its subjects', (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddUnit(), vm);

      await tester.tap(find.byKey(const Key('unit_course_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physics — Class 11').last);
      await tester.pumpAndSettle();

      verify(() => repo.getSubjectListByCourseCode('PHY-11')).called(1);
    });

    testWidgets('extra subject codes can be added and removed',
        (tester) async {
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddUnit(), vm);

      expect(find.byKey(const Key('unit_extra_code_remove_0')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('unit_extra_code_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('unit_extra_code_add')));
      await tester.pump();
      expect(find.byKey(const Key('unit_extra_code_remove_0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('unit_extra_code_remove_0')));
      await tester.pump();
      expect(find.byKey(const Key('unit_extra_code_remove_0')), findsNothing);
    });

    testWidgets('editing does not demand a new image', (tester) async {
      when(() => repo.updateUnit(any(), any())).thenAnswer((_) async {});
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditUnit(unitData: _fixture().first), vm);

      await tester.tap(find.byKey(const Key('unit_save_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a unit image'), findsNothing);
      verify(() => repo.updateUnit(any(), 'a')).called(1);
    });

    testWidgets('extra codes are saved with the primary one, de-duplicated',
        (tester) async {
      when(() => repo.updateUnit(any(), any())).thenAnswer((_) async {});
      final vm = UnitViewModel(unitRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditUnit(unitData: _fixture()[1]), vm);

      await tester.tap(find.byKey(const Key('unit_save_button')));
      await tester.pump();
      await tester.pump();

      final UnitModel saved =
          verify(() => repo.updateUnit(captureAny(), 'b')).captured.single
              as UnitModel;
      expect(saved.subjectCodeList, ['MECH', 'ENG', 'APP']);
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: UnitList()), UnitViewModel(unitRepo: repo));

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
