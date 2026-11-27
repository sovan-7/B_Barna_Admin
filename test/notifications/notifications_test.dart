import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/repo/banners_repo.dart';
import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/core/widgets/app_toast.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/notifications/repo/notifications_repo.dart';
import 'package:bbarna/notifications/screen/notification_list.dart';
import 'package:bbarna/notifications/screen/send_notification.dart';
import 'package:bbarna/notifications/viewModel/notifications_view_model.dart';
import 'package:bbarna/notifications/widgets/notification_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockNotificationsRepo extends Mock implements NotificationsRepo {}

class MockBannersRepo extends Mock implements BannersRepo {}

class _FakeSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;
  _FakeSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;
}

final Uint8List _pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

NotificationModel _sent(String id, String title,
        {NotificationStatus status = NotificationStatus.sent,
        String? imageUrl,
        String? url,
        String? error}) =>
    NotificationModel(
      docId: id,
      title: title,
      body: "Body of $title",
      imageUrl: imageUrl,
      url: url,
      status: status,
      error: error,
      createdAt: DateTime(2026, 10, 30, 16, 5),
    );

/// History rows on screen: table rows on wide windows, cards on narrow.
Finder _rows() => find.byWidgetPredicate((widget) {
      if (widget is NotificationCard) return true;
      final Key? key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('notification_row_');
    });

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationModel(title: "", body: ""));
    registerFallbackValue(Uint8List(0));
  });

  late MockNotificationsRepo repo;
  late MockBannersRepo bannersRepo;

  setUp(() {
    repo = MockNotificationsRepo();
    bannersRepo = MockBannersRepo();
    when(() => repo.getNotifications()).thenAnswer((_) async => [
          _sent('a', 'Holiday notice'),
          _sent('b', 'New batch', status: NotificationStatus.pending),
          _sent('c', 'Broken', status: NotificationStatus.failed, error: 'x'),
          _sent('d', 'Live class', url: 'https://meet.google.com/abc-defg-hij'),
        ]);
    when(() => repo.send(any())).thenAnswer((_) async => 'new-id');
    when(() => repo.uploadImage(any()))
        .thenAnswer((_) async => 'https://example.com/up.png');
    final BannersModel banner =
        BannersModel(bannerImage: 'https://example.com/banner.png');
    banner.docId = 'banner-1';
    when(() => bannersRepo.getBannersList()).thenAnswer((_) async => [banner]);
  });

  Future<NotificationsViewModel> pump(WidgetTester tester, Widget home,
      {Size size = const Size(1024, 768)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vm = NotificationsViewModel(notificationsRepo: repo);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationsViewModel>.value(value: vm),
        ChangeNotifierProvider<BannersViewModel>(
            create: (_) => BannersViewModel(bannersRepo: bannersRepo)),
      ],
      child: MaterialApp(navigatorKey: navigatorKey, home: home),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return vm;
  }

  group('model', () {
    test('reads a document the Cloud Function has updated', () {
      final model = NotificationModel.fromDocumentSnapshot(_FakeSnapshot('id', {
        'title': 'Hi',
        'body': 'There',
        'image_url': 'https://example.com/i.png',
        'status': 'failed',
        'error': 'boom',
        'created_at': Timestamp.fromDate(DateTime(2026, 1, 2)),
      }));

      expect(model.docId, 'id');
      expect(model.status, NotificationStatus.failed);
      expect(model.error, 'boom');
      expect(model.hasImage, isTrue);
      expect(model.createdAt, DateTime(2026, 1, 2));
    });

    test('an unknown or missing status counts as pending', () {
      expect(NotificationStatus.fromName('weird'), NotificationStatus.pending);
      expect(NotificationStatus.fromName(null), NotificationStatus.pending);
    });

    test('a text-only notification stores no image url', () {
      const model = NotificationModel(title: 'T', body: '', imageUrl: '');
      expect(model.toMap()['image_url'], isNull);
      expect(model.toMap()['status'], 'pending');
    });

    test('copies the title and the whole text, links included', () {
      const model = NotificationModel(
          title: 'Live class',
          body: 'Join at 7 pm.\nhttps://meet.example.com/abc-defg-hij');
      expect(model.copyText,
          'Live class\nJoin at 7 pm.\nhttps://meet.example.com/abc-defg-hij');
    });

    test('with no text, copies just the title', () {
      const model = NotificationModel(title: 'Holiday', body: '');
      expect(model.copyText, 'Holiday');
    });

    test('stores and reads the link as url', () {
      const model = NotificationModel(
          title: 'Live class',
          body: '',
          url: ' https://meet.google.com/abc-defg-hij ');
      expect(model.hasLink, isTrue);
      expect(model.toMap()['url'], 'https://meet.google.com/abc-defg-hij');

      final read = NotificationModel.fromDocumentSnapshot(_FakeSnapshot('id', {
        'title': 'Live class',
        'url': 'https://youtu.be/dQw4w9WgXcQ',
      }));
      expect(read.url, 'https://youtu.be/dQw4w9WgXcQ');
      expect(read.hasLink, isTrue);
    });

    test('no link stores null', () {
      const blank = NotificationModel(title: 'T', body: '', url: '  ');
      expect(blank.hasLink, isFalse);
      expect(blank.toMap()['url'], isNull);
      expect(blank.toMap().containsKey('url'), isTrue);

      final read = NotificationModel.fromDocumentSnapshot(
          _FakeSnapshot('id', {'title': 'Old one'}));
      expect(read.url, isNull);
      expect(read.hasLink, isFalse);
    });

    test('copies the link after the title and text', () {
      const model = NotificationModel(
          title: 'Live class',
          body: 'Join at 7 pm.',
          url: 'https://zoom.us/j/123456789');
      expect(model.copyText,
          'Live class\nJoin at 7 pm.\nhttps://zoom.us/j/123456789');
      const noBody = NotificationModel(
          title: 'Live class', body: '', url: 'https://zoom.us/j/1');
      expect(noBody.copyText, 'Live class\nhttps://zoom.us/j/1');
    });
  });

  group('linkProblem', () {
    for (final String ok in [
      '',
      '   ',
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://youtu.be/dQw4w9WgXcQ',
      'https://meet.google.com/abc-defg-hij',
      'https://us02web.zoom.us/j/123456789?pwd=abc',
      'http://example.com/page',
      ' HTTPS://Example.com ',
    ]) {
      test('accepts "$ok"', () {
        expect(NotificationModel.linkProblem(ok), isNull);
      });
    }

    for (final String bad in [
      'meet.google.com/abc-defg-hij',
      'www.youtube.com/watch?v=dQw4w9WgXcQ',
      'ftp://example.com/file',
      'https://',
      'https://localhost',
      'not a link',
      'https://meet.google.com/abc defg',
    ]) {
      test('rejects "$bad"', () {
        expect(NotificationModel.linkProblem(bad),
            'Paste the full link, starting with https://');
      });
    }
  });

  group('sendNotification', () {
    test('text only: writes the document, uploads nothing', () async {
      final vm = NotificationsViewModel(notificationsRepo: repo);
      expect(await vm.sendNotification(title: ' Hi ', body: ' There '), isTrue);

      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.title, 'Hi');
      expect(sent.body, 'There');
      expect(sent.imageUrl, isNull);
      verifyNever(() => repo.uploadImage(any()));
    });

    test('a new picture is uploaded first and its url sent', () async {
      final vm = NotificationsViewModel(notificationsRepo: repo);
      expect(
          await vm.sendNotification(title: 'Hi', body: '', newImage: _pngBytes),
          isTrue);

      verify(() => repo.uploadImage(_pngBytes)).called(1);
      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.imageUrl, 'https://example.com/up.png');
    });

    test('a banner is sent by its url, without uploading again', () async {
      final vm = NotificationsViewModel(notificationsRepo: repo);
      await vm.sendNotification(
          title: 'Hi',
          body: '',
          existingImageUrl: 'https://example.com/banner.png');

      verifyNever(() => repo.uploadImage(any()));
      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.imageUrl, 'https://example.com/banner.png');
    });

    test('the link is sent trimmed', () async {
      final vm = NotificationsViewModel(notificationsRepo: repo);
      await vm.sendNotification(
          title: 'Hi', body: '', url: ' https://meet.google.com/abc ');

      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.url, 'https://meet.google.com/abc');
    });

    test('a blank link is sent as none', () async {
      final vm = NotificationsViewModel(notificationsRepo: repo);
      await vm.sendNotification(title: 'Hi', body: '', url: '   ');

      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.url, isNull);
    });

    testWidgets('a failed upload sends nothing', (tester) async {
      when(() => repo.uploadImage(any())).thenThrow(Exception('storage down'));
      final vm = await pump(tester, const Scaffold(body: SizedBox()));

      expect(
          await vm.sendNotification(title: 'Hi', body: '', newImage: _pngBytes),
          isFalse);
      verifyNever(() => repo.send(any()));
    });
  });

  group('history', () {
    for (final Size size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}', (tester) async {
        await pump(tester, const Scaffold(body: NotificationList()),
            size: size);

        expect(tester.takeException(), isNull);
        if (size.width < 900) {
          // Cards, scrolling once they run out of room.
          expect(_rows(), findsWidgets);
          return;
        }
        expect(_rows(), findsNWidgets(4));
        // Counted inside the rows: the tiles and chips above say these too.
        Finder inRows(String text) =>
            find.descendant(of: _rows(), matching: find.text(text));
        expect(inRows('Sent'), findsNWidgets(2));
        expect(inRows('Sending'), findsOneWidget);
        expect(inRows('Failed'), findsOneWidget);
      });
    }

    testWidgets('only a notification with a link shows it and Open link',
        (tester) async {
      // The card (narrow windows) spells the link out.
      await pump(tester, const Scaffold(body: NotificationList()),
          size: const Size(800, 900));

      expect(find.byKey(const Key('notification_open_link')), findsOneWidget);
      final SelectableText link = tester.widget(find.descendant(
          of: find.byKey(const Key('notification_link')),
          matching: find.byType(SelectableText)));
      expect(link.data, 'meet.google.com/abc-defg-hij');
      expect(find.byKey(const Key('notification_link')), findsOneWidget);
    });

    testWidgets('nothing sent yet offers to send one', (tester) async {
      when(() => repo.getNotifications()).thenAnswer((_) async => []);
      await pump(tester, const Scaffold(body: NotificationList()));

      expect(find.text('No notifications sent yet'), findsOneWidget);
      expect(find.text('Send a notification'), findsOneWidget);
    });

    testWidgets('a failed load shows Retry', (tester) async {
      when(() => repo.getNotifications()).thenThrow(Exception('offline'));
      await pump(tester, const Scaffold(body: NotificationList()));

      expect(find.text("Couldn't load notifications"), findsOneWidget);
    });

    testWidgets('the copy button puts the title and text on the clipboard',
        (tester) async {
      // A toast left over from an earlier test still points at that test's
      // overlay; clear it so this one shows in this test's window.
      AppToast.dismissAll();
      addTearDown(AppToast.dismissAll);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pump(tester, const Scaffold(body: NotificationList()),
          size: const Size(800, 900));
      expect(find.byKey(const Key('notification_copy')), findsNWidgets(4));

      await tester.tap(find.byKey(const Key('notification_copy')).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(copied, 'Holiday notice\nBody of Holiday notice');
      expect(find.text('Copied to clipboard'), findsOneWidget);
      // Let the toast run out so no timer is left pending.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('send page', () {
    for (final Size size in _sizes) {
      testWidgets('lays out at ${size.width.toInt()}', (tester) async {
        await pump(tester, const SendNotification(), size: size);

        expect(tester.takeException(), isNull);
        expect(find.text('Send a notification'), findsOneWidget);
        expect(find.byType(NotificationPreview), findsOneWidget);
      });
    }

    testWidgets('sending without a title says so and sends nothing',
        (tester) async {
      await pump(tester, const SendNotification());

      await tester.tap(find.byKey(const Key('notification_send_button')));
      await tester.pump();

      expect(find.text('Enter a title'), findsOneWidget);
      verifyNever(() => repo.send(any()));
    });

    testWidgets('the preview follows what is typed', (tester) async {
      await pump(tester, const SendNotification());

      await tester.enterText(
          find.byKey(const Key('notification_title_field')), 'Exam on Friday');
      await tester.pump();

      final Text preview =
          tester.widget(find.byKey(const Key('notification_preview_title')));
      expect(preview.data, 'Exam on Friday');
    });

    testWidgets('the link field is hidden by default', (tester) async {
      await pump(tester, const SendNotification());

      expect(find.byKey(const Key('notification_link_field')), findsNothing);
      expect(find.text('Link (optional)'), findsNothing);
      expect(find.byKey(const Key('notification_preview_link')), findsNothing);
    });

    testWidgets('the preview shows the link once one is typed', (tester) async {
      await pump(tester, const SendNotification(showLinkField: true));
      expect(find.byKey(const Key('notification_preview_link')), findsNothing);

      await tester.enterText(find.byKey(const Key('notification_link_field')),
          'https://meet.google.com/abc-defg-hij');
      await tester.pump();

      final Text preview =
          tester.widget(find.byKey(const Key('notification_preview_link')));
      expect(preview.data, 'https://meet.google.com/abc-defg-hij');
    });

    testWidgets('a link without https:// is refused and nothing is sent',
        (tester) async {
      await pump(tester, const SendNotification(showLinkField: true));

      await tester.enterText(
          find.byKey(const Key('notification_title_field')), 'Live class');
      await tester.enterText(find.byKey(const Key('notification_link_field')),
          'meet.google.com/abc-defg-hij');
      await tester.tap(find.byKey(const Key('notification_send_button')));
      await tester.pump();

      expect(find.text('Paste the full link, starting with https://'),
          findsOneWidget);
      verifyNever(() => repo.send(any()));

      // Typing again clears the error.
      await tester.enterText(find.byKey(const Key('notification_link_field')),
          'https://meet.google.com/abc-defg-hij');
      await tester.pump();
      expect(find.text('Paste the full link, starting with https://'),
          findsNothing);
    });

    testWidgets('a link goes out with the notification', (tester) async {
      await pump(tester, const SendNotification(showLinkField: true));

      await tester.enterText(
          find.byKey(const Key('notification_title_field')), 'Live class');
      await tester.enterText(find.byKey(const Key('notification_link_field')),
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      await tester.tap(find.byKey(const Key('notification_send_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.url, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    });

    testWidgets('"Use a banner" needs a banner to be chosen', (tester) async {
      await pump(tester, const SendNotification());

      await tester.enterText(
          find.byKey(const Key('notification_title_field')), 'Offer');
      // The picture choices sit below the message fields.
      await tester
          .ensureVisible(find.byKey(const Key('notification_source_banner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification_source_banner')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('notification_send_button')));
      await tester.pump();

      expect(
          find.text('Choose a banner, or pick "No picture"'), findsOneWidget);
      verifyNever(() => repo.send(any()));
    });

    testWidgets('confirming sends it to everyone', (tester) async {
      await pump(tester, const SendNotification());

      await tester.enterText(
          find.byKey(const Key('notification_title_field')), 'Hello');
      await tester.tap(find.byKey(const Key('notification_send_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final NotificationModel sent =
          verify(() => repo.send(captureAny())).captured.single;
      expect(sent.title, 'Hello');
      expect(sent.imageUrl, isNull);
      expect(sent.url, isNull);
    });
  });
}
