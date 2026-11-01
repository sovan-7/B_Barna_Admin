import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bbarna/question/import/question_import_row.dart';
import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// A .docx whose body is [paragraphs]; the lines inside one paragraph are
/// separated by `<w:br/>`, the way Word stores Shift+Enter.
Uint8List _docx(List<List<String>> paragraphs) {
  String escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  final String body = [
    for (final List<String> lines in paragraphs)
      '<w:p><w:r>${lines.map((l) => '<w:t xml:space="preserve">${escape(l)}</w:t>').join('<w:br/>')}</w:r></w:p>',
  ].join();
  final Archive archive = Archive()
    ..addFile(ArchiveFile.string(
        "word/document.xml",
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            '<w:body>$body</w:body></w:document>'));
  return ZipEncoder().encodeBytes(archive);
}

List<QuestionImportRow> _read(List<List<String>> paragraphs) =>
    buildImportRows(QuestionSheetParser.parse(_docx(paragraphs), "Q.DOCX"));

/// Two questions laid out exactly like "Demo QU.docx".
const List<List<String>> _demo = [
  [
    "XYZ1. পিয়াজের মতে শিশুর জ্ঞানীয় বিকাশের কোন স্তরে বিমূর্ত চিন্তন ক্ষমতার বিকাশ ঘটে?"
  ],
  [
    "(A) সংবেদন-সঞ্চালনমূলক স্তর",
    "(B) প্রাক্-সক্রিয়তামূলক স্তর",
    "(C) মূর্ত সক্রিয়তামূলক স্তর",
    "(D) আনুষ্ঠানিক সক্রিয়তামূলক স্তর",
  ],
  ["সঠিক উত্তর: (D)"],
  [
    "ব্যাখ্যা: জ্যাঁ পিয়াজের মতে, ১১ বছর বা তার পরবর্তী সময়ে আনুষ্ঠানিক সক্রিয়তামূলক স্তরের সূচনা হয়।"
  ],
  ["XYZ2. 'Zone of Proximal Development (ZPD)' ধারণাটি কে প্রবর্তন করেন?"],
  [
    "(A) জ্যাঁ পিয়াজে",
    "(B) লেভ ভাইগটস্কি",
    "(C) জেরোম ব্রুনার",
    "(D) বি. এফ. স্কিনার"
  ],
  ["সঠিক উত্তর: (B)"],
  ["ব্যাখ্যা: ভাইগটস্কির মতে, শিশু একা যে কাজ করতে পারে…"],
  [""],
];

