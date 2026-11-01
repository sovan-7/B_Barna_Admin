import 'dart:convert';

import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:csv/csv.dart';

/// One sheet row turned into a question, with whatever is wrong with it.
///
/// The rules are [QuestionDraft.validate]'s — the same ones the Add
/// Question form applies — plus the two only an import can break: a code
/// used twice in the file, and a code that already exists.
class QuestionImportRow {
  /// The cells as read, kept so a rejected row can be handed back.
  final SheetRow source;

  /// The question this row saves as.
  final QuestionDraft draft;

  /// Problems, in the order they should be read. Empty means ready.
  final List<String> errors;

  QuestionImportRow._(this.source, this.draft, this.errors);

  /// The row's number as the spreadsheet shows it.
  int get rowNumber => source.rowNumber;

  /// "Row 4" (sheet) or "Question 3" (Word document).
  String get label => source.label;

  /// The code as it will be stored (upper-case).
  String get code => draft.code.trim().toUpperCase();

  /// Whether this row will be imported.
  bool get isValid => errors.isEmpty;

  /// The question as one line of plain text, for the preview.
  String get preview => QuestionDraft.plainText(draft.question);
}

/// Builds and checks a row per sheet row. A code repeated in the file is
/// kept on its first row and reported on the later ones.
List<QuestionImportRow> buildImportRows(List<SheetRow> rows) {
  final Map<String, String> firstRowOfCode = {};
  return [
    for (final SheetRow row in rows) _build(row, firstRowOfCode),
  ];
}

/// Adds "already exists" to every row whose code is in [existing].
void markExistingCodes(List<QuestionImportRow> rows, Set<String> existing) {
  for (final QuestionImportRow row in rows) {
    if (row.code.isNotEmpty && existing.contains(row.code)) {
      row.errors.add("Code ${row.code} already exists");
    }
  }
}

QuestionImportRow _build(SheetRow row, Map<String, String> firstRowOfCode) {
  final List<String> options = [
    row["option_a"],
    row["option_b"],
    row["option_c"],
    row["option_d"],
  ];
  final String answerCell = row["answer"];
  final QuestionOption? answer = parseAnswer(answerCell, options);

  final QuestionDraft draft = QuestionDraft(
    code: row["question_code"],
    question: cellToHtml(row["question"]),
    questionBody: cellToHtml(row["question_body"]),
    optionA: cellToHtml(options[0]),
    optionB: cellToHtml(options[1]),
    optionC: cellToHtml(options[2]),
    optionD: cellToHtml(options[3]),
    hints: cellToHtml(row["hints"]),
    solution: cellToHtml(row["solution"]),
    answer: answer,
  );

  final Map<QuestionField, String> problems = draft.validate();
  // The form's wording assumes a picker; here the admin typed something.
  if (answer == null && answerCell.isNotEmpty) {
    problems[QuestionField.answer] =
        "Answer \"$answerCell\" must be A, B, C or D, or match an option";
  }
  final List<String> errors = problems.values.toList();

  final String code = draft.code.trim().toUpperCase();
  if (code.isNotEmpty) {
    final String? first = firstRowOfCode[code];
    if (first != null) {
      errors.add("Code $code is already used in ${first.toLowerCase()}");
    } else {
      firstRowOfCode[code] = row.label;
    }
  }
  return QuestionImportRow._(row, draft, errors);
}

/// Which option [answer] names: a letter (A–D), a number (1–4), or the
/// text of one of [options] (ignoring case and outer spaces). Null when it
/// names none.
QuestionOption? parseAnswer(String answer, List<String> options) {
  final String value = answer.trim().toLowerCase();
  if (value.isEmpty) return null;
  const Map<String, QuestionOption> byKey = {
    "a": QuestionOption.a,
    "b": QuestionOption.b,
    "c": QuestionOption.c,
    "d": QuestionOption.d,
    "1": QuestionOption.a,
    "2": QuestionOption.b,
    "3": QuestionOption.c,
    "4": QuestionOption.d,
    "ক": QuestionOption.a,
    "খ": QuestionOption.b,
    "গ": QuestionOption.c,
    "ঘ": QuestionOption.d,
  };
  final QuestionOption? keyed = byKey[value];
  if (keyed != null) return keyed;
  // "(D)", "D)" or "(D) the option's text", as written in a document.
  final RegExpMatch? bracketed = _bracketedAnswer.firstMatch(value);
  if (bracketed != null) {
    return byKey[bracketed.group(1) ?? bracketed.group(2)];
  }
  for (int i = 0; i < options.length; i++) {
    if (options[i].trim().toLowerCase() == value) {
      return QuestionOption.values[i];
    }
  }
  return null;
}

final RegExp _bracketedAnswer =
    RegExp(r'^(?:\(\s*([a-d1-4কখগঘ])\s*\)|([a-d1-4কখগঘ])\))');

/// A plain-text cell as the HTML the rich editors store: escaped, line
/// breaks kept, in one paragraph. An empty cell stays empty.
String cellToHtml(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) return "";
  const HtmlEscape escape = HtmlEscape(HtmlEscapeMode.element);
  return "<p>${trimmed.split('\n').map((line) => escape.convert(line.trim())).join('<br>')}</p>";
}

/// The columns, in the order the template lays them out.
const List<String> _templateColumns = [
  "question_code",
  "question",
  "question_body",
  "option_a",
  "option_b",
  "option_c",
  "option_d",
  "answer",
  "hints",
  "solution",
];

/// A CSV with the header row and one worked example, to fill in.
String templateCsv() => const ListToCsvConverter().convert([
      _templateColumns,
      [
        "Q101",
        "What is the capital of India?",
        "",
        "Mumbai",
        "New Delhi",
        "Kolkata",
        "Chennai",
        "B",
        "It is in the north.",
        "New Delhi has been the capital since 1931.",
      ],
    ]);

/// The rejected rows as a CSV the admin can fix and import again: the
/// original cells plus an `error` column explaining each.
String rejectedRowsCsv(List<QuestionImportRow> rows) =>
    const ListToCsvConverter().convert([
      ["row", ..._templateColumns, "error"],
      for (final QuestionImportRow row in rows)
        if (!row.isValid)
          [
            row.rowNumber,
            for (final String column in _templateColumns) row.source[column],
            row.errors.join("; "),
          ],
    ]);
