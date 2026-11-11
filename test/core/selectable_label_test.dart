import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contract every module list now leans on.
///
/// Names, titles and codes used to be plain [Text], which cannot be selected
/// with the mouse and so cannot be copied — an admin had to retype a subject
/// code to paste it into another form. [SelectableLabel] is the replacement,
/// and these tests pin the two things that made it worth replacing: the text
/// really does reach the clipboard, and the row still clamps the same way it
/// did as [Text].
void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('the text can be selected and copied to the clipboard',
      (tester) async {
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

    await pump(tester, const SelectableLabel('PHY-11'));

    final EditableTextState state =
        tester.state<EditableTextState>(find.byType(EditableText));
    state.selectAll(SelectionChangedCause.tap);
    await tester.pump();
    state.copySelection(SelectionChangedCause.toolbar);
    await tester.pump();

    expect(copied, 'PHY-11',
        reason: 'this is the whole point: the code reaches the clipboard');
  });

  testWidgets('selection is enabled, unlike the Text it replaced',
      (tester) async {
    await pump(tester, const SelectableLabel('Trigonometry'));

    final EditableText editable = tester.widget<EditableText>(
      find.byType(EditableText),
    );
    expect(editable.selectionEnabled, isTrue);
    expect(editable.readOnly, isTrue,
        reason: 'a label is copyable, not editable');
  });

  testWidgets('a long value still clamps to one line with an ellipsis',
      (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 120,
        child: SelectableLabel(
          'An extremely long subject name that cannot fit on one line',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final EditableText editable =
        tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.maxLines, 1);
    expect(editable.style.overflow, TextOverflow.ellipsis);
  });

  testWidgets('maxLines passes through for the two-line values',
      (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 120,
        child: SelectableLabel('A question that runs onto a second line',
            maxLines: 2),
      ),
    );

    expect(tester.widget<EditableText>(find.byType(EditableText)).maxLines, 2);
  });

  testWidgets('the caller style survives the overflow override',
      (tester) async {
    await pump(
      tester,
      const SelectableLabel(
        'Mechanics',
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
    );

    final TextStyle style =
        tester.widget<EditableText>(find.byType(EditableText)).style;
    expect(style.fontSize, 14.5);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.overflow, TextOverflow.ellipsis);
  });
}
