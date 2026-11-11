import 'dart:typed_data';

import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/repo/banners_repo.dart';
import 'package:bbarna/banners/screen/add_banner.dart';
import 'package:bbarna/banners/screen/banner_list.dart';
import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/banners/widgets/banner_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockBannersRepo extends Mock implements BannersRepo {}

BannersModel _banner(String id, String url) {
  final BannersModel model = BannersModel(bannerImage: url);
  model.docId = id;
  return model;
}

/// A 1x1 transparent PNG — enough bytes for the picker-shaped state
/// without reading a fixture off disk.
final Uint8List _pngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

Future<void> _pump(WidgetTester tester, Size size, Widget home,
    BannersViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<BannersViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    registerFallbackValue(BannersModel(bannerImage: ""));
    registerFallbackValue(Uint8List(0));
  });

  late MockBannersRepo repo;

  setUp(() {
    repo = MockBannersRepo();
    when(() => repo.getBannersList()).thenAnswer((_) async => [
          _banner('a', 'https://example.com/a.png'),
          _banner('b', 'https://example.com/b.png'),
          _banner('c', 'https://example.com/c.png'),
        ]);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the grid lays out at ${size.width.toInt()}', (tester) async {
        final vm = BannersViewModel(bannersRepo: repo);
        await _pump(tester, size, const Scaffold(body: BannerList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Banners'), findsOneWidget);
        expect(find.byType(BannerCard), findsNWidgets(3));
      });

      testWidgets('the add page lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = BannersViewModel(bannersRepo: repo);
        await _pump(tester, size, const AddBanner(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a banner'), findsOneWidget);
        expect(find.text('Choose an image'), findsOneWidget);
      });
    }

    testWidgets('the column count follows the width', (tester) async {
      // Purely arithmetic, but it is the rule the old hardcoded
      // `crossAxisCount: 5` got wrong at every width but one.
      expect(columnsFor(320, 300), 1);
      expect(columnsFor(700, 300), 2);
      expect(columnsFor(1300, 300), 4);
      expect(columnsFor(4000, 300), 5, reason: 'capped so tiles stay sane');
    });
  });

  group('empty and loading', () {
    testWidgets('an empty grid offers a way to fill it', (tester) async {
      when(() => repo.getBannersList()).thenAnswer((_) async => []);
      final vm = BannersViewModel(bannersRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: BannerList()), vm);

      expect(find.text('No banners yet'), findsOneWidget);
      expect(find.text('Upload a banner'), findsOneWidget);
    });

    test('a fresh view model starts loading, so nothing claims "no banners"',
        () {
      expect(BannersViewModel(bannersRepo: repo).isLoading, isTrue);
    });

    testWidgets('an empty result never flashes the empty state first',
        (tester) async {
      when(() => repo.getBannersList()).thenAnswer((_) async => []);
      final vm = BannersViewModel(bannersRepo: repo);

      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ChangeNotifierProvider<BannersViewModel>.value(
        value: vm,
        child: const MaterialApp(home: Scaffold(body: BannerList())),
      ));
      // First frame: the fetch has not resolved into the widget tree yet.
      expect(find.text('No banners yet'), findsNothing);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No banners yet'), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      // BannerList is mounted from Sidebar's `screenList[selectedIndex]`
      // during a build; the fetch used to notify — and push the global
      // loader dialog — synchronously from initState.
      final vm = BannersViewModel(bannersRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: BannerList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('createBanner keeps the collection clean', () {
    // The failure paths route through Helper.showSnackBarMessage, which
    // reaches for navigatorKey.currentContext — so they need a pumped app,
    // not a bare unit test.
    Future<void> withNavigator(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
    }

    test('returns true and uploads against the new doc', () async {
      when(() => repo.addBanner(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadBannerImage(any(), any()))
          .thenAnswer((_) async {});

      final vm = BannersViewModel(bannersRepo: repo);
      expect(await vm.createBanner(_pngBytes), isTrue);

      verify(() => repo.uploadBannerImage(_pngBytes, 'new-id')).called(1);
      verifyNever(() => repo.deleteBanner(any()));
    });

    testWidgets('a failed upload takes the empty document with it',
        (tester) async {
      when(() => repo.addBanner(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.uploadBannerImage(any(), any()))
          .thenThrow(Exception('storage down'));
      when(() => repo.deleteBanner(any())).thenAnswer((_) async {});
      await withNavigator(tester);

      final vm = BannersViewModel(bannersRepo: repo);
      expect(await vm.createBanner(_pngBytes), isFalse);

      // Without this the grid keeps a tile that can never show an image.
      verify(() => repo.deleteBanner('new-id')).called(1);
    });

    testWidgets('a failed create never tries to delete', (tester) async {
      when(() => repo.addBanner(any())).thenThrow(Exception('offline'));
      await withNavigator(tester);

      final vm = BannersViewModel(bannersRepo: repo);
      expect(await vm.createBanner(_pngBytes), isFalse);
      verifyNever(() => repo.deleteBanner(any()));
    });
  });

  testWidgets('saving with no image says so instead of doing nothing',
      (tester) async {
    final vm = BannersViewModel(bannersRepo: repo);
    await _pump(tester, const Size(1024, 768), const AddBanner(), vm);

    await tester.tap(find.byKey(const Key('banner_save_button')));
    await tester.pump();

    expect(find.text('Choose an image to upload'), findsOneWidget);
    verifyNever(() => repo.addBanner(any()));
  });

  testWidgets('a banner with no image url renders a placeholder, not a crash',
      (tester) async {
    // Exactly what an orphaned document from a failed upload looks like.
    when(() => repo.getBannersList())
        .thenAnswer((_) async => [_banner('orphan', '')]);

    final vm = BannersViewModel(bannersRepo: repo);
    await _pump(tester, const Size(1024, 768),
        const Scaffold(body: BannerList()), vm);

    expect(tester.takeException(), isNull);
    expect(find.text('No image uploaded'), findsOneWidget);
  });
}
