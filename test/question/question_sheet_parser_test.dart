import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const String _header =
    "question_code,question,option_a,option_b,option_c,option_d,answer";

Uint8List _csv(String text) => Uint8List.fromList(utf8.encode(text));

/// A minimal .xlsx: the parts the parser reads, nothing else. The sheet is
/// deliberately not called sheet1.xml, so following the workbook's
/// relationships is what finds it.
Uint8List _xlsx(String sheetRows, {List<String> shared = const []}) {
  final Archive archive = Archive()
    ..addFile(ArchiveFile.string(
        "xl/workbook.xml",
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="Questions" sheetId="1" r:id="rId7"/></sheets></workbook>'))
    ..addFile(ArchiveFile.string(
        "xl/_rels/workbook.xml.rels",
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId7" Target="worksheets/questions.xml"/></Relationships>'))
    ..addFile(ArchiveFile.string("xl/sharedStrings.xml",
        '<sst>${shared.map((s) => "<si><t>$s</t></si>").join()}</sst>'))
    ..addFile(ArchiveFile.string("xl/worksheets/questions.xml",
        '<worksheet><sheetData>$sheetRows</sheetData></worksheet>'));
  return ZipEncoder().encodeBytes(archive);
}

String _inline(String ref, String text) =>
    '<c r="$ref" t="inlineStr"><is><t>$text</t></is></c>';

void main() {
  group('csv', () {
    test('reads rows keyed by column, numbered as the sheet shows them', () {
      final rows = QuestionSheetParser.parse(
          _csv("$_header\nQ1,Two plus two?,3,4,5,6,B\n"), "q.csv");

      expect(rows, hasLength(1));
      expect(rows.single.rowNumber, 2);
      expect(rows.single["question_code"], "Q1");
      expect(rows.single["option_b"], "4");
      expect(rows.single["answer"], "B");
    });

    test('quoted cells keep their commas, quotes and line breaks', () {
      final rows = QuestionSheetParser.parse(
          _csv(
              '$_header\r\nQ1,"Pick one, carefully","say ""hi""","line 1\r\nline 2",c,d,A\r\n'),
          "q.csv");

      expect(rows.single["question"], "Pick one, carefully");
      expect(rows.single["option_a"], 'say "hi"');
      expect(rows.single["option_b"], "line 1\nline 2");
    });

    test('a byte-order mark does not spoil the first header', () {
      final rows =
          QuestionSheetParser.parse(_csv("﻿$_header\nQ1,Q,a,b,c,d,A"), "q.csv");
      expect(rows.single["question_code"], "Q1");
    });

    test('headers match in any case and any order; extras are kept', () {
      final rows = QuestionSheetParser.parse(
          _csv("ANSWER,Option_D,option_c,option_b,option_a,Question,"
              "Question_Code,Solution\nC,d,c,b,a,Q?,Q9,Because."),
          "q.csv");
      expect(rows.single["question_code"], "Q9");
      expect(rows.single["answer"], "C");
      expect(rows.single["solution"], "Because.");
      expect(rows.single["hints"], "", reason: "missing optional column");
    });

    test('numbers are kept as written', () {
      final rows = QuestionSheetParser.parse(
          _csv("$_header\n007,Q,1.50,2,3,4,2"), "q.csv");
      expect(rows.single["question_code"], "007");
      expect(rows.single["option_a"], "1.50");
    });

    test('blank rows are skipped but row numbers still line up', () {
      final rows = QuestionSheetParser.parse(
          _csv("$_header\n\n,,,,,,\nQ1,Q,a,b,c,d,A"), "q.csv");
      expect(rows.single.rowNumber, 4);
    });

    test('a missing column fails the whole file, naming it', () {
      expect(
        () => QuestionSheetParser.parse(
            _csv("question_code,question,option_a,option_b,answer\nQ1,Q,a,b,A"),
            "q.csv"),
        throwsA(isA<QuestionSheetException>().having(
            (e) => e.message, 'message', contains("option_c, option_d"))),
      );
    });

    test('a header with no rows under it is refused', () {
      expect(() => QuestionSheetParser.parse(_csv(_header), "q.csv"),
          throwsA(isA<QuestionSheetException>()));
    });

    test('an empty file is refused', () {
      expect(() => QuestionSheetParser.parse(_csv(""), "q.csv"),
          throwsA(isA<QuestionSheetException>()));
    });

    test('more than the limit is refused', () {
      final String body =
          List.generate(maxImportRows + 1, (i) => "Q$i,Q,a,b,c,d,A").join("\n");
      expect(
        () => QuestionSheetParser.parse(_csv("$_header\n$body"), "q.csv"),
        throwsA(isA<QuestionSheetException>()
            .having((e) => e.message, 'message', contains("$maxImportRows"))),
      );
    });

    test('exactly the limit is fine', () {
      final String body =
          List.generate(maxImportRows, (i) => "Q$i,Q,a,b,c,d,A").join("\n");
      expect(QuestionSheetParser.parse(_csv("$_header\n$body"), "q.csv"),
          hasLength(maxImportRows));
    });
  });

  group('xlsx', () {
    test('reads shared, inline and number cells from the first sheet', () {
      final List<String> columns = _header.split(",");
      final String headerRow = '<row r="1">'
          '${[
        for (int i = 0; i < columns.length; i++)
          _inline("${String.fromCharCode(65 + i)}1", columns[i])
      ].join()}</row>';
      final String dataRow = '<row r="2">'
          '<c r="A2" t="s"><v>0</v></c>'
          '<c r="B2" t="s"><v>1</v></c>'
          '<c r="C2"><v>3</v></c>'
          '${_inline("D2", "4")}'
          '${_inline("E2", "5")}'
          '${_inline("F2", "6")}'
          '${_inline("G2", "B")}'
          '</row>';

      final rows = QuestionSheetParser.parse(
          _xlsx(headerRow + dataRow, shared: ["Q1", "What is 2 + 2?"]),
          "Questions.XLSX");

      expect(rows.single.rowNumber, 2);
      expect(rows.single["question_code"], "Q1");
      expect(rows.single["question"], "What is 2 + 2?");
      expect(rows.single["option_a"], "3");
      expect(rows.single["option_b"], "4");
      expect(rows.single["answer"], "B");
    });

    test('skipped cells and rows land in the right place', () {
      final List<String> columns = _header.split(",");
      final String headerRow = '<row r="1">'
          '${[
        for (int i = 0; i < columns.length; i++)
          _inline("${String.fromCharCode(65 + i)}1", columns[i])
      ].join()}</row>';
      // Row 2 is absent; row 3 has nothing in column B or C.
      final String dataRow = '<row r="3">'
          '${_inline("A3", "Q2")}${_inline("D3", "b")}${_inline("G3", "A")}'
          '</row>';

      final rows =
          QuestionSheetParser.parse(_xlsx(headerRow + dataRow), "q.xlsx");

      expect(rows.single.rowNumber, 3);
      expect(rows.single["question_code"], "Q2");
      expect(rows.single["question"], "");
      expect(rows.single["option_b"], "b");
      expect(rows.single["answer"], "A");
    });

    test('something that is not a workbook is refused', () {
      expect(() => QuestionSheetParser.parse(_csv("not a zip"), "q.xlsx"),
          throwsA(isA<QuestionSheetException>()));
    });
  });

  test('other file types are refused', () {
    expect(() => QuestionSheetParser.parse(_csv(_header), "q.xls"),
        throwsA(isA<QuestionSheetException>()));
  });
}
