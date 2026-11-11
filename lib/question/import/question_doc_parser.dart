import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:xml/xml.dart';

/// Reads questions written as plain text blocks in a Word (.docx) file:
///
/// ```
/// XYZ1. Question text…    ← the full stop after the code is optional
/// BODY-                   ← optional; or BODY: / Body- (see below)
/// A. first statement
/// B. second statement
/// (A) first option        ← or A) / A. / (ক) …; one paragraph or several
/// (B) second option
/// (C) third option
/// (D) fourth option
/// সঠিক উত্তর: (D)          ← or উত্তর: / Answer: / Ans:
/// ব্যাখ্যা: Why…           ← or Explanation: / Solution:  (optional)
/// সংকেত: Hint…             ← or Hint:                     (optional)
/// ```
///
/// Lines after a BODY marker — on a line of its own, or "BODY-" at the end
/// of the question line — are statements, match-the-column rows or a
/// passage. Up to the first "(A)" line they are saved as the question's
/// body (shown under it), so "A." / "a)" statements there are not taken
/// for options.
///
/// Each block comes out as a [SheetRow] with the same columns a sheet has,
/// so validation and import treat both the same. Pure Dart, no Firebase.
class QuestionDocParser {
  const QuestionDocParser._();

  /// Parses a .docx file. Throws [QuestionSheetException] when it is not a
  /// Word document, holds no question, or holds more than [maxImportRows].
  static List<SheetRow> parse(Uint8List bytes) {
    final List<String> lines = _lines(_documentXml(bytes));
    final List<String?> nextPrefix = _nextLetterPrefixes(lines);

    final List<_Block> blocks = [];
    _Block? current;
    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];
      final _Start? start = _questionStart(
          line, blocks.isEmpty ? null : blocks.first, current, nextPrefix[i]);
      if (start != null) {
        current = _Block(start.code, start.number, start.prefix)
          ..takeQuestion(start.text);
        blocks.add(current);
        continue;
      }
      // Anything before the first question (a title, instructions) is not
      // part of any question.
      current?.take(line);
    }

    if (blocks.isEmpty) {
      throw const QuestionSheetException(
          "No questions found. Each question should start with its code, "
          "like \"XYZ1. …\", followed by (A)–(D) options and a "
          "\"সঠিক উত্তর: (B)\" or \"Answer: B\" line.");
    }
    if (blocks.length > maxImportRows) {
      throw QuestionSheetException(
          "The document has ${blocks.length} questions. Import at most "
          "$maxImportRows at a time — split it into smaller files.");
    }
    return [
      for (int i = 0; i < blocks.length; i++)
        SheetRow(i + 1, blocks[i].cells(),
            label: "Question ${i + 1}", problems: blocks[i].problems),
    ];
  }

  // ---- Reading the document -------------------------------------------------

  static XmlDocument _documentXml(Uint8List bytes) {
    final ArchiveFile? file;
    try {
      file = ZipDecoder().decodeBytes(bytes).findFile("word/document.xml");
    } catch (_) {
      throw const QuestionSheetException(
          "That file could not be opened as a Word document.");
    }
    if (file == null) {
      throw const QuestionSheetException("That file is not a Word document.");
    }
    try {
      return XmlDocument.parse(utf8.decode(file.content, allowMalformed: true));
    } catch (_) {
      throw const QuestionSheetException(
          "That Word document could not be read.");
    }
  }

  /// Every non-empty line of text, in reading order. A paragraph is a line;
  /// a line break inside one starts another.
  static List<String> _lines(XmlDocument doc) {
    final List<String> lines = [];
    for (final XmlElement paragraph
        in doc.descendantElements.where((e) => e.name.local == "p")) {
      final StringBuffer text = StringBuffer();
      for (final XmlElement node in paragraph.descendantElements) {
        switch (node.name.local) {
          case "t":
            text.write(node.innerText);
          case "tab":
            text.write(" ");
          case "br":
          case "cr":
            text.write("\n");
        }
      }
      for (final String line in text.toString().split("\n")) {
        final String trimmed = line.trim();
        if (trimmed.isNotEmpty) lines.add(trimmed);
      }
    }
    return lines;
  }

  // ---- Recognising lines ----------------------------------------------------

  /// "XYZ12. text" / "Q3) text" / "7। text": a code ending in digits.
  static final RegExp _startPattern =
      RegExp(r'^([A-Za-z][A-Za-z0-9_-]*?|)(\d+)\s*[.)।:]\s*(.*)$');

  /// "XYZ12 text": a lettered code without a full stop. Plain numbers keep
  /// needing theirs — "2 প্রকার…" is far more likely a sentence than a code.
  static final RegExp _bareStartPattern =
      RegExp(r'^([A-Za-z][A-Za-z0-9_-]*?)(\d+)\s+(\S.*)$');

  /// For each line, the letters (upper-cased) of the next lettered code
  /// below it — "XYZ" for "XYZ7 …" — or null when none follows.
  static List<String?> _nextLetterPrefixes(List<String> lines) {
    final List<String?> next = List<String?>.filled(lines.length, null);
    String? below;
    for (int i = lines.length - 1; i >= 0; i--) {
      next[i] = below;
      final RegExpMatch? code = _startPattern.firstMatch(lines[i]) ??
          _bareStartPattern.firstMatch(lines[i]);
      final String prefix = code?.group(1) ?? "";
      if (prefix.isNotEmpty) below = prefix.toUpperCase();
    }
    return next;
  }

  /// Whether [line] begins a new question.
  ///
  /// Numbered lines also appear *inside* questions ("1. statement…") and
  /// explanations, so after the first question only lines in its style
  /// count: the same letter prefix (XYZ…), with or without a full stop, or
  /// — for plain numbers — the next number, once the current question has
  /// its options.
  ///
  /// Before the first question, a code without a full stop may as well be
  /// a title ("SLST2025 Practice Set"), so it counts only when the next
  /// lettered code ([nextPrefix]) has the same letters.
  static _Start? _questionStart(
      String line, _Block? first, _Block? current, String? nextPrefix) {
    final RegExpMatch? separated = _startPattern.firstMatch(line);
    final RegExpMatch? match = separated ?? _bareStartPattern.firstMatch(line);
    if (match == null) return null;
    final String prefix = match.group(1)!;
    final int number = int.tryParse(match.group(2)!) ?? -1;
    final _Start start =
        _Start("$prefix${match.group(2)!}", prefix, number, match.group(3)!);

    if (first == null || current == null) {
      return separated != null || prefix.toUpperCase() == nextPrefix
          ? start
          : null;
    }
    if (first.prefix.isNotEmpty) {
      return prefix.toUpperCase() == first.prefix.toUpperCase() ? start : null;
    }
    if (prefix.isNotEmpty) return null;
    return number == current.number + 1 && current.hasOption ? start : null;
  }
}

