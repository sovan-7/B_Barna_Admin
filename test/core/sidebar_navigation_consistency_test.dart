import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/core/widgets/sidebar_widget.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// NOTE on scope: pumping the real `Sidebar` mounts
// `screenList[selectedIndex]` (e.g. `BannerList`) eagerly, whose initState
// lazily constructs its ViewModel -> Repo -> `FirebaseFirestore.instance`,
// which throws with no Firebase test app initialised anywhere in this
// codebase. That's a pre-existing coupling. So the widget tests here drive
// `ExtraSideBar`, which renders the very same `SidebarNav` that `Sidebar`
// does — the two no longer keep separate hand-synced copies of the list.
Future<void> _pumpNav(WidgetTester tester,
    {Size size = const Size(400, 1400), int selected = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: ExtraSideBar(sidebarIndex: selected)),
  ));
  await tester.pump();
}

void main() {
  // An admin sees every module; what others see is covered by
  // module_access_test.dart.
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{adminIdPrefsKey: 't1', rolePrefsKey: roleAdmin});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  group('module metadata stays in step', () {
    test('Teachers is where teacherModuleIndex says it is', () {
      expect(moduleList[teacherModuleIndex], 'TEACHERS');
    });

    test('every list is index-aligned with moduleList', () {
      expect(moduleDisplayList, hasLength(moduleList.length));
      expect(moduleIconList, hasLength(moduleList.length));
    });

    test('Live Classes is where liveClassModuleIndex says it is', () {
      expect(moduleList[liveClassModuleIndex], 'LIVE CLASSES');
      expect(moduleDisplayList[liveClassModuleIndex], 'Live Classes');
      expect(moduleIconList[liveClassModuleIndex], Icons.live_tv);
    });

    test('Notifications is where notificationModuleIndex says it is', () {
      expect(moduleList[notificationModuleIndex], 'NOTIFICATIONS');
      expect(moduleDisplayList[notificationModuleIndex], 'Notifications');
      expect(moduleIconList[notificationModuleIndex], Icons.campaign_outlined);
    });

    test('Question1 is where question1ModuleIndex says it is', () {
      expect(moduleList[question1ModuleIndex], 'QUESTION1');
      expect(moduleDisplayList[question1ModuleIndex], 'Question1');
      expect(moduleIconList[question1ModuleIndex], Icons.library_books);
    });
  });

  group('module groups', () {
    test('every module is in exactly one group', () {
      final List<int> grouped = [
        for (final ModuleGroup group in moduleGroups) ...group.modules,
      ];
      expect(grouped, hasLength(moduleList.length));
      expect(grouped.toSet(), {for (int i = 0; i < moduleList.length; i++) i});
    });

    test('each module reports the group it is listed under', () {
      expect(groupOfModule(courseModuleIndex)?.label, 'Content');
      expect(groupOfModule(topic1ModuleIndex)?.label, 'Content');
      expect(groupOfModule(videoModuleIndex)?.label, 'Media');
      expect(groupOfModule(quizModuleIndex)?.label, 'Assessment');
      expect(groupOfModule(teacherModuleIndex)?.label, 'People');
      expect(groupOfModule(bannerModuleIndex)?.label, 'Engage');
      expect(groupOfModule(transactionModuleIndex)?.label, 'Finance');
      expect(groupOfModule(-1), isNull);
    });

    test('railOrder lists modules group by group', () {
      expect(
          railOrder([bannerModuleIndex, studentModuleIndex, courseModuleIndex]),
          [courseModuleIndex, studentModuleIndex, bannerModuleIndex]);
    });
  });

  testWidgets('the nav renders every shown module, group by group',
      (tester) async {
    await _pumpNav(tester);

    final List<SidebarWidget> items =
        tester.widgetList<SidebarWidget>(find.byType(SidebarWidget)).toList();
    final List<int> shown = [
      for (final ModuleGroup group in moduleGroups)
        for (final int i in group.modules)
          if (!hiddenModuleIndices.contains(i)) i,
    ];
    final List<String> labels = items.map((item) => item.itemText).toList();
    expect(labels.indexOf('New Topics'), labels.indexOf('Topics') + 1,
        reason: 'Topic1 sits right after Topics');
    expect(labels, isNot(contains('Question1')),
        reason: 'Question1 is hidden from the sidebar');

    expect(labels, [for (final int i in shown) moduleDisplayList[i]]);
    expect(items.map((item) => item.iconData).toList(),
        [for (final int i in shown) moduleIconList[i]]);

    // Headings for every group with something in it; Shop holds only
    // hidden modules, so it has none.
    for (final String label in [
      'Content',
      'Media',
      'Assessment',
      'People',
      'Engage',
      'Finance'
    ]) {
      expect(find.byKey(ValueKey('nav_group_$label')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('nav_group_Shop')), findsNothing);
  });

  testWidgets('the selected module is the only one marked selected',
      (tester) async {
    await _pumpNav(tester, selected: liveClassModuleIndex);

    final List<SidebarWidget> selected = tester
        .widgetList<SidebarWidget>(find.byType(SidebarWidget))
        .where((item) => item.isSelected)
        .toList();

    expect(selected, hasLength(1));
    expect(selected.single.itemText, 'Live Classes');
  });

  testWidgets('a narrow panel drops the labels rather than clipping them',
      (tester) async {
    // What `Expanded(child: ExtraSideBar(...))` hands it on the add/edit
    // screens once the window gets small.
    await _pumpNav(tester,
        size: Size(AppTokens.railAutoCollapseWidth - 20, 1400));

    final List<SidebarWidget> items =
        tester.widgetList<SidebarWidget>(find.byType(SidebarWidget)).toList();

    expect(items, isNotEmpty);
    expect(items.every((item) => item.isCollapsed), isTrue);
    // Labels become tooltips, so no module name is painted.
    expect(find.text('Live Classes'), findsNothing);
    expect(find.byType(Tooltip), findsWidgets);
  });

  testWidgets('a wide panel keeps the labels', (tester) async {
    await _pumpNav(tester, size: const Size(400, 1400));

    final List<SidebarWidget> items =
        tester.widgetList<SidebarWidget>(find.byType(SidebarWidget)).toList();

    expect(items.every((item) => !item.isCollapsed), isTrue);
    expect(find.text('Live Classes'), findsOneWidget);
  });
}
