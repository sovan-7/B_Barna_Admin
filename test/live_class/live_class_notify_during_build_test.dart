import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/screen/add_live_class.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockLiveClassRepo extends Mock implements LiveClassRepo {}

LiveClassModel _model(String id, DateTime start) => LiveClassModel(
      docId: id,
      title: "Class $id",
      description: "d",
      youtubeLink: "l",
      teacherName: "T",
      startDateTime: start,
      endDateTime: start.add(const Duration(hours: 1)),
    );

/// Stands in for Sidebar, which mounts `screenList[selectedIndex]` from
/// inside its own build.
class _FakeSidebar extends StatefulWidget {
  const _FakeSidebar();
  @override
  State<_FakeSidebar> createState() => _FakeSidebarState();
}

class _FakeSidebarState extends State<_FakeSidebar> {
  int selectedIndex = 0;
  final List<Widget> screenList = const [
    Center(child: Text('other module')),
    LiveClassList(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          TextButton(
            key: const Key('go_live'),
            onPressed: () => setState(() => selectedIndex = 1),
            child: const Text('go'),
          ),
          Expanded(child: screenList[selectedIndex]),
        ]),
      );
}

Widget _wrap(LiveClassViewModel vm, Widget home) =>
    ChangeNotifierProvider<LiveClassViewModel>.value(
      value: vm,
      child: MaterialApp(navigatorKey: navigatorKey, home: home),
    );

void main() {
  late MockLiveClassRepo repo;

  setUp(() {
    repo = MockLiveClassRepo();
    when(() => repo.getLiveClassList()).thenAnswer((_) async =>
        [_model('a', DateTime.now().add(const Duration(days: 1)))]);
    when(() => repo.getTeachers()).thenAnswer(
        (_) async => [const LiveClassTeacher(id: 't1', name: 'T')]);
    when(() => repo.getSubjects()).thenAnswer(
        (_) async => [const LiveClassSubject(code: 'MECH', name: 'Mechanics')]);
  });

  // The regression this file exists for: a refresh that lands mid-build used
  // to throw "setState() or markNeedsBuild() called during build" out of
  // LiveClassViewModel's notification dispatch, leaving the list stale.
  testWidgets('notifying from inside a build does not throw', (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    bool mutated = false;

    await tester.pumpWidget(_wrap(
      vm,
      Scaffold(
        body: Consumer<LiveClassViewModel>(
          builder: (context, model, _) => Builder(builder: (context) {
            // Any descendant that mutates the view model while the framework
            // is still building — e.g. a deferred list refresh landing early.
            // Once only, so the rebuild it triggers doesn't loop.
            if (!mutated) {
              mutated = true;
              model.selectStatus(LiveClassStatus.live);
            }
            return const SizedBox();
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(vm.selectedStatus, LiveClassStatus.live);
  });

  testWidgets('a notify deferred past dispose is dropped', (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    bool mutated = false;
    await tester.pumpWidget(_wrap(
      vm,
      Scaffold(
        body: Consumer<LiveClassViewModel>(
          builder: (context, model, _) => Builder(builder: (context) {
            if (!mutated) {
              mutated = true;
              model.selectStatus(LiveClassStatus.past);
            }
            return const SizedBox();
          }),
        ),
      ),
    ));
    vm.dispose();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the sidebar onto the list stays clean',
      (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    await tester.pumpWidget(_wrap(vm, const _FakeSidebar()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('go_live')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Class a'), findsOneWidget);
  });

  testWidgets('the add route refreshing the list on pop stays clean',
      (tester) async {
    final vm = LiveClassViewModel(liveClassRepo: repo);
    await tester.pumpWidget(_wrap(vm, const Scaffold(body: LiveClassList())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.byType(AddLiveClass), findsOneWidget);

    // Close it the way a successful save does, which is what triggers the
    // refresh (a plain Cancel no longer reloads the list).
    navigatorKey.currentState!.pop(true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    verify(() => repo.getLiveClassList()).called(2);
  });
}
