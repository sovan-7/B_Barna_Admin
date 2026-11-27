import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget child,
    {Size size = const Size(1280, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    scaffoldMessengerKey: snackBarKey,
    home: Scaffold(body: child),
  ));
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{adminIdPrefsKey: 't1', rolePrefsKey: roleAdmin});
    sharedPreferences = await SharedPreferences.getInstance();
  });

  group('StatsStrip', () {
    List<Widget> tiles() => [
          StatTile.count(key: const Key('a'), label: "Total", count: 12),
          StatTile.count(key: const Key('b'), label: "Visible", count: 9),
          StatTile.count(key: const Key('c'), label: "Hidden", count: 3),
          const StatTile(
              key: Key('d'),
              label: "Revenue",
              value: "₹1,84,350",
              caption: "↑ 12% vs October"),
        ];

    testWidgets('puts every tile on one line when there is room',
        (tester) async {
      await _pump(tester, StatsStrip(tiles: tiles()));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('₹1,84,350'), findsOneWidget);
      expect(find.text('↑ 12% vs October'), findsOneWidget);
      final double y = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      expect(tester.getTopLeft(find.byKey(const Key('d'))).dy, y);
    });

    testWidgets('wraps two to a line when narrow', (tester) async {
      await _pump(tester, StatsStrip(tiles: tiles()),
          size: const Size(420, 800));

      final double firstRow = tester.getTopLeft(find.byKey(const Key('a'))).dy;
      expect(tester.getTopLeft(find.byKey(const Key('b'))).dy, firstRow);
      expect(tester.getTopLeft(find.byKey(const Key('c'))).dy,
          greaterThan(firstRow));
    });
  });

  testWidgets('FilterChipBar reports the tapped value', (tester) async {
    String? picked = 'unset';
    await _pump(
      tester,
      FilterChipBar<String?>(
        selected: null,
        onChanged: (value) => picked = value,
        options: const [
          FilterOption(null, "All", key: Key('all')),
          FilterOption('hidden', "Hidden", key: Key('hidden')),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('hidden')));
    expect(picked, 'hidden');
    await tester.tap(find.byKey(const Key('all')));
    expect(picked, isNull);
  });

  group('AdminTable', () {
    const List<AdminTableColumn> columns = [
      AdminTableColumn("Course", flex: 4),
      AdminTableColumn("Code", flex: 2),
      AdminTableColumn("", width: 60, alignment: Alignment.centerRight),
    ];

    Widget table({ValueChanged<int>? onRowTap, Widget? footer}) => AdminTable(
          columns: columns,
          rowCount: 2,
          rowKey: (i) => ValueKey('row_$i'),
          onRowTap: onRowTap,
          footer: footer,
          cellsBuilder: (context, i, hovered) => [
            Text(['WBCS Prelims 2027', 'SSC CGL complete'][i]),
            Text(['WBCS27', 'SSCCGL'][i]),
            hovered
                ? Icon(Icons.edit, key: ValueKey('edit_$i'))
                : const SizedBox.shrink(),
          ],
        );

    testWidgets('shows upper-case titles and a row per item', (tester) async {
      await _pump(tester, table(footer: const Text('Load more')));

      expect(find.text('COURSE'), findsOneWidget);
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('WBCS Prelims 2027'), findsOneWidget);
      expect(find.text('SSCCGL'), findsOneWidget);
      expect(find.text('Load more'), findsOneWidget);
      // Header and rows share columns, so the code column lines up.
      expect(tester.getTopLeft(find.text('CODE')).dx,
          tester.getTopLeft(find.text('WBCS27')).dx);
    });

    testWidgets('row actions appear on hover', (tester) async {
      await _pump(tester, table());
      expect(find.byKey(const ValueKey('edit_0')), findsNothing);

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('row_0'))));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('edit_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('edit_1')), findsNothing);
    });

    testWidgets('row actions always show on a compact screen', (tester) async {
      await _pump(tester, table(), size: const Size(800, 800));
      expect(find.byKey(const ValueKey('edit_0')), findsOneWidget);
    });

    testWidgets('a tapped row reports its index', (tester) async {
      int? tapped;
      await _pump(tester, table(onRowTap: (i) => tapped = i));

      await tester.tap(find.text('SSC CGL complete'));
      expect(tapped, 1);
    });
  });

  group('cells', () {
    testWidgets('StatusPill shows its label', (tester) async {
      await _pump(
          tester,
          const Row(children: [
            StatusPill("Visible", tone: StatusTone.success),
            StatusPill("Live", tone: StatusTone.danger, dot: true),
          ]));
      expect(find.text('Visible'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('LockSwitch flips, and shows a spinner while saving',
        (tester) async {
      bool? flipped;
      await _pump(
          tester,
          LockSwitch(
              locked: false,
              itemLabel: "this course",
              switchKey: const Key('lock'),
              onChanged: (value) => flipped = value));

      expect(find.byTooltip('Lock this course'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lock')));
      expect(flipped, isTrue);

      await _pump(
          tester, LockSwitch(locked: true, busy: true, onChanged: (_) {}));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('CodeChip copies its code', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _pump(tester, const CodeChip('VID-301', copyable: true));
      await tester.tap(find.byKey(const Key('copy_code_VID-301')));
      await tester.pump();

      expect(copied, 'VID-301');
      // Let the "Copied" toast finish its timers.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('CodeChip has no copy button unless asked', (tester) async {
      await _pump(tester, const CodeChip('VID-301'));
      expect(find.byKey(const Key('copy_code_VID-301')), findsNothing);
    });
  });

  group('AppHeader breadcrumb', () {
    testWidgets('leads with the module group and name', (tester) async {
      await _pump(
          tester,
          AppHeader(
              onTapIcon: () {},
              moduleIndex: courseModuleIndex,
              title: "Add a course"));

      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Add a course'), findsOneWidget);
    });

    testWidgets('does not repeat the module name', (tester) async {
      await _pump(
          tester,
          AppHeader(
              onTapIcon: () {},
              moduleIndex: courseModuleIndex,
              title: "Courses"));
      expect(find.text('Courses'), findsOneWidget);
    });

    testWidgets('shows the role on the account chip', (tester) async {
      await _pump(tester, AppHeader(onTapIcon: () {}));
      expect(find.text('Admin'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app_header_account')));
      await tester.pumpAndSettle();
      expect(find.text('Signed in as Admin'), findsOneWidget);
      expect(find.byKey(const Key('app_header_sign_out')), findsOneWidget);
    });

    testWidgets('a phone shows only the page, beside the menu button',
        (tester) async {
      await _pump(
          tester,
          AppHeader(
              onTapIcon: () {},
              moduleIndex: courseModuleIndex,
              title: "Add a course"),
          size: const Size(400, 800));

      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Content'), findsNothing);
      expect(find.text('Add a course'), findsOneWidget);
    });
  });
}
