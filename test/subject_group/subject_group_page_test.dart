import 'dart:async';

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/repo/subject_repo.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/subject/widgets/subject_card.dart';
import 'package:bbarna/subject_group/group_links.dart';
import 'package:bbarna/subject_group/model/group_message.dart';
import 'package:bbarna/subject_group/repo/subject_group_repo.dart';
import 'package:bbarna/subject_group/screen/subject_group_page.dart';
import 'package:bbarna/subject_group/widgets/group_message_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockSubjectGroupRepo extends Mock implements SubjectGroupRepo {}

class MockSubjectRepo extends Mock implements SubjectRepo {}

final Uint8List _png =
    Uint8List.fromList(img.encodePng(img.Image(width: 8, height: 6)));

SubjectModel _subject({String code = 'SSCGD27', String docId = 'sub-1'}) {
  return SubjectModel('SSC', 'Full Course', 'SSC', 5000, 1750, code, '',
      'SSC GD + MTS 2027 Foundation Batch', '', 1, 0, true, false, false)
    ..docId = docId;
}

GroupMessage _msg(int i, {DateTime? at, String text = ''}) => GroupMessage(
      docId: 'm$i',
      text: text.isEmpty ? 'Message $i' : text,
      senderId: 't1',
      senderName: 'Riya Sen',
      senderRole: roleAdmin,
      subjectCode: 'SSCGD27',
      createdAt: at ?? DateTime.now().subtract(Duration(minutes: i)),
    );

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