/// A recognised question start.
class _Start {
  final String code;
  final String prefix;
  final int number;
  final String text;
  const _Start(this.code, this.prefix, this.number, this.text);
}

/// The part of a question a line belongs to.
enum _Part {
  question,
  body,
  optionA,
  optionB,
  optionC,
  optionD,
  answer,
  solution,
  hints
}

/// One question being collected.
class _Block {
  final String code;
  final int number;
  final String prefix;
  final Map<_Part, List<String>> _text = {};

  /// Where an unlabelled line goes (the part above it).
  _Part _last = _Part.question;

  /// Options and the answer given so far by a labelled line ("(A) …",
  /// "সঠিক উত্তর: …").
  final Set<_Part> _labelled = {};

  /// Those labelled a second time. Usually the next question's code was
  /// not recognised, or statements were written without a BODY- line;
  /// either way the block is reported rather than quietly merged.
  final Set<_Part> _repeated = {};

  _Block(this.code, this.number, this.prefix);

  bool get hasOption => const [
        _Part.optionA,
        _Part.optionB,
        _Part.optionC,
        _Part.optionD
      ].any(_text.containsKey);

  /// What is wrong with how the block is written.
  List<String> get problems {
    final List<String> letters = [
      for (final MapEntry<_Part, String> option in _optionLetters.entries)
        if (_repeated.contains(option.key)) option.value,
    ];
    return [
      if (letters.isNotEmpty)
        "${letters.length == 1 ? "Option" : "Options"} ${letters.join(", ")} "
            "${letters.length == 1 ? "appears" : "appear"} more than once — "
            "check that each question starts with its code, and put "
            "statements or columns after a BODY- line",
      if (_repeated.contains(_Part.answer))
        "More than one answer line — check that each question starts with "
            "its code",
    ];
  }

  void append(_Part part, String text) {
    _last = part;
    if (text.trim().isEmpty) return;
    (_text[part] ??= []).add(text.trim());
  }

  /// Question text: the start line, or an unlabelled line under it. A
  /// "BODY-" in it ends the question; the rest is body.
  void takeQuestion(String text) {
    final RegExpMatch? marker = _bodyInQuestion.firstMatch(text);
    if (marker == null) return append(_Part.question, text);
    append(_Part.question, text.substring(0, marker.start));
    append(_Part.body, text.substring(marker.end));
  }

