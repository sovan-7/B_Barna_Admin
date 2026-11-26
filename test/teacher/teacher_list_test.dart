import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';
import 'package:bbarna/teacher/screen/teacher_list.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/teacher/widgets/teacher_access.dart';
import 'package:bbarna/teacher/widgets/teacher_card.dart';
import 'package:bbarna/teacher/widgets/teacher_roster_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockTeacherRepo extends Mock implements TeacherRepo {}

TeacherModel _teacher(
  String username,
  String name, {
  String role = roleSubadmin,
  List<String>? modules,
  String imageUrl = "",
}) =>
    TeacherModel(
      docId: username,
      name: name,
      imageUrl: imageUrl,
      username: username,
      password: "hash",
      phoneNumber: "9876543210",
      timeStamp: 0,
      moduleAccess: modules ?? const ['COURSES', 'SUBJECT'],
      role: role,
    );

List<TeacherModel> _fixture() => [
      _teacher('jane_doe', 'Jane Doe'),
      // Everything granted.
      _teacher('admin_ravi', 'Ravi Kumar',
          role: roleAdmin, modules: moduleList),
      // Nothing granted at all.
      _teacher('locked_out', 'Meera Nair', modules: const []),
      // More than the card shows before collapsing.
      _teacher('many', 'Subramanian Venkataraghavan',
          modules: const ['BANNERS', 'COURSES', 'SUBJECT', 'UNIT', 'TOPIC']),
    ];

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockTeacherRepo repo;

