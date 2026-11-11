import 'dart:typed_data';

import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/repo/banners_repo.dart';
import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/notifications/repo/notifications_repo.dart';
import 'package:bbarna/notifications/screen/notification_list.dart';
import 'package:bbarna/notifications/screen/send_notification.dart';
import 'package:bbarna/notifications/viewModel/notifications_view_model.dart';
import 'package:bbarna/notifications/widgets/notification_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
        String? error}) =>
    NotificationModel(
      docId: id,
      title: title,
      body: "Body of $title",
      imageUrl: imageUrl,
      status: status,
      error: error,
      createdAt: DateTime(2026, 10, 30, 16, 5),
    );

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
        expect(find.byType(NotificationCard), findsNWidgets(3));
        expect(find.text('Sent'), findsOneWidget);
        expect(find.text('Sending'), findsOneWidget);
        expect(find.text('Failed'), findsOneWidget);
      });
    }

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

    testWidgets('"Use a banner" needs a banner to be chosen', (tester) async {
      await pump(tester, const SendNotification());

      await tester.enterText(
          find.byKey(const Key('notification_title_field')), 'Offer');
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
    });
  });
}
