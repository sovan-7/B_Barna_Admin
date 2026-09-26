import 'dart:typed_data';

import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/course/screen/add_course.dart';
import 'package:bbarna/course/screen/course_list.dart';
import 'package:bbarna/course/screen/edit_course.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockCourseRepo extends Mock implements CourseRepo {}

class CourseModelFake extends Fake implements CourseModel {}

CourseModel _course(
  String id,
  String code,
  String name, {
  int priority = 1,
  int timeStamp = 0,
  bool willDisplay = true,
  bool isLocked = false,
  String description = "A description that runs on a bit.",
}) {
  final CourseModel model = CourseModel(code, description, name, "", priority,
      timeStamp, willDisplay, isLocked);
  model.docId = id;
  return model;
}

List<CourseModel> _fixture() => [
      _course('a', 'PHY-11', 'Physics — Class 11', timeStamp: 300),
      _course('b', 'CHEM-12', 'Chemistry — Class 12',
          timeStamp: 200, isLocked: true),
      _course(
          'c',
          'MATH-10',
          'An extremely long course name that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          timeStamp: 100,
          willDisplay: false),
    ];

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, CourseViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<CourseViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue(CourseModelFake());
    registerFallbackValue(Uint8List(0));
  });

  late MockCourseRepo repo;

  setUp(() {
    repo = MockCourseRepo();
    when(() => repo.getCourseList()).thenAnswer((_) async => _fixture());
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = CourseViewModel(courseRepo: repo);
        await _pump(tester, size, const Scaffold(body: CourseList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Courses'), findsOneWidget);
        expect(find.byType(CourseCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = CourseViewModel(courseRepo: repo);
        await _pump(tester, size, const AddCourse(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a course'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = CourseViewModel(courseRepo: repo);
        await _pump(tester, size,
            EditCourse(courseData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit course'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('a course search does not shrink the other forms\' pickers',
        (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: CourseList()), vm);

      await tester.enterText(find.byType(TextField).first, 'chemistry');
      await tester.pump();

      // The Subject, Topic and Unit forms offer allCourses; the search
      // only narrows what the Courses list shows.
      expect(vm.courseList, hasLength(1));
      expect(vm.allCourses, hasLength(_fixture().length));
    });

    testWidgets('is newest first', (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: CourseList()), vm);

      expect(vm.courseList.map((c) => c.docId).toList(), ['a', 'b', 'c']);
    });

    testWidgets('search filters on name or code, and clears back',
        (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: CourseList()), vm);

      await tester.enterText(find.byType(TextField).first, 'chem');
      await tester.pump();
      expect(find.byType(CourseCard), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byType(CourseCard), findsNWidgets(3));
    });

    testWidgets('an empty result says which kind of empty it is',
        (tester) async {
      when(() => repo.getCourseList()).thenAnswer((_) async => []);
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: CourseList()), vm);

      expect(find.text('No courses yet'), findsOneWidget);
      expect(find.text('Add a course'), findsOneWidget);
    });

    testWidgets('a filtered-to-nothing search offers no add button',
        (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: CourseList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump();

      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Add a course'), findsNothing);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: CourseList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('the lock toggle', () {
    testWidgets('goes through the repo and updates the row in place',
        (tester) async {
      when(() => repo.setCourseLocked(any(), any())).thenAnswer((_) async {});

      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: CourseList()), vm);

      // Forget the fetch the initial mount made, so the assertion below is
      // about what the *tap* does.
      clearInteractions(repo);

      await tester.tap(find.byKey(const Key('course_lock_a')));
      await tester.pump();
      await tester.pump();

      // It used to call FirebaseFirestore.instance straight from the widget.
      verify(() => repo.setCourseLocked('a', true)).called(1);
      expect(vm.courseList.firstWhere((c) => c.docId == 'a').isLocked, isTrue);
      // And it refetched the whole list to flip one boolean.
      verifyNever(() => repo.getCourseList());
    });
  });

  group('createCourse keeps the collection clean', () {
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('uploads against the new document id', () async {
      when(() => repo.addCourse(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadCourseImage(any(), any())).thenAnswer((_) async {});

      final vm = CourseViewModel(courseRepo: repo);
      final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
      expect(await vm.createCourse(_course('', 'PHY', 'Physics'), bytes),
          isTrue);

      // Keyed by document id, not course code — two courses sharing a code
      // used to overwrite each other's image in storage.
      verify(() => repo.uploadCourseImage(bytes, 'new-id')).called(1);
    });

    testWidgets('a failed upload takes the empty document with it',
        (tester) async {
      when(() => repo.addCourse(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadCourseImage(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deleteCourse(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = CourseViewModel(courseRepo: repo);
      expect(
          await vm.createCourse(
              _course('', 'PHY', 'Physics'), Uint8List.fromList([1])),
          isFalse);

      verify(() => repo.deleteCourse('new-id')).called(1);
    });
  });

  group('updateCourse', () {
    test('leaves the existing image alone when none was picked', () async {
      when(() => repo.updateCourse(any(), any())).thenAnswer((_) async {});

      final vm = CourseViewModel(courseRepo: repo);
      expect(await vm.updateCourse(_course('a', 'PHY', 'Physics'), 'a'), isTrue);

      verifyNever(() => repo.uploadCourseImage(any(), any()));
    });

    test('uploads only when a new image was picked', () async {
      when(() => repo.updateCourse(any(), any())).thenAnswer((_) async {});
      when(() => repo.uploadCourseImage(any(), any())).thenAnswer((_) async {});

      final vm = CourseViewModel(courseRepo: repo);
      final Uint8List bytes = Uint8List.fromList([9]);
      expect(
          await vm.updateCourse(_course('a', 'PHY', 'Physics'), 'a',
              image: bytes),
          isTrue);

      verify(() => repo.uploadCourseImage(bytes, 'a')).called(1);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddCourse(), vm);

      await tester.tap(find.byKey(const Key('course_save_button')));
      await tester.pump();

      // The old form reported one problem at a time, by snackbar only.
      expect(find.text('Give the course a code'), findsOneWidget);
      expect(find.text('Give the course a name'), findsOneWidget);
      expect(find.text('Set a display priority'), findsOneWidget);
      expect(find.text('Choose a course image'), findsOneWidget);
      verifyNever(() => repo.addCourse(any()));

      await tester.enterText(find.byType(TextField).first, 'phy-11');
      await tester.pump();
      expect(find.text('Give the course a code'), findsNothing);
      expect(find.text('Give the course a name'), findsOneWidget);
    });

    testWidgets('the code field upper-cases as you type', (tester) async {
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddCourse(), vm);

      await tester.enterText(find.byType(TextField).first, 'phy-11');
      await tester.pump();

      expect(find.text('PHY-11'), findsOneWidget);
    });

    testWidgets('editing does not demand a new image', (tester) async {
      when(() => repo.updateCourse(any(), any())).thenAnswer((_) async {});
      final vm = CourseViewModel(courseRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditCourse(courseData: _fixture().first), vm);

      await tester.tap(find.byKey(const Key('course_save_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a course image'), findsNothing);
      verify(() => repo.updateCourse(any(), 'a')).called(1);
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: CourseList()), CourseViewModel(courseRepo: repo));

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