void main() {
  test('reads the demo layout into ready questions', () {
    final rows = _read(_demo);

    expect(rows, hasLength(2));
    expect(rows.every((r) => r.isValid), isTrue,
        reason: rows.map((r) => r.errors).toString());

    final QuestionImportRow first = rows.first;
    expect(first.label, "Question 1");
    expect(first.code, "XYZ1");
    expect(first.preview, startsWith("পিয়াজের মতে"));
    expect(first.source["option_a"], "সংবেদন-সঞ্চালনমূলক স্তর");
    expect(first.source["option_d"], "আনুষ্ঠানিক সক্রিয়তামূলক স্তর");
    expect(first.draft.answer, QuestionOption.d);
    expect(first.draft.solution, startsWith("<p>জ্যাঁ পিয়াজের মতে"));

    expect(rows[1].code, "XYZ2");
    expect(rows[1].draft.answer, QuestionOption.b);
    expect(rows[1].source["option_d"], "বি. এফ. স্কিনার");
  });

  test('options may be separate paragraphs, or all on one line', () {
    final rows = _read([
      ["Q1. First?"],
      ["(A) one"],
      ["(B) two"],
      ["(C) three"],
      ["(D) four"],
      ["Answer: C"],
      ["Q2. Second?"],
      ["(A) w (B) x (C) y (D) z"],
      ["Ans: (D)"],
    ]);

    expect(rows.map((r) => r.isValid), [true, true]);
    expect(rows[0].source["option_c"], "three");
    expect(rows[0].draft.answer, QuestionOption.c);
    expect(rows[1].source["option_a"], "w");
    expect(rows[1].source["option_d"], "z");
    expect(rows[1].draft.answer, QuestionOption.d);
  });

  test('questions and explanations may run over several lines', () {
    final rows = _read([
      [
        "XYZ1. Read the statements:",
        "1. The sun is a star.",
        "2. The moon is a planet."
      ],
      ["Which is true?"],
      ["(A) Only 1", "(B) Only 2", "(C) Both", "(D) Neither"],
      ["সঠিক উত্তর: (A)"],
      ["ব্যাখ্যা: The sun is a star."],
      ["1. Stars make their own light.", "2. The moon reflects it."],
      ["XYZ2. Next?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["উত্তর: খ"],
    ]);

    expect(rows, hasLength(2),
        reason: "numbered lines inside a question are not new questions");
    expect(rows[0].preview,
        "Read the statements: 1. The sun is a star. 2. The moon is a planet. Which is true?");
    expect(rows[0].draft.solution,
        "<p>The sun is a star.<br>1. Stars make their own light.<br>2. The moon reflects it.</p>");
    expect(rows[1].draft.answer, QuestionOption.b);
  });

  test('plain numbers work when they count up', () {
    final rows = _read([
      ["1. First?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Answer: A"],
      ["Explanation: see the rule."],
      ["2. Second?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Answer: B"],
    ]);

    expect(rows.map((r) => r.code), ["1", "2"]);
    expect(rows.every((r) => r.isValid), isTrue);
  });

  test('Bengali option letters work', () {
    final rows = _read([
      ["XYZ9. প্রশ্ন?"],
      ["(ক) এক", "(খ) দুই", "(গ) তিন", "(ঘ) চার"],
      ["সঠিক উত্তর: (গ)"],
    ]);

    expect(rows.single.isValid, isTrue);
    expect(rows.single.source["option_b"], "দুই");
    expect(rows.single.draft.answer, QuestionOption.c);
  });

  test('a title before the first question is ignored', () {
    final rows = _read([
      ["Chapter 3 — Child development MCQ"],
      ["Answer every question."],
      ..._demo,
    ]);
    expect(rows, hasLength(2));
    expect(rows.first.preview, startsWith("পিয়াজের মতে"));
  });

  test('a hint line is kept', () {
    final rows = _read([
      ["XYZ1. Q?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Hint: think small"],
      ["Answer: A"],
    ]);
    expect(rows.single.draft.hints, "<p>think small</p>");
  });

  test('a missing option is a problem with that question only', () {
    final rows = _read([
      ["XYZ1. Q?"],
      ["(A) a", "(B) b", "(D) d"],
      ["সঠিক উত্তর: (A)"],
      ["XYZ2. Q?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["সঠিক উত্তর: (Z)"],
      ["XYZ1. Again?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["সঠিক উত্তর: (A)"],
    ]);

    expect(rows[0].errors, ["Fill in option C"]);
    expect(rows[1].errors,
        ['Answer "(Z)" must be A, B, C or D, or match an option']);
    expect(rows[2].errors, ["Code XYZ1 is already used in question 1"]);
  });

  test('a document with no questions is refused, explaining the layout', () {
    expect(
      () => QuestionSheetParser.parse(
          _docx([
            ["Just some notes"]
          ]),
          "notes.docx"),
      throwsA(isA<QuestionSheetException>()
          .having((e) => e.message, 'message', contains("XYZ1."))),
    );
  });

  test('something that is not a Word document is refused', () {
    final Uint8List zip = ZipEncoder()
        .encodeBytes(Archive()..addFile(ArchiveFile.string("a.txt", "hi")));
    expect(() => QuestionSheetParser.parse(zip, "q.docx"),
        throwsA(isA<QuestionSheetException>()));
    expect(
        () =>
            QuestionSheetParser.parse(Uint8List.fromList([1, 2, 3]), "q.docx"),
        throwsA(isA<QuestionSheetException>()));
  });

  test('an old .doc gets a save-as hint', () {
    expect(
      () => QuestionSheetParser.parse(Uint8List(0), "old.doc"),
      throwsA(isA<QuestionSheetException>()
          .having((e) => e.message, 'message', contains(".docx"))),
    );
  });

  test('answers written as in documents', () {
    const options = ["a", "b", "c", "d"];
    expect(parseAnswer("(D)", options), QuestionOption.d);
    expect(parseAnswer("( b )", options), QuestionOption.b);
    expect(parseAnswer("C)", options), QuestionOption.c);
    expect(parseAnswer("(A) a", options), QuestionOption.a);
    expect(parseAnswer("ঘ", options), QuestionOption.d);
    expect(parseAnswer("(ক)", options), QuestionOption.a);
    expect(parseAnswer("(E)", options), isNull);
  });
}
