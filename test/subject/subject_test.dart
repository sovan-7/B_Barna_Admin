import 'dart:typed_data';

import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/repo/subject_repo.dart';
import 'package:bbarna/subject/screen/add_subject.dart';
import 'package:bbarna/subject/screen/edit_subject.dart';
import 'package:bbarna/subject/screen/subject_list.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/subject/widgets/subject_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockSubjectRepo extends Mock implements SubjectRepo {}

class MockCourseRepo extends Mock implements CourseRepo {}

class SubjectModelFake extends Fake implements SubjectModel {}

SubjectModel _subject(
  String id,
  String code,
  String name, {
  String courseName = "Physics — Class 11",
  String courseType = "Full Course",
  double price = 1000,
  double sellingPrice = 750,
  int priority = 1,
  int timeStamp = 0,
  bool willDisplay = true,
  bool isLocked = false,
  bool isPopular = false,
  String? couponCode,
  double couponDiscount = 0,
  int couponValidTill = 0,
}) {
  final SubjectModel model = SubjectModel(
      "PHY-11",
      courseType,
      courseName,
      price,
      sellingPrice,
      code,
      "A description.",
      name,
      "",
      priority,
      timeStamp,
      willDisplay,
      isLocked,
      isPopular);
  model.docId = id;
  // Set on the built model to keep the fixture call short; the form
  // passes them through the constructor.
  if (couponCode != null) {
    model.couponCode = couponCode;
    model.couponDiscount = couponDiscount;
    model.couponValidTill = couponValidTill;
  }
  return model;
}

List<SubjectModel> _fixture() => [
      _subject('a', 'MECH', 'Mechanics', timeStamp: 300),
      _subject('b', 'ORG', 'Organic Chemistry',
          courseName: "Chemistry — Class 12",
          timeStamp: 200,
          isLocked: true,
          sellingPrice: 1000),
      _subject(
          'c',
          'TRIG',
          'An extremely long subject name that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          timeStamp: 100,
          willDisplay: false,
          isPopular: true),
    ];

CourseModel _course(String code, String name) {
  final CourseModel model =
      CourseModel(code, "", name, "", 1, 0, true, false);
  model.docId = code;
  return model;
}

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockSubjectRepo repo;
late MockCourseRepo courseRepo;

