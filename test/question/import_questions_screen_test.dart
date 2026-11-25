import 'dart:convert';
import 'dart:typed_data';

import 'package:bbarna/question/repo/question_repo.dart';
import 'package:bbarna/question/screen/import_questions.dart';
import 'package:bbarna/question/viewModel/question_import_view_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockQuestionRepo extends Mock implements QuestionRepo {}

const String _file =
    "question_code,question,option_a,option_b,option_c,option_d,answer\n"
    "Q1,What is the capital of India?,Mumbai,New Delhi,Kolkata,Chennai,B\n"
    "Q2,An extremely long question that will certainly not fit on one line "
    "of the preview at any width whatsoever,a,b,,d,A\n"
    "Q1,Duplicate,a,b,c,d,Z\n";

Future<QuestionImportViewModel> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final MockQuestionRepo repo = MockQuestionRepo();
  when(() => repo.existingCodes(any())).thenAnswer((_) async => {});
  final vm = QuestionImportViewModel(questionRepo: repo);

  await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey, home: ImportQuestions(viewModel: vm)));
  await vm.loadFile(Uint8List.fromList(utf8.encode(_file)), "questions.csv");
  await tester.pumpAndSettle();
  return vm;
}

void main() {
  for (final Size size in const [Size(1440, 900), Size(380, 820)]) {
    testWidgets('a preview lays out at ${size.width.toInt()}', (tester) async {
      await _pump(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('import_summary')), findsOneWidget);
      expect(find.byKey(const Key('import_row_2')), findsOneWidget);
      expect(find.text('Fill in option C'), findsOneWidget);
      expect(find.text('Code Q1 is already used in row 2'), findsOneWidget);
      expect(find.text('Import 1 question'), findsOneWidget);
      expect(find.byKey(const Key('import_download_rejected')), findsOneWidget);
    });
  }
}
