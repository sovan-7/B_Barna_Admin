import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/resources/constant.dart';

/// Which option a question's answer points at.
enum QuestionOption { a, b, c, d }

/// Display letter and form field for each [QuestionOption].
extension QuestionOptionLabel on QuestionOption {
  /// "A" – "D".
  String get label => switch (this) {
        QuestionOption.a => "A",
        QuestionOption.b => "B",
        QuestionOption.c => "C",
        QuestionOption.d => "D",
      };

  /// The form field this option's text lives in.
  QuestionField get field => switch (this) {
        QuestionOption.a => QuestionField.optionA,
        QuestionOption.b => QuestionField.optionB,
        QuestionOption.c => QuestionField.optionC,
        QuestionOption.d => QuestionField.optionD,
      };
}

/// The fields a question form collects, as plain strings.
///
/// The rich-text editors are webviews, so nothing that reads them can be
/// exercised in a test. Pulling the *rules* out into a plain value means
/// validation and assembly can be tested on their own, and the form is left
/// doing only what a form should: gather text, hand it over, show errors.
class QuestionDraft {
  /// Question code (upper-cased on save).
  final String code;

  /// The question, as HTML.
  final String question;

  /// Optional extra body, as HTML.
  final String questionBody;

  /// Option A, as HTML.
  final String optionA;

  /// Option B, as HTML.
  final String optionB;

  /// Option C, as HTML.
  final String optionC;

  /// Option D, as HTML.
  final String optionD;

  /// Hint, as HTML.
  final String hints;

  /// Worked solution, as HTML.
  final String solution;

  /// Which option is correct; null until one is marked.
  final QuestionOption? answer;

  /// Creates a draft from the form's current values.
  const QuestionDraft({
    this.code = "",
    this.question = "",
    this.questionBody = "",
    this.optionA = "",
    this.optionB = "",
    this.optionC = "",
    this.optionD = "",
    this.hints = "",
    this.solution = "",
    this.answer,
  });

  /// The draft an edit form opens with.
  ///
  /// Split out from the form because the form cannot be mounted in a test —
  /// its fields are `html_editor_enhanced` webviews — so this is the only
  /// place the "editing shows the stored question" rule can be pinned down.
  factory QuestionDraft.fromQuestion(Question question) => QuestionDraft(
        code: _blankDefault(question.questionCode),
        question: _blankDefault(question.question),
        questionBody: _blankDefault(question.questionBody),
        optionA: _blankDefault(question.option1),
        optionB: _blankDefault(question.option2),
        optionC: _blankDefault(question.option3),
        optionD: _blankDefault(question.option4),
        hints: _blankDefault(question.hints),
        solution: _blankDefault(question.solution),
        answer: answerOf(question),
      );

  /// A field that was never set reads back as [stringDefault] ("NA"). That
  /// is a placeholder, not content — putting it in an editor would have the
  /// admin deleting the letters N and A out of every empty field.
  static String _blankDefault(String value) =>
      value == stringDefault ? "" : value;

  /// The HTML of [option].
  String optionFor(QuestionOption option) => switch (option) {
        QuestionOption.a => optionA,
        QuestionOption.b => optionB,
        QuestionOption.c => optionC,
        QuestionOption.d => optionD,
      };

  /// Which option's text matches the stored `answer`, or null when it
  /// matches none (so an unmarked answer never shows as D).
  static QuestionOption? answerOf(Question question) {
    final String answer = _strip(question.answer);
    if (answer.isEmpty) return null;
    for (final QuestionOption option in QuestionOption.values) {
      final String text = _strip(switch (option) {
        QuestionOption.a => question.option1,
        QuestionOption.b => question.option2,
        QuestionOption.c => question.option3,
        QuestionOption.d => question.option4,
      });
      if (text.isNotEmpty && text == answer) return option;
    }
    return null;
  }

  /// Field-keyed problems with this draft. Empty means valid.
  Map<QuestionField, String> validate() {
    final Map<QuestionField, String> errors = {};

    if (code.trim().isEmpty) {
      errors[QuestionField.code] = "Give the question a code";
    }
    if (_strip(question).isEmpty) {
      errors[QuestionField.question] = "Write the question";
    }

    // All four options are required: a multiple-choice question with a
    // blank option is one a student can pick and never be right about.
    for (final QuestionOption option in QuestionOption.values) {
      if (_strip(optionFor(option)).isEmpty) {
        errors[option.field] = "Fill in option ${option.label}";
      }
    }

    if (answer == null) {
      errors[QuestionField.answer] = "Mark which option is correct";
    } else if (_strip(optionFor(answer!)).isEmpty) {
      errors[QuestionField.answer] =
          "Option ${answer!.label} is empty — it cannot be the answer";
    }
    return errors;
  }

  /// The document body this draft saves as.
  Map<String, dynamic> toMap({required int timeStamp}) => {
        "question_code": code.trim().toUpperCase(),
        "question": question,
        "question_body": questionBody,
        "option1": optionA,
        "option2": optionB,
        "option3": optionC,
        "option4": optionD,
        "hints": hints,
        "solution": solution,
        "answer": answer == null ? "" : optionFor(answer!),
        "timeStamp": timeStamp,
      };

  /// Rich text with its markup removed, for emptiness checks and for
  /// showing a question as one line in a list.
  ///
  /// Results are cached (list rows ask for the same text on every rebuild).
  static String plainText(String html) {
    final String? cached = _plainCache[html];
    if (cached != null) return cached;
    if (_plainCache.length >= 2000) _plainCache.clear();
    return _plainCache[html] = _toPlainText(html);
  }

  /// Converted texts, keyed by the HTML they came from.
  static final Map<String, String> _plainCache = <String, String>{};

  static final RegExp _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _tag = RegExp(r'<[^>]*>');
  static final RegExp _spaces = RegExp(r'\s+');

  /// The uncached conversion behind [plainText].
  static String _toPlainText(String html) {
    final String text = html
        .replaceAll(_lineBreak, ' ')
        .replaceAll(_tag, ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll(_spaces, ' ')
        .trim();
    return text;
  }

  /// Short alias for [plainText].
  static String _strip(String html) => plainText(html);
}

/// Every field of the question form that can carry an inline error.
enum QuestionField {
  code,
  question,
  optionA,
  optionB,
  optionC,
  optionD,
  answer
}
