import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bbarna/question/import/question_doc_parser.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';

/// Columns a question sheet must have (lower-case; headers are matched
/// case-insensitively).
const List<String> requiredQuestionColumns = [
  "question_code",
  "question",
  "option_a",
  "option_b",
  "option_c",
  "option_d",
  "answer",
];

/// Columns a question sheet may have.
const List<String> optionalQuestionColumns = [
  "question_body",
  "hints",
  "solution",
];

/// Most data rows one file may hold. Keeps a single import reviewable and
/// well inside what a browser tab handles comfortably.
const int maxImportRows = 500;

/// Why a whole file could not be read (as opposed to one bad row).
class QuestionSheetException implements Exception {
  /// Shown to the admin as is.
  final String message;
  const QuestionSheetException(this.message);

  @override
  String toString() => message;
}

/// One data row of the sheet.
class SheetRow {
  /// The row's number as the spreadsheet shows it (the header is row 1),
  /// or the question's position in a Word document.
  final int rowNumber;

  /// Cell text by lower-cased column name, trimmed. Missing cells are "".
  final Map<String, String> cells;

  /// How the admin finds it again: "Row 4" in a sheet, "Question 3" in a
  /// Word document.
  final String label;

  SheetRow(this.rowNumber, this.cells, {String? label})
      : label = label ?? "Row $rowNumber";

  /// The cell in [column], or "" when there is none.
  String operator [](String column) => cells[column] ?? "";
}

/// Reads a question sheet (.csv or .xlsx) into rows keyed by column name.
///
/// Pure Dart with no Firebase, so it can be tested on its own. The `excel`
/// package cannot be used here (it pins `archive` 3, while `image` needs
/// 4), so .xlsx is read directly: it is a zip of XML parts.
class QuestionSheetParser {
  const QuestionSheetParser._();

  /// Parses [bytes]; [fileName]'s extension picks the format.
  ///
  /// Throws [QuestionSheetException] when the file cannot be used at all:
  /// an unknown type, unreadable content, missing columns, no rows, or more
  /// than [maxImportRows] rows. Fully blank rows are skipped.
  static List<SheetRow> parse(Uint8List bytes, String fileName) {
    final String name = fileName.toLowerCase();
    final List<List<String>> table;
    if (name.endsWith(".docx")) {
      return QuestionDocParser.parse(bytes);
    } else if (name.endsWith(".csv")) {
      table = _readCsv(bytes);
    } else if (name.endsWith(".xlsx")) {
      table = _readXlsx(bytes);
    } else if (name.endsWith(".doc") || name.endsWith(".xls")) {
      throw QuestionSheetException(
          "That is an old ${name.endsWith(".doc") ? "Word" : "Excel"} "
          "format. Open it and save as "
          "${name.endsWith(".doc") ? ".docx" : ".xlsx"} first.");
    } else {
      throw const QuestionSheetException("Choose a .docx, .xlsx or .csv file.");
    }
    return _toRows(table);
  }

  /// Header plus rows → [SheetRow]s, checking the columns.
  static List<SheetRow> _toRows(List<List<String>> table) {
    final int headerIndex = table.indexWhere(_hasText);
    if (headerIndex == -1) {
      throw const QuestionSheetException("The file is empty.");
    }
    final List<String> header = [
      for (final String cell in table[headerIndex]) cell.trim().toLowerCase(),
    ];

    final List<String> missing = [
      for (final String column in requiredQuestionColumns)
        if (!header.contains(column)) column,
    ];
    if (missing.isNotEmpty) {
      throw QuestionSheetException(
          "The first row must name the columns. Missing: "
          "${missing.join(", ")}. Download the template to see the layout.");
    }

    final List<SheetRow> rows = [];
    for (int i = headerIndex + 1; i < table.length; i++) {
      final List<String> cells = table[i];
      if (!_hasText(cells)) continue;
      rows.add(SheetRow(i + 1, {
        for (int c = 0; c < header.length; c++)
          if (header[c].isNotEmpty)
            header[c]: c < cells.length ? cells[c].trim() : "",
      }));
    }

    if (rows.isEmpty) {
      throw const QuestionSheetException(
          "The file has a header row but no questions under it.");
    }
    if (rows.length > maxImportRows) {
      throw QuestionSheetException(
          "The file has ${rows.length} questions. Import at most "
          "$maxImportRows at a time — split it into smaller files.");
    }
    return rows;
  }

  static bool _hasText(List<String> cells) =>
      cells.any((cell) => cell.trim().isNotEmpty);

