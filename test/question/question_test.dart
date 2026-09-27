import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/question/viewModel/question_view_model.dart';
import 'package:bbarna/question/repo/question_repo.dart';
import 'package:bbarna/question/screen/question_list.dart';
import 'package:bbarna/question/widgets/question_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockQuestionRepo extends Mock implements QuestionRepo {}

Question _question(
  String id,
  String code, {
  String text = "<p>What is the SI unit of force?</p>",
  String a = "<p>Newton</p>",
  String b = "<p>Joule</p>",
  String c = "<p>Watt</p>",
  String d = "<p>Pascal</p>",
  String? answer = "<p>Newton</p>",
  int timeStamp = 0,
}) =>
    Question(
      docId: id,
      questionCode: code,
      question: text,
      option1: a,
      option2: b,
      option3: c,
      option4: d,
      answer: answer ?? "",
      timeStamp: timeStamp,
    );

List<Question> _fixture() => [
      _question('a', 'PHY-001', timeStamp: 300),
      // No answer stored at all.
      _question('b', 'PHY-002',
          text: "<p>State Newton&#39;s first law.</p>",
          answer: null,
          timeStamp: 200),
      // Two options never filled in.
      _question('c', 'PHY-003',
          text: "<p>Define momentum.</p>",
          c: "",
          d: "",
          answer: "<p>Newton</p>",
          timeStamp: 100),
    ];

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockQuestionRepo repo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, QuestionViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<QuestionViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    repo = MockQuestionRepo();
    when(() => repo.getFirstQuestionList(any()))
        .thenAnswer((_) async => _fixture());
    when(() => repo.getQuestionListLength()).thenAnswer((_) async => 3);
  });

  group('the draft', () {
    const QuestionDraft valid = QuestionDraft(
      code: "PHY-001",
      question: "<p>What is the SI unit of force?</p>",
      optionA: "<p>Newton</p>",
      optionB: "<p>Joule</p>",
      optionC: "<p>Watt</p>",
      optionD: "<p>Pascal</p>",
      answer: QuestionOption.a,
    );

    test('a complete draft is valid', () {
      expect(valid.validate(), isEmpty);
    });

    test('every empty option is reported, not just the first', () {
      // Only the code, the question and *an* answer were checked before, so
      // a question could be saved with blank options a student could pick.
      const QuestionDraft draft = QuestionDraft(
        code: "PHY-001",
        question: "<p>Q</p>",
        optionA: "<p>Newton</p>",
        answer: QuestionOption.a,
      );
      final Map<QuestionField, String> errors = draft.validate();

      expect(errors[QuestionField.optionB], "Fill in option B");
      expect(errors[QuestionField.optionC], "Fill in option C");
      expect(errors[QuestionField.optionD], "Fill in option D");
      expect(errors.containsKey(QuestionField.optionA), isFalse);
    });

    test('empty markup counts as empty', () {
      // A rich-text editor returns "<p><br></p>" for an untouched field.
      final QuestionDraft draft = QuestionDraft(
        code: "PHY-001",
        question: "<p><br></p>",
        optionA: valid.optionA,
        optionB: valid.optionB,
        optionC: valid.optionC,
        optionD: valid.optionD,
        answer: QuestionOption.a,
      );
      expect(draft.validate()[QuestionField.question], "Write the question");
    });

    test('an unmarked answer is reported', () {
      final QuestionDraft draft = QuestionDraft(
        code: valid.code,
        question: valid.question,
        optionA: valid.optionA,
        optionB: valid.optionB,
        optionC: valid.optionC,
        optionD: valid.optionD,
      );
      expect(draft.validate()[QuestionField.answer],
          "Mark which option is correct");
    });

    test('an answer pointing at an empty option is reported', () {
      final QuestionDraft draft = QuestionDraft(
        code: valid.code,
        question: valid.question,
        optionA: valid.optionA,
        optionB: valid.optionB,
        optionC: valid.optionC,
        answer: QuestionOption.d,
      );
      expect(draft.validate()[QuestionField.answer],
          "Option D is empty — it cannot be the answer");
    });

    test('the code is stored upper-cased and the answer as option text', () {
      const QuestionDraft draft = QuestionDraft(
        code: " phy-001 ",
        question: "<p>Q</p>",
        optionA: "<p>Newton</p>",
        optionB: "<p>Joule</p>",
        optionC: "<p>Watt</p>",
        optionD: "<p>Pascal</p>",
        answer: QuestionOption.c,
      );
      final Map<String, dynamic> map = draft.toMap(timeStamp: 42);

      expect(map["question_code"], "PHY-001");
      expect(map["answer"], "<p>Watt</p>");
      expect(map["timeStamp"], 42);
    });
  });

  group('opening a question for editing', () {
    // The form's fields are `html_editor_enhanced` webviews and cannot be
    // mounted in a test, so this is where "edit shows what was saved" is
    // pinned. The form seeds each editor from this draft.
    Question stored() => Question(
          docId: 'q1',
          questionCode: 'PHY-01',
          question: '<p>What is the SI unit of force?</p>',
          questionBody: '<p>Refer to the diagram above.</p>',
          option1: '<p>Newton</p>',
          option2: '<p>Joule</p>',
          option3: '<p>Watt</p>',
          option4: '<p>Pascal</p>',
          answer: '<p>Newton</p>',
          hints: '<p>Think of F = ma.</p>',
          solution: '<p>Force is measured in newtons.</p>',
          timeStamp: 42,
        );

    test('carries every field the form has to fill', () {
      final QuestionDraft draft = QuestionDraft.fromQuestion(stored());

      // Every one of these opened blank: the editors were prefilled from a
      // post-frame `setText`, which runs before the webview exists.
      expect(draft.code, 'PHY-01');
      expect(draft.question, '<p>What is the SI unit of force?</p>');
      expect(draft.questionBody, '<p>Refer to the diagram above.</p>');
      expect(draft.optionA, '<p>Newton</p>');
      expect(draft.optionB, '<p>Joule</p>');
      expect(draft.optionC, '<p>Watt</p>');
      expect(draft.optionD, '<p>Pascal</p>');
      expect(draft.hints, '<p>Think of F = ma.</p>');
      expect(draft.solution, '<p>Force is measured in newtons.</p>');
    });

    test('marks the option the stored answer points at', () {
      expect(QuestionDraft.fromQuestion(stored()).answer, QuestionOption.a);
    });

    test('what it opens with is what it would save back', () {
      // Reopening and saving without touching anything must not change the
      // document.
      final Question original = stored();
      final Map<String, dynamic> map =
          QuestionDraft.fromQuestion(original).toMap(timeStamp: 42);

      expect(map['question_code'], original.questionCode);
      expect(map['question'], original.question);
      expect(map['question_body'], original.questionBody);
      expect(map['option1'], original.option1);
      expect(map['option4'], original.option4);
      expect(map['hints'], original.hints);
      expect(map['solution'], original.solution);
      expect(map['answer'], original.answer);
    });

    test('an unset field opens empty, not as the string "NA"', () {
      // Question.fromDocumentSnapshot defaults missing fields to
      // stringDefault. Seeding an editor with that would have the admin
      // deleting "NA" out of every optional box.
      final QuestionDraft draft = QuestionDraft.fromQuestion(Question(
        docId: 'q2',
        questionCode: 'PHY-02',
        question: '<p>Q</p>',
        questionBody: stringDefault,
        hints: stringDefault,
        solution: stringDefault,
        option1: '<p>a</p>',
        option2: '<p>b</p>',
        option3: '<p>c</p>',
        option4: '<p>d</p>',
        answer: '<p>a</p>',
      ));

      expect(draft.questionBody, '');
      expect(draft.hints, '');
      expect(draft.solution, '');
    });

    test('adding opens with nothing filled in', () {
      const QuestionDraft draft = QuestionDraft();

      expect(draft.code, '');
      expect(draft.question, '');
      expect(draft.answer, isNull);
    });
  });

  group('answerOf', () {
    test('finds the option the stored answer matches', () {
      expect(QuestionDraft.answerOf(_question('a', 'X')), QuestionOption.a);
      expect(
          QuestionDraft.answerOf(
              _question('a', 'X', answer: "<p>Watt</p>")),
          QuestionOption.c);
    });

    test('returns null when nothing matches', () {
      // The old lookup was an if/else chain whose final `else` returned
      // option 4, so a question with no answer showed D as correct.
      expect(QuestionDraft.answerOf(_question('a', 'X', answer: null)), isNull);
      expect(
          QuestionDraft.answerOf(
              _question('a', 'X', answer: "<p>Something else</p>")),
          isNull);
    });

    test('an empty option is never the match for an empty answer', () {
      expect(
          QuestionDraft.answerOf(
              _question('a', 'X', d: "", answer: null)),
          isNull);
    });
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = QuestionViewModel(questionRepo: repo);
        await _pump(tester, size, const Scaffold(body: QuestionList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Questions'), findsOneWidget);
        expect(find.byType(QuestionCard), findsNWidgets(3));
      });
    }
  });

  group('the card', () {
    testWidgets('shows the question as one line of plain text',
        (tester) async {
      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: QuestionList()), vm);

      // The old row rendered the stored HTML, so a row was as tall as the
      // question's formatting.
      expect(find.text('What is the SI unit of force?'), findsOneWidget);
      expect(find.text("State Newton's first law."), findsOneWidget);
    });

    testWidgets('calls out a question with no answer marked', (tester) async {
      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: QuestionList()), vm);

      expect(find.text('No answer set'), findsOneWidget);
      expect(find.text('Answer A'), findsNWidgets(2));
    });

    testWidgets('calls out missing options', (tester) async {
      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: QuestionList()), vm);

      expect(find.text('2 of 4 options'), findsOneWidget);
      expect(find.text('4 options'), findsNWidgets(2));
    });
  });

  group('the list', () {
    testWidgets('says how much of the collection is loaded', (tester) async {
      when(() => repo.getQuestionListLength()).thenAnswer((_) async => 640);
      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: QuestionList()), vm);

      expect(find.text('Showing 3 of 640'), findsOneWidget);
      expect(find.byKey(const Key('paged_list_load_more')), findsOneWidget);
    });

    testWidgets('search runs server-side, uppercased', (tester) async {
      when(() => repo.searchQuestion(any()))
          .thenAnswer((_) async => [_fixture().first]);

      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1440, 900),
          const Scaffold(body: QuestionList()), vm);

      await tester.enterText(find.byType(TextField).first, 'phy-001');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      verify(() => repo.searchQuestion('PHY-001')).called(1);
      expect(find.byType(QuestionCard), findsOneWidget);
    });

    testWidgets('a failed search reports it instead of popping the page',
        (tester) async {
      when(() => repo.searchQuestion(any())).thenThrow(Exception('offline'));

      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: QuestionList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(QuestionList), findsOneWidget);
      // A failed search is an error with Retry, not "No matches".
      expect(find.text('Search failed'), findsOneWidget);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = QuestionViewModel(questionRepo: repo);
      await _pump(tester, const Size(1024, 768),
          const Scaffold(body: QuestionList()), vm);
      expect(tester.takeException(), isNull);
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: QuestionList()), QuestionViewModel(questionRepo: repo));

    final Iterable<SelectableLabel> labels =
        tester.widgetList<SelectableLabel>(find.byType(SelectableLabel));
    expect(labels, isNotEmpty);
    for (final SelectableLabel label in labels) {
      expect(label.data.trim(), isNotEmpty);
    }
    // Drag-select and Ctrl/Cmd-C come from the SelectableText each builds.
    expect(
      find.descendant(
        of: find.byType(SelectableLabel),
        matching: find.byType(SelectableText),
      ),
      findsWidgets,
    );
  });

  });

  group('delete', () {
    test('removes the row by document id, not by list position', () async {
      when(() => repo.deleteQuestion(any())).thenAnswer((_) async {});

      final vm = QuestionViewModel(questionRepo: repo);
      await vm.fetchFirstQuestionList();
      expect(vm.questionList, hasLength(3));

      // It used to take a list index and removeAt it, so a delete confirmed
      // after a refresh removed whichever row now sat at that position.
      expect(await vm.deleteQuestion('b'), isTrue);

      verify(() => repo.deleteQuestion('b')).called(1);
      expect(vm.questionList.map((q) => q.docId).toList(), ['a', 'c']);
      expect(vm.questionListLength, 2);
    });
  });

  group('save', () {
    const QuestionDraft draft = QuestionDraft(
      code: "phy-009",
      question: "<p>Q</p>",
      optionA: "<p>A</p>",
      optionB: "<p>B</p>",
      optionC: "<p>C</p>",
      optionD: "<p>D</p>",
      answer: QuestionOption.b,
    );

    test('create writes the draft', () async {
      when(() => repo.addQuestion(any())).thenAnswer((_) async => 'new-id');

      final vm = QuestionViewModel(questionRepo: repo);
      expect(await vm.createQuestion(draft), isTrue);

      final Map<String, dynamic> written =
          verify(() => repo.addQuestion(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(written["question_code"], "PHY-009");
      expect(written["answer"], "<p>B</p>");
    });

    test('an update keeps the original timestamp', () async {
      when(() => repo.updateQuestion(any(), any())).thenAnswer((_) async {});

      final vm = QuestionViewModel(questionRepo: repo);
      expect(await vm.updateQuestion('a', draft, timeStamp: 111), isTrue);

      final Map<String, dynamic> written =
          verify(() => repo.updateQuestion('a', captureAny())).captured.single
              as Map<String, dynamic>;
      // Otherwise editing a question would jump it to the top of a list
      // ordered by timeStamp.
      expect(written["timeStamp"], 111);
    });
  });
}
