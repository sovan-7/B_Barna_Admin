import 'dart:async';
import 'dart:typed_data';

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject_group/model/group_message.dart';
import 'package:bbarna/subject_group/repo/subject_group_repo.dart';
import 'package:bbarna/subject_group/viewModel/subject_group_view_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectGroupRepo extends Mock implements SubjectGroupRepo {}

final Uint8List _pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

GroupMessage _msg(int i) => GroupMessage(
      docId: 'm$i',
      text: 'Message $i',
      senderId: 't1',
      senderName: 'Riya Sen',
      senderRole: roleAdmin,
      subjectCode: 'WBCS01',
      createdAt: DateTime(2026, 11, 10, 9).subtract(Duration(minutes: i)),
    );

List<GroupMessage> _msgs(int count) => [for (int i = 0; i < count; i++) _msg(i)];

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // SafeNotifier asks the scheduler which phase the frame is in.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_msg(0));
    registerFallbackValue(Uint8List(0));
  });

  // The student app reads these exact names
  // (b_barna_app/lib/subjectGroup/model/group_message.dart); its tests check
  // the same cases.
  group('contract with the student app', () {
    test('field names', () {
      const GroupMessage message = GroupMessage(
        text: 'Hello',
        imageUrl: 'https://img/p.jpg',
        imageWidth: 1600,
        imageHeight: 1200,
        senderId: 't1',
        senderName: 'Riya Sen',
        senderRole: roleSubadmin,
        subjectCode: 'WBCS01',
      );
      expect(message.toMap(), {
        'text': 'Hello',
        'image_url': 'https://img/p.jpg',
        'image_width': 1600,
        'image_height': 1200,
        'sender_id': 't1',
        'sender_name': 'Riya Sen',
        'sender_role': 'subadmin',
        'subject_code': 'WBCS01',
      });
    });

    test('group id: the code, encoded', () {
      expect(groupIdFor('WBCS01'), 'WBCS01');
      expect(groupIdFor('WB/CS 01'), 'WB%2FCS%2001');
    });

    test('reads back what it wrote, plus the server time', () {
      final DateTime sent = DateTime(2026, 11, 10, 9, 5);
      final GroupMessage read = GroupMessage.fromMap('m1', {
        ..._msg(0).toMap(),
        'image_width': 1600.0, // edited by hand in the console
        'created_at': Timestamp.fromDate(sent),
      });
      expect(read.docId, 'm1');
      expect(read.text, 'Message 0');
      expect(read.imageWidth, 1600);
      expect(read.createdAt, sent);
      expect(GroupMessage.fromMap('m2', {}).createdAt, isNull);
    });
  });

  group('SubjectGroupViewModel', () {
    late MockSubjectGroupRepo repo;
    late SubjectGroupViewModel vm;
    late List<StreamController<List<GroupMessage>>> streams;

    setUp(() async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{adminIdPrefsKey: 'riya', rolePrefsKey: roleAdmin});
      sharedPreferences = await SharedPreferences.getInstance();

      repo = MockSubjectGroupRepo();
      streams = [];
      when(() => repo.watch(any(), limit: any(named: 'limit')))
          .thenAnswer((_) {
        final StreamController<List<GroupMessage>> stream =
            StreamController<List<GroupMessage>>();
        streams.add(stream);
        return stream.stream;
      });
      when(() => repo.send(any(), any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadImage(any(), any())).thenAnswer((_) async =>
          (url: 'https://img/up.jpg', width: 1600, height: 1200));
      when(() => repo.teacherName(any())).thenAnswer((_) async => 'Riya Sen');
      when(() => repo.delete(any(), any())).thenAnswer((_) async {});
      when(() => repo.deleteAll(any())).thenAnswer((_) async => 3);

      vm = SubjectGroupViewModel(subjectCode: 'WB/CS 01', repo: repo);
    });

    tearDown(() => vm.dispose());

    test('watches its own group and shows the messages', () async {
      vm.start();
      verify(() => repo.watch('WB%2FCS%2001', limit: 30)).called(1);
      expect(vm.isLoading, isTrue);

      streams.last.add(_msgs(2));
      await _settle();
      expect(vm.isLoading, isFalse);
      expect(vm.messages.map((m) => m.docId), ['m0', 'm1']);
    });

    test('a failed load with nothing shown offers Retry', () async {
      vm.start();
      streams.last.addError(StateError('permission-denied'));
      await _settle();
      expect(vm.loadError, isNotNull);

      vm.retry();
      streams.last.add([]);
      await _settle();
      expect(vm.loadError, isNull);
      expect(vm.messages, isEmpty);
    });

    test('Load older widens the window when a full page is shown', () async {
      vm.start();
      streams.last.add(_msgs(30));
      await _settle();
      expect(vm.hasOlder, isTrue);

      vm.loadOlder();
      expect(vm.isLoadingOlder, isTrue);
      verify(() => repo.watch(any(), limit: 60)).called(1);
      expect(streams.first.hasListener, isFalse);

      streams.last.add(_msgs(40));
      await _settle();
      expect(vm.isLoadingOlder, isFalse);
      expect(vm.hasOlder, isFalse);
    });

    test('text only: trimmed, no upload, signed with the teacher', () async {
      expect(await vm.send(text: '  Class at 7 pm  \n'), isTrue);

      verifyNever(() => repo.uploadImage(any(), any()));
      final GroupMessage sent =
          verify(() => repo.send('WB%2FCS%2001', captureAny())).captured.single
              as GroupMessage;
      expect(sent.text, 'Class at 7 pm');
      expect(sent.imageUrl, '');
      expect(sent.senderId, 'riya');
      expect(sent.senderName, 'Riya Sen');
      expect(sent.senderRole, roleAdmin);
      expect(sent.subjectCode, 'WB/CS 01');
      expect(vm.isSending, isFalse);
    });

    test('picture only: uploaded first, its size saved', () async {
      expect(await vm.send(text: '', image: _pngBytes), isTrue);

      verify(() => repo.uploadImage('WB/CS 01', _pngBytes)).called(1);
      final GroupMessage sent =
          verify(() => repo.send(any(), captureAny())).captured.single
              as GroupMessage;
      expect(sent.text, '');
      expect(sent.imageUrl, 'https://img/up.jpg');
      expect(sent.imageWidth, 1600);
      expect(sent.imageHeight, 1200);
    });

    test('text and picture together', () async {
      expect(await vm.send(text: 'Holiday', image: _pngBytes), isTrue);
      final GroupMessage sent =
          verify(() => repo.send(any(), captureAny())).captured.single
              as GroupMessage;
      expect(sent.text, 'Holiday');
      expect(sent.hasImage, isTrue);
    });

    test('nothing to post: nothing is written', () async {
      expect(await vm.send(text: '  \n '), isFalse);
      verifyNever(() => repo.send(any(), any()));
    });

    test('a failed upload posts nothing', () async {
      when(() => repo.uploadImage(any(), any()))
          .thenThrow(StateError('storage/unauthorized'));

      expect(await vm.send(text: 'Holiday', image: _pngBytes), isFalse);
      verifyNever(() => repo.send(any(), any()));
      expect(vm.isSending, isFalse);
    });

    test('the name is looked up once; without one it says Admin', () async {
      await vm.send(text: 'One');
      await vm.send(text: 'Two');
      verify(() => repo.teacherName('riya')).called(1);

      final SubjectGroupViewModel other =
          SubjectGroupViewModel(subjectCode: 'WBCS01', repo: repo);
      when(() => repo.teacherName(any())).thenThrow(StateError('offline'));
      await other.send(text: 'Three');
      final GroupMessage sent =
          verify(() => repo.send(any(), captureAny())).captured.last
              as GroupMessage;
      expect(sent.senderName, 'Admin');
      other.dispose();
    });

    test('a teacher posts as subadmin', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        adminIdPrefsKey: 'amit',
        rolePrefsKey: roleSubadmin,
      });
      sharedPreferences = await SharedPreferences.getInstance();

      await vm.send(text: 'Homework');
      final GroupMessage sent =
          verify(() => repo.send(any(), captureAny())).captured.single
              as GroupMessage;
      expect(sent.senderRole, roleSubadmin);
      expect(sent.senderId, 'amit');
    });

    test('delete removes the message, busy while it runs', () async {
      final Completer<void> done = Completer<void>();
      when(() => repo.delete(any(), any())).thenAnswer((_) => done.future);

      final Future<bool> result = vm.delete(_msg(3));
      expect(vm.isDeleting('m3'), isTrue);
      done.complete();
      expect(await result, isTrue);
      expect(vm.isDeleting('m3'), isFalse);
      verify(() => repo.delete('WB%2FCS%2001', any())).called(1);
    });

    test('delete all clears this group, busy while it runs', () async {
      final Completer<int> done = Completer<int>();
      when(() => repo.deleteAll(any())).thenAnswer((_) => done.future);

      final Future<bool> result = vm.deleteAll();
      expect(vm.isDeletingAll, isTrue);
      expect(await vm.deleteAll(), isFalse); // not twice at once
      done.complete(3);
      expect(await result, isTrue);
      expect(vm.isDeletingAll, isFalse);
      verify(() => repo.deleteAll('WB%2FCS%2001')).called(1);
    });

    test('a failed delete all says so', () async {
      when(() => repo.deleteAll(any())).thenThrow(StateError('offline'));
      expect(await vm.deleteAll(), isFalse);
      expect(vm.isDeletingAll, isFalse);
    });

    test('leaving the page stops watching', () async {
      final SubjectGroupViewModel leaving =
          SubjectGroupViewModel(subjectCode: 'WBCS01', repo: repo);
      leaving.start();
      final StreamController<List<GroupMessage>> stream = streams.last;
      leaving.dispose();
      expect(stream.hasListener, isFalse);
    });
  });
}
