import 'dart:convert';
import 'dart:typed_data';

import 'package:bbarna/question/import/question_import_row.dart';
import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/question/repo/question_repo.dart';
import 'package:bbarna/question/viewModel/question_import_view_model.dart';
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockQuestionRepo extends Mock implements QuestionRepo {}

const String _header =
    "question_code,question,option_a,option_b,option_c,option_d,answer";

SheetRow _row(int number, Map<String, String> cells) => SheetRow(number, {
      "question_code": "Q$number",
      "question": "Question $number?",
      "option_a": "a",
      "option_b": "b",
      "option_c": "c",
      "option_d": "d",
      "answer": "A",
      ...cells,
    });

Uint8List _csv(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  // The view model notifies through SafeNotifier, which asks the scheduler
  // what phase the frame is in.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a row', () {
    test('turns into the HTML the editors store', () {
      final row = buildImportRows([
        _row(2, {
          "question_code": " q-7 ",
          "question": "Is 1 < 2 & 3 > 2?",
          "solution": "First line\nSecond line",
        })
      ]).single;

      expect(row.isValid, isTrue);
      expect(row.code, "Q-7");
      expect(row.draft.question, "<p>Is 1 &lt; 2 &amp; 3 &gt; 2?</p>");
      expect(row.draft.solution, "<p>First line<br>Second line</p>");
      expect(row.draft.hints, "", reason: "an empty cell stays empty");
      expect(row.preview, "Is 1 < 2 & 3 > 2?");
    });

    test('saves exactly what the Add Question form would', () {
      final row = buildImportRows([
        _row(2, {"answer": "c"})
      ]).single;
      final Map<String, dynamic> map = row.draft.toMap(timeStamp: 5);

      expect(map["question_code"], "Q2");
      expect(map["option3"], "<p>c</p>");
      expect(map["answer"], "<p>c</p>",
          reason: "the answer is a copy of the chosen option's HTML");
      expect(map["timeStamp"], 5);
    });

    test('an answer can be a letter, a number or the option text', () {
      const options = ["Mumbai", "New Delhi", "Kolkata", "Chennai"];
      expect(parseAnswer("b", options), QuestionOption.b);
      expect(parseAnswer(" D ", options), QuestionOption.d);
      expect(parseAnswer("3", options), QuestionOption.c);
      expect(parseAnswer("new delhi", options), QuestionOption.b);
      expect(parseAnswer("E", options), isNull);
      expect(parseAnswer("", options), isNull);
    });

    test('an unknown answer says what was typed', () {
      final row = buildImportRows([
        _row(2, {"answer": "E"})
      ]).single;
      expect(
          row.errors, ['Answer "E" must be A, B, C or D, or match an option']);
    });

    test('uses the form\'s rules for missing fields', () {
      final row = buildImportRows([
        _row(2, {"question_code": "", "option_c": "", "answer": ""})
      ]).single;

      expect(row.isValid, isFalse);
      expect(row.errors, contains("Give the question a code"));
      expect(row.errors, contains("Fill in option C"));
      expect(row.errors, contains("Mark which option is correct"));
    });

    test('a code repeated in the file is kept on its first row only', () {
      final rows = buildImportRows([
        _row(2, {"question_code": "Q1"}),
        _row(3, {}),
        _row(4, {"question_code": "q1"}),
      ]);

      expect(rows[0].isValid, isTrue);
      expect(rows[1].isValid, isTrue);
      expect(rows[2].errors, ["Code Q1 is already used in row 2"]);
    });

    test('a code that already exists is reported', () {
      final rows = buildImportRows([_row(2, {}), _row(3, {})]);
      markExistingCodes(rows, {"Q3"});

      expect(rows[0].isValid, isTrue);
      expect(rows[1].errors, ["Code Q3 already exists"]);
    });
  });

  group('the files handed back', () {
    test('the template parses into one valid row', () {
      final rows = buildImportRows(
          QuestionSheetParser.parse(_csv(templateCsv()), "template.csv"));
      expect(rows.single.isValid, isTrue);
      expect(rows.single.draft.answer, QuestionOption.b);
    });

    test('rejected rows keep their cells and say why', () {
      final rows = buildImportRows([
        _row(2, {}),
        _row(3, {"option_d": ""}),
      ]);
      final List<List<dynamic>> csv =
          const CsvToListConverter(shouldParseNumbers: false)
              .convert(rejectedRowsCsv(rows));

      expect(csv, hasLength(2), reason: "header plus the one bad row");
      expect(csv[0].first, "row");
      expect(csv[0].last, "error");
      expect(csv[1].first, "3");
      expect(csv[1][1], "Q3");
      expect(csv[1].last, "Fill in option D");
    });
  });

  group('the view model', () {
    late MockQuestionRepo repo;
    late QuestionImportViewModel vm;

    setUp(() {
      repo = MockQuestionRepo();
      vm = QuestionImportViewModel(questionRepo: repo);
    });

    test('a good file ends in a preview, checking every code once', () async {
      when(() => repo.existingCodes(any())).thenAnswer((_) async => {"Q3"});

      await vm.loadFile(
          _csv("$_header\nQ1,One?,a,b,c,d,A\nQ1,Dup?,a,b,c,d,A\n"
              "Q3,Three?,a,b,c,d,A\nQ4,Four?,a,b,c,,A"),
          "q.csv");

      expect(vm.stage, ImportStage.preview);
      expect(vm.rows, hasLength(4));
      expect(vm.validRows.map((r) => r.code), ["Q1"]);
      expect(vm.invalidCount, 3);
      verify(() => repo.existingCodes(["Q1", "Q3", "Q4"])).called(1);
    });

    test('a broken file goes back to the start with the reason', () async {
      await vm.loadFile(_csv("question_code\nQ1"), "q.csv");

      expect(vm.stage, ImportStage.idle);
      expect(vm.error, contains("Missing"));
      verifyNever(() => repo.existingCodes(any()));
    });

    test('a failed code check is reported and nothing can be imported',
        () async {
      when(() => repo.existingCodes(any())).thenThrow(Exception("offline"));

      await vm.loadFile(_csv("$_header\nQ1,One?,a,b,c,d,A"), "q.csv");

      expect(vm.stage, ImportStage.idle);
      expect(vm.error, contains("Couldn't check"));
      expect(vm.rows, isEmpty);
    });

    test('importing writes only the ready rows, in sheet order', () async {
      when(() => repo.existingCodes(any())).thenAnswer((_) async => {});
      when(() => repo.addQuestions(any(), onProgress: any(named: 'onProgress')))
          .thenAnswer((invocation) async {
        final maps =
            invocation.positionalArguments.first as List<Map<String, dynamic>>;
        (invocation.namedArguments[#onProgress] as void Function(
            int))(maps.length);
      });

      await vm.loadFile(
          _csv(
              "$_header\nQ1,One?,a,b,c,d,A\nQ2,,a,b,c,d,A\nQ3,Three?,a,b,c,d,D"),
          "q.csv");
      await vm.importValid();

      final List<Map<String, dynamic>> written = verify(() => repo.addQuestions(
          captureAny(),
          onProgress: any(named: 'onProgress'))).captured.single;
      expect(written.map((m) => m["question_code"]), ["Q1", "Q3"]);
      expect(written[1]["answer"], "<p>d</p>");
      expect(written[1]["timeStamp"], greaterThan(written[0]["timeStamp"]),
          reason: "later rows are newer, so the list keeps the sheet's order");
      expect(vm.stage, ImportStage.done);
      expect(vm.importedCount, 2);
      expect(vm.error, isNull);
    });

    test('a failure part-way says how many made it', () async {
      when(() => repo.existingCodes(any())).thenAnswer((_) async => {});
      when(() => repo.addQuestions(any(), onProgress: any(named: 'onProgress')))
          .thenAnswer((invocation) async {
        (invocation.namedArguments[#onProgress] as void Function(int))(1);
        throw Exception("quota");
      });

      await vm.loadFile(
          _csv("$_header\nQ1,One?,a,b,c,d,A\nQ2,Two?,a,b,c,d,A"), "q.csv");
      await vm.importValid();

      expect(vm.stage, ImportStage.done);
      expect(vm.importedCount, 1);
      expect(vm.error, startsWith("Imported 1 of 2"));
    });

    test('nothing is written when no row is ready', () async {
      when(() => repo.existingCodes(any())).thenAnswer((_) async => {});

      await vm.loadFile(_csv("$_header\nQ1,,a,b,c,d,A"), "q.csv");
      await vm.importValid();

      expect(vm.stage, ImportStage.preview);
      verifyNever(
          () => repo.addQuestions(any(), onProgress: any(named: 'onProgress')));
    });
  });
}
