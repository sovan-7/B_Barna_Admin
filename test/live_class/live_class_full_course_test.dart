import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/edit_live_class.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

class LiveClassModelFake extends Fake implements LiveClassModel {}

LiveClassModel _class(String id, String title, DateTime start,
        {String classType = LiveClassModel.liveClassPaid,
        DateTime? chatDeleteRequestedAt,
        DateTime? chatDeletedAt}) =>
    LiveClassModel(
      docId: id,
      title: title,
      description: '',
      youtubeLink: 'https://www.youtube.com/watch?v=abc',
      teacherName: 'Ravi Kumar',
      teacherId: 'ravi',
      teacherPhone: '9876543210',
      subject: 'Mechanics',
      subjectCode: 'MECH',
      classType: classType,
      startDateTime: start,
      endDateTime: start.add(const Duration(hours: 1)),
      chatDeleteRequestedAt: chatDeleteRequestedAt,
      chatDeletedAt: chatDeletedAt,
    );

Future<void> _signInAs(String role) async {
  SharedPreferences.setMockInitialValues(
      <String, Object>{adminIdPrefsKey: 'riya', rolePrefsKey: role});
  sharedPreferences = await SharedPreferences.getInstance();
}

Future<void> _pump(
    WidgetTester tester, Widget home, LiveClassViewModel vm) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<LiveClassViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => registerFallbackValue(LiveClassModelFake()));

  group('Full Course subjects only', () {
    test('matches "Full Course" in any casing, nothing else', () {
      expect(LiveClassRepo.isFullCourse('Full Course'), isTrue);
      expect(LiveClassRepo.isFullCourse(' full course '), isTrue);
      expect(LiveClassRepo.isFullCourse('FULL COURSE'), isTrue);
      expect(LiveClassRepo.isFullCourse('Part Course'), isFalse);
      expect(LiveClassRepo.isFullCourse('Mock Test'), isFalse);
      expect(LiveClassRepo.isFullCourse(''), isFalse);
      expect(LiveClassRepo.isFullCourse(stringDefault), isFalse);
    });
  });

  group('classType', () {
    test('a class is Paid unless marked Free, as the app defaults', () {
      final DateTime t = DateTime(2026);
      expect(
          LiveClassModel(
                  docId: 'd',
                  title: 't',
                  description: '',
                  youtubeLink: '',
                  teacherName: '',
                  startDateTime: t,
                  endDateTime: t)
              .toMap()['classType'],
          'Paid');
      final LiveClassModel free =
          _class('f', 'Free one', t, classType: LiveClassModel.liveClassFree);
      expect(free.toMap()['classType'], 'Free');
      expect(free.isFree, isTrue);
    });

    test('reading: missing or unknown is Paid, any casing of free is Free',
        () {
      expect(LiveClassModel.normalizeClassType(null), 'Paid');
      expect(LiveClassModel.normalizeClassType('Paid'), 'Paid');
      expect(LiveClassModel.normalizeClassType('something'), 'Paid');
      expect(LiveClassModel.normalizeClassType('Free'), 'Free');
      expect(LiveClassModel.normalizeClassType(' free '), 'Free');
      expect(LiveClassModel.normalizeClassType('FREE'), 'Free');
    });
  });

  group('chat state', () {
    final DateTime t = DateTime(2026, 4, 2, 18);

    test('never written by the panel, so an edit cannot wipe it', () {
      final Map<String, dynamic> map = _class('c', 'x', t,
              chatDeleteRequestedAt: t, chatDeletedAt: t)
          .toMap();
      expect(map.containsKey('chatDeleteRequestedAt'), isFalse);
      expect(map.containsKey('chatDeletedAt'), isFalse);
    });

    test('none, deleting, deleted', () {
      expect(_class('c', 'x', t).chatState, LiveClassChatState.none);
      expect(_class('c', 'x', t, chatDeleteRequestedAt: t).chatState,
          LiveClassChatState.deleting);
      expect(_class('c', 'x', t, chatDeletedAt: t).chatState,
          LiveClassChatState.deleted);
      // A newer request after an earlier delete is still pending.
      expect(
          _class('c', 'x', t,
                  chatDeletedAt: t,
                  chatDeleteRequestedAt: t.add(const Duration(hours: 1)))
              .chatState,
          LiveClassChatState.deleting);
    });
  });

  group('screens', () {
    late MockLiveClassRepo repo;
    final DateTime now = DateTime.now();
    final LiveClassModel past =
        _class('past', 'Algebra recap', now.subtract(const Duration(days: 2)));
    final LiveClassModel upcoming = _class(
        'up', 'Optics drill', now.add(const Duration(days: 1)),
        classType: LiveClassModel.liveClassFree);

    setUp(() async {
      await _signInAs(roleAdmin);
      past.chatDeleteRequestedAt = null;
      repo = MockLiveClassRepo();
      when(() => repo.getLiveClassList())
          .thenAnswer((_) async => [past, upcoming]);
      when(() => repo.getTeachers()).thenAnswer((_) async => const [
            LiveClassTeacher(
                id: 'ravi', name: 'Ravi Kumar', phoneNumber: '9876543210'),
          ]);
      when(() => repo.getSubjects()).thenAnswer((_) async =>
          const [LiveClassSubject(code: 'MECH', name: 'Mechanics')]);
      when(() => repo.updateLiveClass(any())).thenAnswer((_) async {});
      when(() => repo.requestChatDelete(any())).thenAnswer((_) async {});
    });

    testWidgets('the form saves the chosen class type', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, EditLiveClass(liveClassData: upcoming), vm);

      expect(find.text('Class type'), findsOneWidget);
      await tester.tap(find.byKey(const Key('live_class_type_paid')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('live_class_save_button')));
      await tester.pump();

      final LiveClassModel saved =
          verify(() => repo.updateLiveClass(captureAny())).captured.single;
      expect(saved.classType, LiveClassModel.liveClassPaid);
      expect(saved.toMap()['teacherPhone'], '9876543210');
    });

    testWidgets('the card shows Free / Paid', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Scaffold(body: LiveClassList()), vm);

      expect(
          find.descendant(
              of: find.byKey(const Key('live_class_type_chip_up')),
              matching: find.text('Free')),
          findsOneWidget);
      // No chat to delete before the class is over.
      expect(find.byKey(const Key('live_class_delete_chat_up')), findsNothing);
    });

    testWidgets('an admin can delete a past class\'s chat', (tester) async {
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Scaffold(body: LiveClassList()), vm);
      await tester.tap(find.byKey(const Key('live_class_tab_past')));
      await tester.pump();

      // The card's actions take taps only while the pointer is over it.
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Algebra recap')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('live_class_delete_chat_past')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete chat').last);
      await tester.pumpAndSettle();

      verify(() => repo.requestChatDelete('past')).called(1);
      expect(find.byKey(const Key('live_class_chat_deleting_past')),
          findsOneWidget);
      expect(
          find.byKey(const Key('live_class_delete_chat_past')), findsNothing);
    });

    testWidgets('a subadmin gets no Delete chat', (tester) async {
      await _signInAs(roleSubadmin);
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Scaffold(body: LiveClassList()), vm);
      await tester.tap(find.byKey(const Key('live_class_tab_past')));
      await tester.pump();

      expect(
          find.byKey(const Key('live_class_delete_chat_past')), findsNothing);
    });

    testWidgets('a deleted chat shows as such', (tester) async {
      past.chatDeletedAt = DateTime.now();
      addTearDown(() => past.chatDeletedAt = null);
      final vm = LiveClassViewModel(liveClassRepo: repo);
      await _pump(tester, const Scaffold(body: LiveClassList()), vm);
      await tester.tap(find.byKey(const Key('live_class_tab_past')));
      await tester.pump();

      expect(find.byKey(const Key('live_class_chat_deleted_past')),
          findsOneWidget);
      expect(
          find.byKey(const Key('live_class_delete_chat_past')), findsNothing);
    });
  });
}
