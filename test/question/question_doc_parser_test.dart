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

/// XYZ6–XYZ10 of "Demo QU.docx": codes without a full stop, and statement
/// or match-the-column lists after a BODY marker that follows the question
/// after a line break.
const List<List<String>> _demoBody = [
  ["XYZ6 নিচের দেওয়া বিবৃতিগুলি শুদ্ধ না অশুদ্ধ তা বিচার করো।", "BODY-"],
  [
    "A. বামনাচার্য গুণের সঙ্গে রীতির সম্পর্কের কথা বলেছেন।",
    "B. আচার্য আনন্দবর্ধন জানিয়েছেন, রীতির অঞ্চলভিত্তিক নামকরণ হওয়ায় রীতি সীমিত হয়ে পড়েছিল।",
    "C. বামন রীতিকে তখনই আত্মা বলেছেন, যখন রীতির আত্মা হয় গুণ।",
    "D. কুন্তক বামনাচার্যের স্বীকৃত রীতির সঙ্গে গুণের নিবিড় সম্পর্ক স্বীকার করেছেন।",
    "E. কুন্তক বলেছেন রসসৃষ্টিতে রীতির সার্থকতা দ্যোতিত করায় রসের সঙ্গে রীতির সম্পর্কও গড়ে উঠেছে।",
  ],
  [
    "(A) A-শুদ্ধ, B-অশুদ্ধ, C-শুদ্ধ, D-অশুদ্ধ, E-শুদ্ধ",
    "(B) A-অশুদ্ধ, B-শুদ্ধ, C-শুদ্ধ, D-শুদ্ধ, E-অশুদ্ধ",
    "(C) A-অশুদ্ধ, B-শুদ্ধ, C-অশুদ্ধ, D-অশুদ্ধ, E-শুদ্ধ",
    "(D) A-অশুদ্ধ, B-অশুদ্ধ, C-শুদ্ধ, D-শুদ্ধ, E-শুদ্ধ",
  ],
  ["সঠিক উত্তর: (D)"],
  ["ব্যাখ্যা: A ও B অশুদ্ধ … C, D ও E শুদ্ধ।"],
  [""],
  ["XYZ7 ভারতীয় অলংকারশাস্ত্র থেকে স্তম্ভ মিল করো।", "Body-"],
  [
    "'ক' স্তম্ভ — 'খ' স্তম্ভ",
    "A. ভট্টলোল্লট — 1. ন্যায় দর্শন",
    "B. ভট্টশঙ্কুক — 2. বেদান্ত-দর্শন",
    "C. ভট্টনায়ক — 3. সাংখ্য দর্শন",
    "D. অভিনবগুপ্ত — 4. পূর্ব মীমাংসা",
  ],
  [
    "(A) A>2, B>3, C>4, D>1",
    "(B) A>4, B>1, C>3, D>2",
    "(C) A>1, B>2, C>3, D>4",
    "(D) A>3, B>4, C>1, D>2",
  ],
  ["সঠিক উত্তর: (B)"],
  ["XYZ8 নিচের দেওয়া বিবৃতিগুলির শুদ্ধতা বিচার করো।", "BODY-"],
  [
    "a) 'গুণীভূত ব্যঙ্গ্য' শব্দটির প্রবর্তক আনন্দবর্ধন।",
    "b) 'ধ্বন্যালোক'-এর পদ সংখ্যা ১১৬।",
    "c) ধ্বনির মূল কথা ব্যঙ্গ্যার্থ।",
    "d) লক্ষণা শক্তি ২ প্রকার।",
  ],
  [
    "(A) a এবং b শুদ্ধ, c এবং d অশুদ্ধ",
    "(B) a এবং b অশুদ্ধ, c এবং d শুদ্ধ",
    "(C) a এবং b শুদ্ধ, c এবং d শুদ্ধ",
    "(D) a এবং b অশুদ্ধ, c এবং d অশুদ্ধ",
  ],
  ["সঠিক উত্তর: (C)"],
  ["ব্যাখ্যা: চারটি বিবৃতিই শুদ্ধ।"],
  [""],
  ["XYZ9. 'অলংকারশাস্ত্র' থেকে বিবৃতি দেওয়া হল, সঠিক নির্বাচন করো –", "BODY:"],
  [
    "বিবৃতি ১: কাব্যের অবয়ব নির্দোষ হয়ে গুণযুক্ত হলে কাব্য হয়।",
    "বিবৃতি ২: রীতিবাদের মতখণ্ডন হল, শুধুমাত্র অবয়বই কাব্যকে সর্বাঙ্গসুন্দর করে তুলতে পারে।",
  ],
  [
    "(A) উভয় বিবৃতি ঠিক",
    "(B) বিবৃতি ১ ঠিক কিন্তু ২ ভুল",
    "(C) বিবৃতি ১ ভুল কিন্তু ২ ঠিক",
    "(D) উভয় বিবৃতি ভুল",
  ],
  ["সঠিক উত্তর: (B)"],
  ["ব্যাখ্যা: … তাই বিবৃতি ২ ভুল।"],
  ["XYZ10 রসবাদ থেকে স্তম্ভ মিল করো।", "BODY-"],
  [
    "'ক' স্তম্ভ — 'খ' স্তম্ভ",
    "a) ভট্টলোল্লট — 1) উৎপত্তিবাদ",
    "b) ভট্টশঙ্কুক — 2) অনুমিতিবাদ",
    "c) ভট্টনায়ক — 3) ভুক্তিবাদ",
    "d) অভিনবগুপ্ত — 4) অভিব্যক্তিবাদ",
  ],
  [
    "(A) a-1, b-2, c-3, d-4",
    "(B) a-4, b-3, c-2, d-1",
    "(C) a-2, b-4, c-1, d-3",
    "(D) a-1, b-3, c-4, d-2",
  ],
  ["সঠিক উত্তর: (A)"],
  ["ব্যাখ্যা: ভরতের রসসূত্রের ব্যাখ্যায় …"],
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

  test('reads the demo statement and match-the-column questions', () {
    final rows = _read([..._demo, ..._demoBody]);

    expect(rows.map((r) => r.code),
        ["XYZ1", "XYZ2", "XYZ6", "XYZ7", "XYZ8", "XYZ9", "XYZ10"]);
    expect(rows.every((r) => r.isValid), isTrue,
        reason: rows.map((r) => r.errors).toString());
    expect(rows.skip(2).map((r) => r.draft.answer), [
      QuestionOption.d,
      QuestionOption.b,
      QuestionOption.c,
      QuestionOption.b,
      QuestionOption.a,
    ]);

    final QuestionImportRow statements = rows[2];
    expect(statements.preview,
        "নিচের দেওয়া বিবৃতিগুলি শুদ্ধ না অশুদ্ধ তা বিচার করো।");
    expect(statements.source["question_body"].split("\n"), [
      startsWith("A. বামনাচার্য"),
      startsWith("B. আচার্য"),
      startsWith("C. বামন"),
      startsWith("D. কুন্তক"),
      startsWith("E. কুন্তক"),
    ]);
    expect(statements.draft.questionBody, startsWith("<p>A. বামনাচার্য"));
    expect(statements.draft.questionBody, contains("<br>E. কুন্তক"));
    expect(statements.source["option_a"],
        "A-শুদ্ধ, B-অশুদ্ধ, C-শুদ্ধ, D-অশুদ্ধ, E-শুদ্ধ");

    final QuestionImportRow columns = rows[3];
    expect(columns.source["question_body"].split("\n").first,
        "'ক' স্তম্ভ — 'খ' স্তম্ভ");
    expect(columns.source["question_body"].split("\n"), hasLength(5));
    expect(columns.source["option_a"], "A>2, B>3, C>4, D>1");
    expect(columns.draft.optionA, "<p>A&gt;2, B&gt;3, C&gt;4, D&gt;1</p>");
    expect(columns.draft.solution, "");

    expect(rows[4].source["question_body"].split("\n"), hasLength(4));
    expect(
        rows[4].source["question_body"], startsWith("a) 'গুণীভূত ব্যঙ্গ্য'"));
    expect(rows[5].source["question_body"], startsWith("বিবৃতি ১:"));
    expect(rows[6].source["option_d"], "a-1, b-3, c-4, d-2");
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

  test('BODY- may end the question line, and BODY: may carry text', () {
    final rows = _read([
      ["XYZ1 Which are true? BODY-"],
      ["1. The sun is a star.", "2. The moon is a planet."],
      ["(A) Only 1", "(B) Only 2", "(C) Both", "(D) Neither"],
      ["Answer: A"],
      ["XYZ2. Match the columns."],
      ["Body: a) Kolkata — 1) West Bengal", "b) Patna — 2) Bihar"],
      ["(A) a-1, b-2 (B) a-2, b-1 (C) a-1, b-1 (D) a-2, b-2"],
      ["Answer: A"],
    ]);

    expect(rows.every((r) => r.isValid), isTrue,
        reason: rows.map((r) => r.errors).toString());
    expect(rows.map((r) => r.code), ["XYZ1", "XYZ2"]);
    expect(rows[0].preview, "Which are true?");
    expect(rows[0].draft.questionBody,
        "<p>1. The sun is a star.<br>2. The moon is a planet.</p>");
    expect(rows[1].source["question_body"],
        "a) Kolkata — 1) West Bengal\nb) Patna — 2) Bihar");
    expect(rows[1].source["option_b"], "a-2, b-1");
  });

  test('a question that mentions the body keeps its text', () {
    final rows = _read([
      ["XYZ1. Which organ filters blood in the body: which one?"],
      ["(A) Heart", "(B) Kidney", "(C) Lung", "(D) Liver"],
      ["Answer: B"],
    ]);

    expect(rows.single.preview,
        "Which organ filters blood in the body: which one?");
    expect(rows.single.source["question_body"], "");
  });

  test('statements written like options without BODY- are reported', () {
    final rows = _read([
      ["XYZ1. Judge the statements."],
      ["A. The sun is a star.", "B. The moon is a planet."],
      ["(A) A only", "(B) B only", "(C) Both", "(D) Neither"],
      ["সঠিক উত্তর: (C)"],
    ]);

    expect(rows.single.errors, [
      "Options A, B appear more than once — check that each question "
          "starts with its code, and put statements or columns after a "
          "BODY- line",
    ]);
  });

  test('a question whose code is missed is reported, not merged', () {
    final rows = _read([
      ["XYZ1. First?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["সঠিক উত্তর: (A)"],
      ["Second, with no code?"],
      ["(A) w", "(B) x", "(C) y", "(D) z"],
      ["সঠিক উত্তর: (B)"],
    ]);

    expect(rows.single.errors, [
      "Options A, B, C, D appear more than once — check that each question "
          "starts with its code, and put statements or columns after a "
          "BODY- line",
      "More than one answer line — check that each question starts with "
          "its code",
    ]);
  });

  test('codes need no full stop, but a title that looks like one is skipped',
      () {
    final rows = _read([
      ["SLST2025 Practice Set"],
      ["XYZ1 First?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Answer: A"],
      ["XYZ2 Second?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Answer: B"],
    ]);
    expect(rows.map((r) => r.code), ["XYZ1", "XYZ2"]);
    expect(rows.every((r) => r.isValid), isTrue);

    final plain = _read([
      ["Class10 Bengali MCQ"],
      ["1. First?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Answer: A"],
      ["2. Second?"],
      ["(A) a", "(B) b", "(C) c", "(D) d"],
      ["Answer: B"],
    ]);
    expect(plain.map((r) => r.code), ["1", "2"]);
    expect(plain.every((r) => r.isValid), isTrue);
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