Future<void> _pump(WidgetTester tester, Size size, Widget home,
    SubjectViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SubjectViewModel>.value(value: vm),
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
    registerFallbackValue(SubjectModelFake());
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = MockSubjectRepo();
    courseRepo = MockCourseRepo();
    when(() => repo.getSubjectList()).thenAnswer((_) async => _fixture());
    when(() => courseRepo.getCourseList()).thenAnswer((_) async => [
          _course('PHY-11', 'Physics — Class 11'),
          _course('CHEM-12', 'Chemistry — Class 12'),
        ]);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = SubjectViewModel(subjectRepo: repo);
        await _pump(tester, size, const Scaffold(body: SubjectList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Subjects'), findsOneWidget);
        expect(find.byType(SubjectCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = SubjectViewModel(subjectRepo: repo);
        await _pump(tester, size, const AddSubject(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a subject'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = SubjectViewModel(subjectRepo: repo);
        await _pump(
            tester, size, EditSubject(subjectData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit subject'), findsOneWidget);
      });
    }
  });

  group('the list', () {
    testWidgets('is newest first', (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);

      expect(vm.subjectList.map((s) => s.docId).toList(), ['a', 'b', 'c']);
    });

    testWidgets('search matches subject, code or course name',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);

      // By course — the old search only looked at code and name.
      await tester.enterText(find.byType(TextField).first, 'chemistry');
      await tester.pump();
      expect(find.byType(SubjectCard), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'trig');
      await tester.pump();
      expect(find.byType(SubjectCard), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(find.byType(SubjectCard), findsNWidgets(3));
    });

    testWidgets('a search survives the round trip to Add', (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);

      await tester.enterText(find.byType(TextField).first, 'chemistry');
      await tester.pump();
      expect(find.byType(SubjectCard), findsOneWidget);

      await tester.tap(find.text('NEW SUBJECT'));
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // The list refetched on the way back, and the search is still applied
      // to what came back -- it used to be cleared, and after Edit the box
      // kept its text while the list showed everything.
      verify(() => repo.getSubjectList()).called(2);
      expect(find.widgetWithText(TextField, 'chemistry'), findsOneWidget);
      expect(find.byType(SubjectCard), findsOneWidget);
    });

    testWidgets('a search is put back when the list is opened again',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);
      await tester.enterText(find.byType(TextField).first, 'trig');
      await tester.pump();

      // Leave the list entirely (another module), then come back to it.
      await _pump(tester, const Size(1440, 900), const SizedBox(), vm);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);

      expect(find.widgetWithText(TextField, 'trig'), findsOneWidget);
      expect(find.byType(SubjectCard), findsOneWidget);
    });

    testWidgets('an empty result says which kind of empty it is',
        (tester) async {
      when(() => repo.getSubjectList()).thenAnswer((_) async => []);
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: SubjectList()), vm);

      expect(find.text('No subjects yet'), findsOneWidget);
      expect(find.text('Add a subject'), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: SubjectList()), vm);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a discounted subject shows what students pay',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);

      // 750 selling against 1000 list. The card used to show only the
      // list price — the number nobody is charged.
      expect(find.text('₹750.00'), findsWidgets);
      expect(find.text('₹1000.00'), findsWidgets);
      // Was rendered "-25%", which reads as a negative discount.
      expect(find.text('25% OFF'), findsWidgets);
      expect(find.text('-25%'), findsNothing);
    });
  });

  group('the flag toggles', () {
    testWidgets('lock goes through the repo and updates in place',
        (tester) async {
      when(() => repo.setSubjectFlag(any(), any(), any()))
          .thenAnswer((_) async {});

      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);
      clearInteractions(repo);

      await tester.tap(find.byKey(const Key('subject_lock_a')));
      await tester.pump();
      await tester.pump();

      // It used to call FirebaseFirestore.instance straight from the widget
      // and then refetch the whole list to flip one boolean.
      verify(() => repo.setSubjectFlag('a', 'isLocked', true)).called(1);
      expect(vm.subjectList.firstWhere((s) => s.docId == 'a').isLocked, isTrue);
      verifyNever(() => repo.getSubjectList());
    });

    testWidgets('popular goes through the repo too', (tester) async {
      when(() => repo.setSubjectFlag(any(), any(), any()))
          .thenAnswer((_) async {});

      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), vm);
      clearInteractions(repo);

      await tester.tap(find.byKey(const Key('subject_popular_a')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.setSubjectFlag('a', 'isPopular', true)).called(1);
      expect(
          vm.subjectList.firstWhere((s) => s.docId == 'a').isPopular, isTrue);
    });
  });

  group('createSubject keeps the collection clean', () {
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('uploads against the new document id', () async {
      when(() => repo.addSubject(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadSubjectImage(any(), any()))
          .thenAnswer((_) async {});

      final vm = SubjectViewModel(subjectRepo: repo);
      final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
      expect(await vm.createSubject(_subject('', 'MECH', 'Mechanics'), bytes),
          isTrue);

      // Keyed by document id, not subject code — two subjects sharing a
      // code used to overwrite each other's image in storage.
      verify(() => repo.uploadSubjectImage(bytes, 'new-id')).called(1);
    });

    testWidgets('a failed upload takes the empty document with it',
        (tester) async {
      when(() => repo.addSubject(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadSubjectImage(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deleteSubject(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = SubjectViewModel(subjectRepo: repo);
      expect(
          await vm.createSubject(
              _subject('', 'MECH', 'Mechanics'), Uint8List.fromList([1])),
          isFalse);

      verify(() => repo.deleteSubject('new-id')).called(1);
    });
  });

  group('updateSubject', () {
    test('leaves the existing image alone when none was picked', () async {
      when(() => repo.updateSubject(any(), any())).thenAnswer((_) async {});

      final vm = SubjectViewModel(subjectRepo: repo);
      expect(
          await vm.updateSubject(_subject('a', 'MECH', 'Mechanics'), 'a'),
          isTrue);

      verifyNever(() => repo.uploadSubjectImage(any(), any()));
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddSubject(), vm);

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();

      // The old form reported one problem at a time, by snackbar only.
      expect(find.text('Choose the course this belongs to'), findsOneWidget);
      expect(find.text('Choose a course type'), findsOneWidget);
      expect(find.text('Give the subject a code'), findsOneWidget);
      expect(find.text('Give the subject a name'), findsOneWidget);
      expect(find.text('Set a display priority'), findsOneWidget);
      expect(find.text('Set a price'), findsOneWidget);
      expect(find.text('Choose a subject image'), findsOneWidget);
      verifyNever(() => repo.addSubject(any()));
    });

    testWidgets('a selling price above the price is rejected',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: _fixture().first), vm);

      final Finder priceFields = find.byType(TextField);
      // Price is the 5th field: code, name, description, priority, price,
      // selling price — ordered by the form's own layout.
      await tester.enterText(priceFields.at(4), '100');
      await tester.enterText(priceFields.at(5), '500');
      await tester.pump();

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();

      expect(find.text('Cannot be more than the price'), findsOneWidget);
      verifyNever(() => repo.updateSubject(any(), any()));
    });

    testWidgets('editing does not demand a new image', (tester) async {
      when(() => repo.updateSubject(any(), any())).thenAnswer((_) async {});
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: _fixture().first), vm);

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();
      await tester.pump();

      expect(find.text('Choose a subject image'), findsNothing);
      verify(() => repo.updateSubject(any(), 'a')).called(1);
    });

    testWidgets('a course that no longer exists stays selectable',
        (tester) async {
      when(() => courseRepo.getCourseList()).thenAnswer((_) async => []);
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: _fixture().first), vm);

      // Editing must not silently drop the course a subject already names.
      expect(find.text('Physics — Class 11'), findsWidgets);
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: SubjectList()), SubjectViewModel(subjectRepo: repo));

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

  /// Coupons live on the subject document and are written outside this
  /// panel, so until now an admin had no way to see which subjects carried
  /// one or whether a code had already lapsed.
  group('the coupon', () {
    final int now = DateTime.now().millisecondsSinceEpoch;

    Future<void> pumpWith(WidgetTester tester, SubjectModel subject) async {
      when(() => repo.getSubjectList()).thenAnswer((_) async => [subject]);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: SubjectList()), SubjectViewModel(subjectRepo: repo));
    }

    testWidgets('the code is shown, and is selectable to copy',
        (tester) async {
      await pumpWith(
        tester,
        _subject('a', 'MECH', 'Mechanics',
            couponCode: 'NEWYEAR50', couponDiscount: 100, couponValidTill: 0),
      );

      expect(find.text('NEWYEAR50'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is SelectableLabel && w.data == 'NEWYEAR50'),
        findsOneWidget,
        reason: 'a coupon code exists to be copied somewhere else',
      );
    });

    testWidgets('the saving is a rupee amount, not a percentage',
        (tester) async {
      await pumpWith(
        tester,
        _subject('a', 'MECH', 'Mechanics',
            couponCode: 'NEWYEAR50', couponDiscount: 100),
      );

      // The student app applies it as sellingPrice - couponDiscount.
      expect(find.text(' · ₹100 off'), findsOneWidget);
    });

    testWidgets('a lapsed coupon is called out rather than advertised',
        (tester) async {
      await pumpWith(
        tester,
        _subject('a', 'MECH', 'Mechanics',
            couponCode: 'OLDCODE',
            couponDiscount: 50,
            couponValidTill: now - const Duration(days: 2).inMilliseconds),
      );

      expect(find.text('OLDCODE'), findsOneWidget);
      expect(find.text(' · expired'), findsOneWidget);
    });

    testWidgets('a coupon still in date is not marked expired',
        (tester) async {
      await pumpWith(
        tester,
        _subject('a', 'MECH', 'Mechanics',
            couponCode: 'LIVECODE',
            couponDiscount: 50,
            couponValidTill: now + const Duration(days: 2).inMilliseconds),
      );

      expect(find.text('LIVECODE'), findsOneWidget);
      expect(find.text(' · expired'), findsNothing);
    });

    testWidgets('a subject with no coupon shows no chip', (tester) async {
      await pumpWith(tester, _subject('a', 'MECH', 'Mechanics'));

      expect(find.byIcon(Icons.local_offer_outlined), findsNothing);
    });

    test('saving a subject carries the coupon code, discount and expiry', () {
      final SubjectModel subject = _subject('a', 'MECH', 'Mechanics',
          couponCode: 'NEWYEAR50', couponDiscount: 100, couponValidTill: 999);

      final Map<String, dynamic> written = subject.toMap();
      expect(written['couponCode'], 'NEWYEAR50');
      expect(written['couponDiscount'], 100);
      expect(written['couponValidTill'], 999);
    });

    test('a blank coupon in the model writes the NA/-1 defaults', () {
      final SubjectModel subject = _subject('a', 'MECH', 'Mechanics');

      final Map<String, dynamic> written = subject.toMap();
      expect(written['couponCode'], stringDefault);
      expect(written['couponDiscount'], doubleDefault);
      expect(written['couponValidTill'], intDefault);
    });
  });

  group('editing the coupon in the form', () {
    testWidgets('an existing coupon prefills the code and discount fields',
        (tester) async {
      final SubjectModel withCoupon = _subject('a', 'MECH', 'Mechanics',
          couponCode: 'NEWYEAR50', couponDiscount: 100, couponValidTill: 0);
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: withCoupon), vm);

      expect(find.text('NEWYEAR50'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('a coupon code without a discount blocks submission',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: _fixture().first), vm);

      // Coupon code is the 7th TextField: code, priority, name, description,
      // price, selling price, coupon code, coupon discount -- the form's own
      // layout order.
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(6), 'SAVE10');
      await tester.pump();

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();

      expect(find.text('Set a discount for this coupon'), findsOneWidget);
      verifyNever(() => repo.updateSubject(any(), any()));
    });

    testWidgets('a coupon without a valid-till date blocks submission',
        (tester) async {
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: _fixture().first), vm);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(6), 'SAVE10');
      await tester.enterText(fields.at(7), '10');
      await tester.pump();

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();

      expect(find.text('Set how long this coupon is valid'), findsOneWidget);
      verifyNever(() => repo.updateSubject(any(), any()));
    });

    testWidgets('a quick pick in the calendar sets the valid-till date',
        (tester) async {
      when(() => repo.updateSubject(any(), any())).thenAnswer((_) async {});
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: _fixture().first), vm);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(6), 'SAVE10');
      await tester.enterText(fields.at(7), '10');
      await tester.pump();

      final Finder validTill = find.byKey(const Key('subject_coupon_valid_till'));
      await tester.ensureVisible(validTill);
      await tester.tap(validTill);
      await tester.pumpAndSettle();

      await tester.tap(find.text('2 weeks'));
      await tester.pump();
      expect(find.text('Expires in 14 days'), findsOneWidget);

      await tester.tap(find.byKey(const Key('valid_till_confirm')));
      await tester.pumpAndSettle();

      final DateTime inTwoWeeks =
          DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 14));
      expect(find.text(DateFormat('d MMM yyyy').format(inTwoWeeks)),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();
      await tester.pump();

      final SubjectModel saved =
          verify(() => repo.updateSubject(captureAny(), 'a')).captured.single
              as SubjectModel;
      expect(
          saved.couponValidTill,
          DateTime(inTwoWeeks.year, inTwoWeeks.month, inTwoWeeks.day, 23, 59,
                  59, 999)
              .millisecondsSinceEpoch);
    });

    testWidgets('an existing expiry is prefilled and saved back',
        (tester) async {
      when(() => repo.updateSubject(any(), any())).thenAnswer((_) async {});
      final DateTime inAWeek = DateTime.now().add(const Duration(days: 7));
      final int validTill = DateTime(
              inAWeek.year, inAWeek.month, inAWeek.day, 23, 59, 59, 999)
          .millisecondsSinceEpoch;
      final SubjectModel withCoupon = _subject('a', 'MECH', 'Mechanics',
          couponCode: 'NEWYEAR50',
          couponDiscount: 100,
          couponValidTill: validTill);
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: withCoupon), vm);

      expect(find.text(DateFormat('d MMM yyyy').format(inAWeek)),
          findsOneWidget);

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();
      await tester.pump();

      final SubjectModel saved =
          verify(() => repo.updateSubject(captureAny(), 'a')).captured.single
              as SubjectModel;
      expect(saved.toMap()['couponValidTill'], validTill);
    });

    testWidgets('leaving both coupon fields blank on save clears the coupon',
        (tester) async {
      when(() => repo.updateSubject(any(), any())).thenAnswer((_) async {});
      final SubjectModel withCoupon = _subject('a', 'MECH', 'Mechanics',
          couponCode: 'NEWYEAR50', couponDiscount: 100, couponValidTill: 0);
      final vm = SubjectViewModel(subjectRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditSubject(subjectData: withCoupon), vm);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(6), '');
      await tester.enterText(fields.at(7), '');
      await tester.pump();

      await tester.tap(find.byKey(const Key('subject_save_button')));
      await tester.pump();
      await tester.pump();

      final SubjectModel saved =
          verify(() => repo.updateSubject(captureAny(), 'a')).captured.single
              as SubjectModel;
      expect(saved.toMap()['couponCode'], stringDefault);
      expect(saved.toMap()['couponDiscount'], doubleDefault);
    });
  });


  });
}