Future<void> _pump(
    WidgetTester tester, Size size, TeacherViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<TeacherViewModel>.value(
    value: vm,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: TeacherList()),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    repo = MockTeacherRepo();
    when(() => repo.getTeacherList()).thenAnswer((_) async => _fixture());
  });

  group('layout', () {
    // The page itself is wide enough for the table at these sizes (the
    // sidebar rail is not part of this test).
    for (final Size size in _sizes.where((s) => s.width >= 1024)) {
      testWidgets('a table at ${size.width.toInt()}', (tester) async {
        final vm = TeacherViewModel(teacherRepo: repo);
        await _pump(tester, size, vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Teachers'), findsOneWidget);
        expect(find.byType(TeacherRosterRow), findsNWidgets(4));
        expect(find.byType(TeacherCard), findsNothing);
        for (final String title in [
          'TEACHER',
          'USERNAME',
          'PHONE',
          'ROLE',
          'MODULES'
        ]) {
          expect(find.text(title), findsOneWidget);
        }
      });
    }

    for (final Size size in _sizes.where((s) => s.width < 1024)) {
      testWidgets('cards at ${size.width.toInt()}', (tester) async {
        final vm = TeacherViewModel(teacherRepo: repo);
        await _pump(tester, size, vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Teachers'), findsOneWidget);
        expect(find.byType(TeacherCard), findsNWidgets(4));
        expect(find.byType(TeacherRosterRow), findsNothing);
      });
    }
  });

  group('the table', () {
    Finder inTable(Finder matching) => find.descendant(
        of: find.byType(TeacherRosterTable), matching: matching);

    testWidgets('summarises module access as a count', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      final int all = assignableModuleList.length;
      expect(inTable(find.text('Every module')), findsOneWidget);
      expect(inTable(find.text('No module access')), findsOneWidget);
      expect(inTable(find.text('2 of $all')), findsOneWidget);
      expect(inTable(find.text('5 of $all')), findsOneWidget);
      // Nothing is listed until a row is opened.
      expect(find.byType(TeacherModuleChip), findsNothing);
    });

    testWidgets('opening a row lists its modules by their human labels',
        (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      await tester.tap(find.byKey(const Key('teacher_modules_toggle_many')));
      await tester.pump();

      expect(find.byType(TeacherModuleChip), findsNWidgets(5));
      for (final String label in [
        'Banners',
        'Courses',
        'Subjects',
        'Units',
        'Topics'
      ]) {
        expect(inTable(find.text(label)), findsOneWidget);
      }
      expect(find.text('COURSES'), findsNothing);

      await tester.tap(find.byKey(const Key('teacher_modules_toggle_many')));
      await tester.pump();
      expect(find.byType(TeacherModuleChip), findsNothing);
    });

    testWidgets('tells the two roles apart', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      expect(inTable(find.text('Admin')), findsOneWidget);
      expect(inTable(find.text('Subadmin')), findsNWidgets(3));
    });

    testWidgets('keeps the edit and delete buttons', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      expect(find.byKey(const Key('teacher_edit_jane_doe')), findsOneWidget);
      expect(find.byKey(const Key('teacher_delete_jane_doe')), findsOneWidget);
    });
  });

  group('the card', () {
    // Narrower than the table needs, and tall enough for every card.
    const Size cardsSize = Size(700, 1600);

    Finder inCards(Finder matching) =>
        find.descendant(of: find.byType(TeacherCard), matching: matching);

    testWidgets('summarises module access instead of listing all of it',
        (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, cardsSize, vm);

      // An admin with everything used to render thirteen shouting pills.
      expect(find.text('Every module'), findsOneWidget);
      // A teacher who can reach nothing is worth calling out.
      expect(find.text('No module access'), findsOneWidget);
      // Five granted, four shown.
      expect(find.text('+1 more'), findsOneWidget);
    });

    testWidgets('shows human module labels, not the stored constants',
        (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, cardsSize, vm);

      expect(inCards(find.text('Courses')), findsWidgets);
      expect(find.text('COURSES'), findsNothing);
    });

    testWidgets('tells the two roles apart', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, cardsSize, vm);

      expect(inCards(find.text('Admin')), findsOneWidget);
      expect(inCards(find.text('Subadmin')), findsWidgets);
    });
  });

  group('the list', () {
    testWidgets('search filters by name or username', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      await tester.enterText(find.byType(TextField).first, 'ravi');
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'locked_out');
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsNWidgets(4));
    });

    testWidgets('the role filter narrows the rows', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      await tester.tap(find.byKey(const Key('teacher_role_filter_admin')));
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsOneWidget);
      expect(find.byKey(const ValueKey('admin_ravi')), findsOneWidget);

      await tester.tap(find.byKey(const Key('teacher_role_filter_subadmin')));
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsNWidgets(3));

      // Together with the search.
      await tester.enterText(find.byType(TextField).first, 'meera');
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsOneWidget);

      await tester.tap(find.byKey(const Key('teacher_role_filter_all')));
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byType(TeacherRosterRow), findsNWidgets(4));
    });

    testWidgets('a filter that matches nobody says so', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      await tester.enterText(find.byType(TextField).first, 'jane');
      await tester.tap(find.byKey(const Key('teacher_role_filter_admin')));
      await tester.pump();

      expect(find.text('No matches'), findsOneWidget);
      expect(
          find.text('No teacher matches that search or role.'), findsOneWidget);
      expect(find.text('Add a teacher'), findsNothing);
    });

    testWidgets('the stats strip counts every teacher', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1440, 900), vm);

      Finder stat(String key, String value) =>
          find.descendant(of: find.byKey(Key(key)), matching: find.text(value));

      expect(stat('teacher_stat_total', '4'), findsOneWidget);
      expect(stat('teacher_stat_admins', '1'), findsOneWidget);
      expect(stat('teacher_stat_subadmins', '3'), findsOneWidget);

      // Filtering the rows leaves the totals alone.
      await tester.tap(find.byKey(const Key('teacher_role_filter_admin')));
      await tester.pump();
      expect(stat('teacher_stat_total', '4'), findsOneWidget);
    });

    testWidgets('an empty list offers a way to fill it', (tester) async {
      when(() => repo.getTeacherList()).thenAnswer((_) async => []);
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1024, 768), vm);

      expect(find.text('No teachers yet'), findsOneWidget);
      expect(find.text('Add a teacher'), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1024, 768), vm);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed fetch is reported, not thrown', (tester) async {
      // The old getTeacherList had no catch at all, so a failure threw out
      // of an unawaited call and left the loader dialog up for good.
      when(() => repo.getTeacherList()).thenThrow(Exception('offline'));

      final vm = TeacherViewModel(teacherRepo: repo);
      await _pump(tester, const Size(1024, 768), vm);

      expect(tester.takeException(), isNull);
      expect(vm.isLoading, isFalse);
      // An error with Retry, not the empty state.
      expect(find.text("Couldn't load teachers"), findsOneWidget);
      expect(find.text('No teachers yet'), findsNothing);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });
  });

  group('delete', () {
    test('removes the teacher from both lists', () async {
      when(() => repo.deleteTeacher(any())).thenAnswer((_) async {});

      final vm = TeacherViewModel(teacherRepo: repo);
      await vm.getTeacherList();

      expect(await vm.deleteTeacher('jane_doe'), isTrue);

      expect(
          vm.teacherList.map((t) => t.username), isNot(contains('jane_doe')));
      // The old delete left copyTeacherList holding the deleted teacher, so
      // clearing the search brought them back.
      expect(vm.copyTeacherList.map((t) => t.username),
          isNot(contains('jane_doe')));
    });

    testWidgets('a failed delete reports false and keeps the row',
        (tester) async {
      // "Teacher deleted successfully" used to be announced from a
      // whenComplete, which runs whether the delete succeeded or threw.
      // The failure path shows a snackbar, so it needs a pumped app.
      when(() => repo.deleteTeacher(any())).thenThrow(Exception('denied'));
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));

      final vm = TeacherViewModel(teacherRepo: repo);
      await vm.getTeacherList();

      expect(await vm.deleteTeacher('jane_doe'), isFalse);
      expect(vm.teacherList.map((t) => t.username), contains('jane_doe'));
    });

    // The name and the code are what an admin pastes elsewhere -- into a
    // search box, a spreadsheet, another module's form -- so they render as
    // SelectableLabel rather than plain Text.
    testWidgets('names and codes in the list are selectable', (tester) async {
      await _pump(
          tester, const Size(1440, 900), TeacherViewModel(teacherRepo: repo));

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
