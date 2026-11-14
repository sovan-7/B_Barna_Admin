import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/edit_live_class.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The student app marks as teacher whoever logs in with the class's
// `teacherPhone`. A class only stores a copy of that number, so saving it
// must take the number the Teacher module has now.

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

class LiveClassModelFake extends Fake implements LiveClassModel {}

const List<LiveClassTeacher> _teachers = [
  LiveClassTeacher(id: 'ravi', name: 'Ravi Kumar', phoneNumber: '9123456780'),
  LiveClassTeacher(id: 'asha', name: 'Asha Das', phoneNumber: '9000000001'),
];

LiveClassModel _class(
        {required String teacherId, required String teacherPhone}) =>
    LiveClassModel(
      docId: 'c1',
      title: 'Optics drill',
      description: '',
      youtubeLink: 'https://www.youtube.com/watch?v=abc',
      teacherName: 'Ravi Kumar',
      teacherId: teacherId,
      teacherPhone: teacherPhone,
      subject: 'Mechanics',
      subjectCode: 'MECH',
      startDateTime: DateTime.now().add(const Duration(days: 1)),
      endDateTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
    );

Future<void> _pumpEdit(WidgetTester tester, LiveClassModel liveClass,
    LiveClassViewModel vm) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<LiveClassViewModel>.value(
    value: vm,
    child: MaterialApp(
        navigatorKey: navigatorKey,
        home: EditLiveClass(liveClassData: liveClass)),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => registerFallbackValue(LiveClassModelFake()));

  late MockLiveClassRepo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{adminIdPrefsKey: 'riya', rolePrefsKey: roleAdmin});
    sharedPreferences = await SharedPreferences.getInstance();
    repo = MockLiveClassRepo();
    when(() => repo.getLiveClassList()).thenAnswer((_) async => []);
    when(() => repo.getTeachers()).thenAnswer((_) async => _teachers);
    when(() => repo.getSubjects()).thenAnswer((_) async =>
        const [LiveClassSubject(code: 'MECH', name: 'Mechanics')]);
    when(() => repo.updateLiveClass(any())).thenAnswer((_) async {});
  });

  group('teacherFor', () {
    late LiveClassViewModel vm;

    setUp(() async {
      vm = LiveClassViewModel(liveClassRepo: repo);
      await vm.getTeachers();
    });

    test('matches by id first', () {
      expect(vm.teacherFor(id: 'asha', name: 'Ravi Kumar')?.phoneNumber,
          '9000000001');
    });

    test('falls back to the exact name when there is no id', () {
      expect(vm.teacherFor(id: '', name: ' Ravi Kumar ')?.id, 'ravi');
      expect(vm.teacherFor(id: stringDefault, name: 'Ravi Kumar')?.id, 'ravi');
    });

    test('falls back to the name when the id is unknown', () {
      expect(vm.teacherFor(id: 'gone', name: 'Asha Das')?.id, 'asha');
    });

    test('null when nothing matches', () {
      expect(vm.teacherFor(id: 'gone', name: 'Nobody'), isNull);
      expect(vm.teacherFor(id: '', name: ''), isNull);
    });

    test('null before the teachers have loaded', () {
      expect(
          LiveClassViewModel(liveClassRepo: repo)
              .teacherFor(id: 'ravi', name: 'Ravi Kumar'),
          isNull);
    });
  });

  group('saving a class', () {
    Future<LiveClassModel> saveUnchanged(
        WidgetTester tester, LiveClassModel liveClass) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pumpEdit(tester, liveClass, vm);
      await tester.tap(find.byKey(const Key('live_class_save_button')));
      await tester.pump();
      return verify(() => repo.updateLiveClass(captureAny())).captured.single
          as LiveClassModel;
    }

    testWidgets('fills in the phone a class saved without one is missing',
        (tester) async {
      final saved = await saveUnchanged(
          tester, _class(teacherId: 'ravi', teacherPhone: ''));
      expect(saved.toMap()['teacherPhone'], '9123456780');
    });

    testWidgets('replaces a number the teacher no longer has',
        (tester) async {
      final saved = await saveUnchanged(
          tester, _class(teacherId: 'ravi', teacherPhone: '9876543210'));
      expect(saved.toMap()['teacherPhone'], '9123456780');
    });

    testWidgets('a class with only the teacher\'s name gets the id and phone',
        (tester) async {
      final saved =
          await saveUnchanged(tester, _class(teacherId: '', teacherPhone: ''));
      expect(saved.toMap()['teacherId'], 'ravi');
      expect(saved.toMap()['teacherPhone'], '9123456780');
    });

    testWidgets('keeps the stored values when the teacher is not found',
        (tester) async {
      when(() => repo.getTeachers()).thenAnswer((_) async => const [
            LiveClassTeacher(id: 'asha', name: 'Asha Das'),
          ]);
      final saved = await saveUnchanged(
          tester, _class(teacherId: 'ravi', teacherPhone: '9876543210'));
      expect(saved.toMap()['teacherId'], 'ravi');
      expect(saved.toMap()['teacherPhone'], '9876543210');
    });
  });
}