void main() {
  setUpAll(() {
    registerFallbackValue(_msg(0));
    registerFallbackValue(Uint8List(0));
  });

  late MockSubjectGroupRepo repo;
  late List<StreamController<List<GroupMessage>>> streams;

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{adminIdPrefsKey: 'riya', rolePrefsKey: roleAdmin});
    sharedPreferences = await SharedPreferences.getInstance();

    repo = MockSubjectGroupRepo();
    streams = [];
    when(() => repo.watch(any(), limit: any(named: 'limit'))).thenAnswer((_) {
      final StreamController<List<GroupMessage>> stream =
          StreamController<List<GroupMessage>>();
      streams.add(stream);
      return stream.stream;
    });
    when(() => repo.send(any(), any())).thenAnswer((_) async => 'new-id');
    when(() => repo.uploadImage(any(), any())).thenAnswer(
        (_) async => (url: 'https://img/up.jpg', width: 8, height: 6));
    when(() => repo.teacherName(any())).thenAnswer((_) async => 'Riya Sen');
    when(() => repo.delete(any(), any())).thenAnswer((_) async {});
    when(() => repo.deleteAll(any())).thenAnswer((_) async => 2);
  });

  Future<void> pumpPage(WidgetTester tester,
      {Size size = const Size(1440, 900),
      Future<Uint8List?> Function()? pickImage}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: SubjectGroupPage(
          subject: _subject(), repo: repo, pickImage: pickImage),
    ));
    await tester.pump();
  }

  Future<void> show(WidgetTester tester, List<GroupMessage> messages) async {
    streams.last.add(messages);
    await tester.pump();
    await tester.pump();
  }

  ElevatedButton sendButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byKey(const Key('group_send')));

  testWidgets('shows the subject\'s messages, newest at the bottom',
      (tester) async {
    await pumpPage(tester);
    verify(() => repo.watch('SSCGD27', limit: 30)).called(1);

    final DateTime now = DateTime.now();
    await show(tester, [
      _msg(1, at: now, text: 'Class at 7 pm https://youtu.be/abc'),
      _msg(2,
          at: now.subtract(const Duration(days: 1)), text: 'Holiday notice'),
    ]);

    expect(find.text('Group · SSC GD + MTS 2027 Foundation Batch'),
        findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.textContaining('Class at 7 pm', findRichText: true),
        findsOneWidget);
    // Newest at the bottom.
    expect(
        tester.getTopLeft(find.textContaining('Class at 7 pm',
                findRichText: true)).dy,
        greaterThan(tester.getTopLeft(
            find.textContaining('Holiday notice', findRichText: true)).dy));
  });

  testWidgets('a few messages start at the top of the panel', (tester) async {
    await pumpPage(tester);
    final DateTime now = DateTime.now();
    final DateTime noon = DateTime(now.year, now.month, now.day, 12);
    await show(tester, [
      _msg(1, at: noon),
      _msg(2, at: noon.subtract(const Duration(minutes: 1))),
    ]);

    final double subtitleBottom = tester
        .getBottomLeft(find.text(
            'Students who bought this subject see these messages in the '
            'app, in its Group tab.'))
        .dy;
    final double dateTop = tester.getTopLeft(find.text('Today')).dy;
    expect(dateTop - subtitleBottom, lessThan(80));
  });

  testWidgets('an empty group invites the first notice', (tester) async {
    await pumpPage(tester);
    await show(tester, []);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('Send works once there is something to send; the box empties',
      (tester) async {
    await pumpPage(tester);
    await show(tester, []);
    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('group_text_field')), '  Mock test on Sunday ');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('group_send')));
    await tester.pumpAndSettle();

    final GroupMessage sent =
        verify(() => repo.send('SSCGD27', captureAny())).captured.single
            as GroupMessage;
    expect(sent.text, 'Mock test on Sunday');
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('group_text_field')))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('Ctrl+Enter sends', (tester) async {
    await pumpPage(tester);
    await show(tester, []);
    await tester.enterText(
        find.byKey(const Key('group_text_field')), 'Revise Unit 4');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    verify(() => repo.send(any(), any())).called(1);
  });

  testWidgets('a failed send keeps the text to try again', (tester) async {
    when(() => repo.send(any(), any())).thenThrow(StateError('offline'));
    await pumpPage(tester);
    await show(tester, []);
    await tester.enterText(
        find.byKey(const Key('group_text_field')), 'Revise Unit 4');
    await tester.pump();

    await tester.tap(find.byKey(const Key('group_send')));
    await tester.pumpAndSettle();

    expect(find.text('Revise Unit 4'), findsOneWidget);
  });

  testWidgets('a picture alone can be sent, and can be removed first',
      (tester) async {
    await pumpPage(tester, pickImage: () async => _png);
    await show(tester, []);

    await tester.tap(find.byKey(const Key('group_add_picture')));
    await tester.pump();
    expect(find.byKey(const Key('group_remove_picture')), findsOneWidget);
    expect(find.text('Change picture'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_remove_picture')));
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('group_add_picture')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('group_send')));
    await tester.pumpAndSettle();

    verify(() => repo.uploadImage('SSCGD27', _png)).called(1);
    final GroupMessage sent =
        verify(() => repo.send(any(), captureAny())).captured.single
            as GroupMessage;
    expect(sent.imageUrl, 'https://img/up.jpg');
    expect(find.byKey(const Key('group_remove_picture')), findsNothing);
  });

  testWidgets('delete asks first, then removes the message', (tester) async {
    // Narrow window: the bin shows without hovering.
    await pumpPage(tester, size: const Size(380, 820));
    await show(tester, [_msg(1)]);

    await tester.tap(find.byKey(const Key('group_delete_m1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this message?'), findsOneWidget);
    verifyNever(() => repo.delete(any(), any()));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    verify(() => repo.delete('SSCGD27', any())).called(1);
    expect(find.text('Delete this message?'), findsNothing);
  });

  testWidgets('Delete all messages: only with messages, and asks first',
      (tester) async {
    await pumpPage(tester);
    await show(tester, []);
    expect(find.byKey(const Key('group_delete_all')), findsNothing);

    await show(tester, [_msg(1), _msg(2)]);
    expect(find.text('Delete all messages'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_delete_all')));
    await tester.pumpAndSettle();
    expect(find.text('Delete all messages in this group?'), findsOneWidget);
    verifyNever(() => repo.deleteAll(any()));

    await tester.tap(find.text('Delete all'));
    await tester.pumpAndSettle();
    verify(() => repo.deleteAll('SSCGD27')).called(1);
    expect(find.text('Delete all messages in this group?'), findsNothing);
  });

  testWidgets('Delete all messages is an icon on a narrow window',
      (tester) async {
    await pumpPage(tester, size: const Size(380, 820));
    await show(tester, [_msg(1)]);
    expect(find.byTooltip('Delete all messages'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing can be posted while the chat is being deleted',
      (tester) async {
    final Completer<int> done = Completer<int>();
    when(() => repo.deleteAll(any())).thenAnswer((_) => done.future);
    await pumpPage(tester);
    await show(tester, [_msg(1)]);
    await tester.enterText(
        find.byKey(const Key('group_text_field')), 'Revise Unit 4');
    await tester.pump();

    await tester.tap(find.byKey(const Key('group_delete_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await tester.pump();

    expect(
        tester
            .widget<TextField>(find.byKey(const Key('group_text_field')))
            .enabled,
        isFalse);
    expect(sendButton(tester).onPressed, isNull);

    done.complete(1);
    await tester.pumpAndSettle();
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('Load older widens the window', (tester) async {
    await pumpPage(tester);
    await show(tester, [for (int i = 0; i < 30; i++) _msg(i)]);

    // The message list (not the sidebar's or the text field's scrolling).
    final Finder messages = find.ancestor(
        of: find.byType(GroupMessageTile).first,
        matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(
        find.byKey(const Key('group_load_older')), 300,
        scrollable: messages.first);
    await tester.tap(find.byKey(const Key('group_load_older')));
    await tester.pump();
    verify(() => repo.watch(any(), limit: 60)).called(1);
  });

  for (final Size size in _sizes) {
    testWidgets('lays out at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      await pumpPage(tester, size: size);
      await show(tester, [
        _msg(1,
            text: 'নোটিশ: তোমাদের ব্যাচে October 2026 Current Affairs PDF '
                'আপলোড করা হয়েছে। https://youtu.be/abc123XYZ09'),
        _msg(2),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('group_send')), findsOneWidget);
    });
  }

  group('Subjects row', () {
    Future<void> pumpCard(WidgetTester tester, SubjectModel subject) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ChangeNotifierProvider<SubjectViewModel>(
        create: (_) => SubjectViewModel(subjectRepo: MockSubjectRepo()),
        child: MaterialApp(
          home: Scaffold(
            body: SubjectCard(subjectData: subject, onChanged: () {}),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('has a Group button before Edit', (tester) async {
      await pumpCard(tester, _subject());
      final Finder group = find.byKey(const Key('subject_group_sub-1'));
      expect(group, findsOneWidget);
      expect(find.byTooltip('Open group'), findsOneWidget);
      expect(
          tester.getTopLeft(group).dx,
          lessThan(tester
              .getTopLeft(find.byKey(const Key('subject_edit_sub-1')))
              .dx));
    });

    testWidgets('no code, no group', (tester) async {
      await pumpCard(tester, _subject(code: 'NA'));
      expect(find.byKey(const Key('subject_group_sub-1')), findsNothing);
    });
  });

  // The same cases as the student app's link_text_test.dart.
  group('links', () {
    List<String> links(String text) => [
          for (final TextPiece piece in splitLinks(text))
            if (piece.isLink) piece.link.toString(),
        ];

    test('found as the app finds them', () {
      expect(links('Visit www.bbarna.in.'), ['https://www.bbarna.in']);
      expect(links('দেখো: https://x.com/a।'), ['https://x.com/a']);
      expect(links('(https://x.com/a)'), ['https://x.com/a']);
      expect(links('https://en.wikipedia.org/wiki/Kolkata_(city)'),
          ['https://en.wikipedia.org/wiki/Kolkata_(city)']);
      expect(links('http://localhost and www. alone'), isEmpty);
    });

    test('no text lost when split', () {
      const String text = 'দেখো: https://x.com/a। আর (https://y.com)';
      expect(splitLinks(text).map((p) => p.text).join(), text);
    });
  });
}