  /// "(A) x (B) y" on one line is split into its options.
  static final RegExp _inlineOption = RegExp(r'\s+(?=\(\s*[B-Db-dখগঘ]\s*\)\s)');

  static final RegExp _option = RegExp(
      r'^(?:\(\s*([A-Da-dকখগঘ])\s*\)|([A-Da-dকখগঘ])\)|([A-D])\.\s)\s*(.*)$');

  static final RegExp _answer = RegExp(
      r'^(?:সঠিক\s*উত্তর|উত্তর|correct\s*answer|answer|ans)\s*[:：\-–]\s*(.*)$',
      caseSensitive: false);

  static final RegExp _solution = RegExp(
      r'^(?:ব্যাখ্যা|সমাধান|explanation|solution)\s*[:：\-–]\s*(.*)$',
      caseSensitive: false);

  static final RegExp _hint =
      RegExp(r'^(?:সংকেত|hint)\s*[:：\-–]\s*(.*)$', caseSensitive: false);

  /// "BODY-", "Body:" or "BODY: text…" on a line of its own, in any case.
  static final RegExp _bodyLabel =
      RegExp(r'^body\s*(?:[:：\-–—]\s*(.*))?$', caseSensitive: false);

  /// "… BODY-" within a question line. Capitals only, so a question that
  /// mentions the human body is left alone.
  static final RegExp _bodyInQuestion = RegExp(r'(?:^|\s+)BODY\s*[:：\-–—]\s*');

  /// What ends a body: a bracketed capital option, "(A)" or "(ক)".
  static final RegExp _bodyEnd = RegExp(r'^\(\s*[A-Dকখগঘ]\s*\)');

  static const Map<String, _Part> _optionParts = {
    "a": _Part.optionA,
    "b": _Part.optionB,
    "c": _Part.optionC,
    "d": _Part.optionD,
    "ক": _Part.optionA,
    "খ": _Part.optionB,
    "গ": _Part.optionC,
    "ঘ": _Part.optionD,
  };

  static const Map<_Part, String> _optionLetters = {
    _Part.optionA: "A",
    _Part.optionB: "B",
    _Part.optionC: "C",
    _Part.optionD: "D",
  };

  /// Files [line] under the part it names, or the part above it.
  void take(String line) {
    RegExpMatch? match;
    if ((match = _answer.firstMatch(line)) != null) {
      _label(_Part.answer);
      append(_Part.answer, match!.group(1)!);
      // Anything after the answer that is not labelled explains it.
      _last = _Part.solution;
      return;
    }
    if ((match = _solution.firstMatch(line)) != null) {
      return append(_Part.solution, match!.group(1)!);
    }
    if ((match = _hint.firstMatch(line)) != null) {
      return append(_Part.hints, match!.group(1)!);
    }
    if ((match = _bodyLabel.firstMatch(line)) != null) {
      return append(_Part.body, match!.group(1) ?? "");
    }
    // Statements and columns in a body often look like options ("A. …",
    // "a) …"), so only "(A)" ends it.
    if (_last == _Part.body && !_bodyEnd.hasMatch(line)) {
      return append(_Part.body, line);
    }
    if (_option.hasMatch(line)) {
      for (final String piece in line.split(_inlineOption)) {
        final RegExpMatch? option = _option.firstMatch(piece);
        if (option == null) {
          append(_last, piece);
          continue;
        }
        final String letter =
            (option.group(1) ?? option.group(2) ?? option.group(3))!;
        final _Part part = _optionParts[letter.toLowerCase()]!;
        _label(part);
        append(part, option.group(4)!);
      }
      return;
    }
    if (_last == _Part.question) return takeQuestion(line);
    append(_last, line);
  }

  /// Records that a label gave [part], noting when one already had.
  void _label(_Part part) {
    if (!_labelled.add(part)) _repeated.add(part);
  }

  /// The block as sheet columns.
  Map<String, String> cells() {
    String joined(_Part part) => (_text[part] ?? const []).join("\n");
    return {
      "question_code": code,
      "question": joined(_Part.question),
      "question_body": joined(_Part.body),
      "option_a": joined(_Part.optionA),
      "option_b": joined(_Part.optionB),
      "option_c": joined(_Part.optionC),
      "option_d": joined(_Part.optionD),
      "answer": joined(_Part.answer),
      "solution": joined(_Part.solution),
      "hints": joined(_Part.hints),
    };
  }
}
