import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

class LiveClassModelFake extends Fake implements LiveClassModel {}

/// Cards standing at different heights in the same row.
///
/// The grid was a flat `Wrap`, which sizes every child to its own content.
/// A class with a description therefore drew a taller card than the class
/// beside it, and the row ended ragged — exactly what the Upcoming tab
/// showed with one described class and one without.
///
/// The grid now lays out a row at a time inside an `IntrinsicHeight` with
/// `CrossAxisAlignment.stretch`, so a row has one height set by its tallest
/// card, and the card pushes its link row down to that height so the links
/// line up too.
void main() {
  setUpAll(() => registerFallbackValue(LiveClassModelFake()));

  LiveClassModel model(String id, String title, String description) {
    final DateTime start = DateTime.now().add(const Duration(days: 1));
    return LiveClassModel(
      docId: id,
      title: title,
      description: description,
      youtubeLink: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      teacherName: 'Amaresh Sarkar',
      startDateTime: start,
      endDateTime: start.add(const Duration(minutes: 90)),
    );
  }

  /// The reported pair: one described, one not. Both Upcoming, which is the
  /// tab the screen opens on.
  List<LiveClassModel> mixedFixture() => [
        model('test_class', 'Test Class', ''),
        model('abc', 'ABC', 'acdafgaah'),
      ];

  late MockLiveClassRepo repo;

  setUp(() {
    repo = MockLiveClassRepo();
    when(() => repo.getTeachers()).thenAnswer((_) async => const []);
    when(() => repo.getSubjects()).thenAnswer((_) async => const []);
  });

  Future<void> pumpList(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<LiveClassViewModel>.value(
        value: LiveClassViewModel(liveClassRepo: repo),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: LiveClassList()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a described and an undescribed card share a row height',
      (tester) async {
    when(() => repo.getLiveClassList()).thenAnswer((_) async => mixedFixture());

    // Wide enough for two columns (cardMinWidth is 340).
    await pumpList(tester, const Size(1000, 900));

    final Finder cards = find.byType(LiveClassCard);
    expect(cards, findsNWidgets(2));

    final Size first = tester.getSize(cards.at(0));
    final Size second = tester.getSize(cards.at(1));

    expect(first.height, second.height,
        reason: 'the undescribed card must stretch to the row height');
    // Same row, so the ragged bottom edge is gone.
    expect(tester.getTopLeft(cards.at(0)).dy,
        tester.getTopLeft(cards.at(1)).dy);
    expect(tester.getBottomLeft(cards.at(0)).dy,
        tester.getBottomLeft(cards.at(1)).dy);
  });

  testWidgets('the link rows line up across both cards', (tester) async {
    when(() => repo.getLiveClassList()).thenAnswer((_) async => mixedFixture());
    await pumpList(tester, const Size(1000, 900));

    final Finder first = find.byKey(const Key('live_class_link_test_class'));
    final Finder second = find.byKey(const Key('live_class_link_abc'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy,
        reason: 'the link row is pushed to the bottom of each card');
  });

  testWidgets('cards still line up when neither has a description',
      (tester) async {
    when(() => repo.getLiveClassList()).thenAnswer((_) async => [
          model('a', 'Test Class', ''),
          model('b', 'ABC', ''),
        ]);
    await pumpList(tester, const Size(1000, 900));

    final Finder cards = find.byType(LiveClassCard);
    expect(tester.getSize(cards.at(0)).height,
        tester.getSize(cards.at(1)).height);
  });

  testWidgets('an odd card count leaves the last row intact', (tester) async {
    when(() => repo.getLiveClassList()).thenAnswer((_) async => [
          model('a', 'One', 'has a description'),
          model('b', 'Two', ''),
          model('c', 'Three', ''),
        ]);
    await pumpList(tester, const Size(1000, 900));

    expect(tester.takeException(), isNull);
    expect(find.byType(LiveClassCard), findsNWidgets(3));
  });

  testWidgets('a single column still renders', (tester) async {
    when(() => repo.getLiveClassList()).thenAnswer((_) async => mixedFixture());
    await pumpList(tester, const Size(380, 820));

    expect(tester.takeException(), isNull);
    expect(find.byType(LiveClassCard), findsNWidgets(2));
  });
}