  // ---- CSV ----------------------------------------------------------------

  static List<List<String>> _readCsv(Uint8List bytes) {
    String text = utf8.decode(bytes, allowMalformed: true);
    // Excel's "CSV UTF-8" starts with a byte-order mark, which would
    // otherwise end up glued to the first header name.
    if (text.startsWith('﻿')) text = text.substring(1);
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final List<List<dynamic>> parsed =
        const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
            .convert(text);
    return [
      for (final List<dynamic> row in parsed)
        [for (final dynamic cell in row) cell.toString()],
    ];
  }

  // ---- XLSX ---------------------------------------------------------------

  static List<List<String>> _readXlsx(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const QuestionSheetException(
          "That file could not be opened as an Excel workbook.");
    }

    final List<String> shared = _sharedStrings(archive);
    final XmlDocument? sheet = _xml(archive, _firstSheetPath(archive));
    if (sheet == null) {
      throw const QuestionSheetException("That workbook has no sheet to read.");
    }

    final List<List<String>> table = [];
    for (final XmlElement row in sheet.findAllElements("row")) {
      // Rows and cells may be sparse: positions come from their `r`
      // attributes when present, otherwise from their order.
      final int rowIndex =
          (int.tryParse(row.getAttribute("r") ?? "") ?? table.length + 1) - 1;
      while (table.length < rowIndex) {
        table.add(<String>[]);
      }
      final List<String> cells = [];
      for (final XmlElement cell in row.findElements("c")) {
        final int column = _columnIndex(cell.getAttribute("r")) ?? cells.length;
        while (cells.length < column) {
          cells.add("");
        }
        cells.add(_cellText(cell, shared));
      }
      table.add(cells);
    }
    return table;
  }

  /// The first sheet's part path, following the workbook's relationships;
  /// `sheet1.xml` when they cannot be followed.
  static String _firstSheetPath(Archive archive) {
    const String fallback = "xl/worksheets/sheet1.xml";
    final XmlDocument? workbook = _xml(archive, "xl/workbook.xml");
    final XmlDocument? rels = _xml(archive, "xl/_rels/workbook.xml.rels");
    final XmlElement? first = workbook?.findAllElements("sheet").firstOrNull;
    if (first == null || rels == null) return fallback;

    final String? id = first.attributes
        .where((a) => a.name.local == "id")
        .map((a) => a.value)
        .firstOrNull;
    final String? target = rels
        .findAllElements("Relationship")
        .where((r) => r.getAttribute("Id") == id)
        .map((r) => r.getAttribute("Target"))
        .firstOrNull;
    if (target == null) return fallback;
    return target.startsWith("/") ? target.substring(1) : "xl/$target";
  }

  /// The workbook's shared string table (most text cells point into it).
  static List<String> _sharedStrings(Archive archive) {
    final XmlDocument? doc = _xml(archive, "xl/sharedStrings.xml");
    if (doc == null) return const [];
    return [
      for (final XmlElement item in doc.findAllElements("si")) _textOf(item),
    ];
  }

  static String _cellText(XmlElement cell, List<String> shared) {
    final String type = cell.getAttribute("t") ?? "";
    if (type == "inlineStr") {
      final XmlElement? inline = cell.getElement("is");
      return inline == null ? "" : _textOf(inline);
    }
    final String value = cell.getElement("v")?.innerText ?? "";
    if (type == "s") {
      final int? index = int.tryParse(value);
      return index != null && index < shared.length ? shared[index] : "";
    }
    if (type == "b") return value == "1" ? "TRUE" : "FALSE";
    return value;
  }

  /// All `<t>` text inside [element] (rich text is split into runs).
  static String _textOf(XmlElement element) =>
      element.findAllElements("t").map((t) => t.innerText).join();

  /// "C12" → 2 (zero-based column).
  static int? _columnIndex(String? reference) {
    if (reference == null) return null;
    int index = 0;
    int letters = 0;
    for (final int unit in reference.toUpperCase().codeUnits) {
      if (unit < 65 || unit > 90) break;
      index = index * 26 + (unit - 64);
      letters++;
    }
    return letters == 0 ? null : index - 1;
  }

  static XmlDocument? _xml(Archive archive, String path) {
    final ArchiveFile? file = archive.findFile(path);
    if (file == null) return null;
    try {
      return XmlDocument.parse(utf8.decode(file.content, allowMalformed: true));
    } catch (_) {
      return null;
    }
  }
}
