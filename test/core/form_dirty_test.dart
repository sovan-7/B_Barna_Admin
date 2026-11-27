import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_dirty_scope.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {double width = 1280}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final TextEditingController name = TextEditingController();
  addTearDown(name.dispose);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => FormPageBody(
          width: width,
          children: [
            FormTextField(
              label: "Course name",
              hint: "Name",
              controller: name,
              fieldKey: const Key('name'),
            ),
            FormToggleRow(
              key: const Key('toggle'),
              title: "Show in the app",
              subtitle: "Students can see it",
              value: false,
              onChanged: (_) {},
            ),
          ],
          actionBar: FormActionBar(
            width: width,
            isSaving: false,
            saveKey: const Key('save'),
            saveLabel: "Save",
            onSave: () {},
          ),
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('says nothing until a field is changed', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('form_unsaved_changes')), findsNothing);

    await tester.enterText(find.byKey(const Key('name')), 'Physics');
    await tester.pump();
    expect(find.byKey(const Key('form_unsaved_changes')), findsOneWidget);
  });

  testWidgets('a switch counts as a change', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.byKey(const Key('form_unsaved_changes')), findsOneWidget);
  });

  testWidgets('a phone keeps the bar to Cancel and Save', (tester) async {
    await _pump(tester, width: 400);
    await tester.enterText(find.byKey(const Key('name')), 'Physics');
    await tester.pump();
    expect(find.byKey(const Key('form_unsaved_changes')), findsNothing);
  });

  test('a mark after the page has gone is ignored', () {
    final FormDirtyController controller = FormDirtyController();
    controller.dispose();
    expect(controller.markDirty, returnsNormally);
    expect(controller.dirty, isFalse);
  });

  testWidgets('fields work outside a form page', (tester) async {
    final TextEditingController c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: FormTextField(
                label: "L",
                hint: "H",
                controller: c,
                fieldKey: const Key('f')))));
    await tester.enterText(find.byKey(const Key('f')), 'x');
    expect(tester.takeException(), isNull);
  });
}
