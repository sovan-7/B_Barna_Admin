import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/repo/quiz_repo.dart';
import 'package:bbarna/quiz/screen/add_quiz.dart';
import 'package:bbarna/quiz/screen/edit_quiz.dart';
import 'package:bbarna/quiz/screen/quiz_list.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/quiz/widgets/quiz_card.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockQuizRepo extends Mock implements QuizRepo {}

class QuizModelFake extends Fake implements QuizModel {}

QuizModel _quiz(
  String id,
  String code,
  String name, {
  String status = "LIVE",
  String type = "FREE",
  int totalTime = 90,
  int totalMarks = 100,
  int deduction = 0,
  int totalQuestion = 2,
  List<String>? questionCodes,
  int timeStamp = 0,
}) {
  final QuizModel model = QuizModel(code, name, status, type, totalTime,
      timeStamp, totalMarks, deduction, 0, totalQuestion,
      questionCodes ?? ["Q-01", "Q-02"]);
  model.docId = id;
  return model;
}

List<QuizModel> _fixture() => [
      _quiz('a', 'MOCK-01', 'Physics mock test 1', timeStamp: 300),
      _quiz('b', 'MOCK-02', 'Chemistry mock test',
          status: "UPCOMING", type: "PAID", deduction: 1, timeStamp: 200),
      _quiz(
          'c',
          'MOCK-03',
          'An extremely long quiz name that will certainly not fit on one '
              'line of any card at any breakpoint whatsoever',
          status: "PENDING",
          totalTime: 0,
          totalMarks: 0,
          totalQuestion: 5,
          questionCodes: ["Q-01"],
          timeStamp: 100),
    ];

Question _question(String code, String body) {
  final Question q = Question(questionCode: code);
  q.question = body;
  return q;
}

const List<Size> _sizes = [
  Size(1440, 900),
  Size(1024, 768),
  Size(700, 900),
  Size(380, 820),
];

late MockQuizRepo repo;

Future<void> _pump(
    WidgetTester tester, Size size, Widget home, QuizViewModel vm) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ChangeNotifierProvider<QuizViewModel>.value(
    value: vm,
    child: MaterialApp(navigatorKey: navigatorKey, home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => registerFallbackValue(QuizModelFake()));

  setUp(() {
    repo = MockQuizRepo();
    when(() => repo.getFirstQuizList(any())).thenAnswer((_) async => _fixture());
    when(() => repo.getQuizListLength()).thenAnswer((_) async => 3);
    when(() => repo.getQuestionsByCodes(any())).thenAnswer((_) async => [
          _question('Q-01', '<p>What is the SI unit of force?</p>'),
          _question('Q-02', '<p>State the first law of motion.</p>'),
        ]);
  });

  group('layout', () {
    for (final Size size in _sizes) {
      testWidgets('the list lays out at ${size.width.toInt()}', (tester) async {
        final vm = QuizViewModel(quizRepo: repo);
        await _pump(tester, size, const Scaffold(body: QuizList()), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Quizzes'), findsOneWidget);
        expect(find.byType(QuizCard), findsNWidgets(3));
      });

      testWidgets('the add form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = QuizViewModel(quizRepo: repo);
        await _pump(tester, size, const AddQuiz(), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Add a quiz'), findsOneWidget);
      });

      testWidgets('the edit form lays out at ${size.width.toInt()}',
          (tester) async {
        final vm = QuizViewModel(quizRepo: repo);
        await _pump(tester, size, EditQuiz(quizData: _fixture().first), vm);

        expect(tester.takeException(), isNull);
        expect(find.text('Edit quiz'), findsOneWidget);
      });
    }
  });

  group('the card', () {
    testWidgets('shows the numbers that define a quiz', (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: QuizList()), vm);

      // None of this was on the old row.
      expect(find.text('1h 30m'), findsNWidgets(2));
      expect(find.text('100 marks'), findsNWidgets(2));
      expect(find.text('-1 per wrong answer'), findsOneWidget);
      expect(find.text('No time limit'), findsOneWidget);
      expect(find.text('No marks set'), findsOneWidget);
    });

    testWidgets('flags a stored count that disagrees with the questions',
        (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: QuizList()), vm);

      // MOCK-03 says 5 questions but names only one.
      expect(find.text('1 attached (set to 5)'), findsOneWidget);
      expect(find.text('2 questions'), findsNWidgets(2));
    });

    testWidgets('status is told apart', (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(
          tester, const Size(1440, 900), const Scaffold(body: QuizList()), vm);

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('a failed search reports it instead of popping the page',
        (tester) async {
      when(() => repo.searchQuiz(any())).thenThrow(Exception('offline'));

      final vm = QuizViewModel(quizRepo: repo);
      await _pump(
          tester, const Size(1024, 768), const Scaffold(body: QuizList()), vm);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(QuizList), findsOneWidget);
      // A failed search is an error with Retry, not "No matches".
      expect(find.text('Search failed'), findsOneWidget);
      expect(find.byKey(const Key('list_retry_button')), findsOneWidget);
    });

    testWidgets('mounting mid-build does not throw', (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(
          tester, const Size(1024, 768), const Scaffold(body: QuizList()), vm);
      expect(tester.takeException(), isNull);
    });
  });

  group('the question picker', () {
    testWidgets('an edit loads the questions the quiz already holds',
        (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditQuiz(quizData: _fixture().first), vm);

      verify(() => repo.getQuestionsByCodes(['Q-01', 'Q-02'])).called(1);
      expect(find.text('2 attached'), findsOneWidget);
      // Questions are stored as HTML; the row shows the text, not the markup.
      expect(find.text('What is the SI unit of force?'), findsOneWidget);
    });

    testWidgets('adding moves a question between the lists', (tester) async {
      when(() => repo.getQuestionsByCodes(any())).thenAnswer((_) async => []);
      when(() => repo.searchQuestions(any())).thenAnswer(
          (_) async => [_question('Q-07', '<p>Define momentum.</p>')]);

      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddQuiz(), vm);

      expect(find.text('No questions attached yet'), findsOneWidget);

      await tester.ensureVisible(
          find.byKey(const Key('quiz_question_search_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('quiz_question_search')), 'q-07');
      await tester.tap(find.byKey(const Key('quiz_question_search_button')));
      await tester.pump();
      await tester.pump();

      verify(() => repo.searchQuestions('Q-07')).called(1);
      expect(find.byKey(const Key('quiz_add_Q-07')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('quiz_add_Q-07')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quiz_add_Q-07')));
      await tester.pump();

      expect(vm.selectedQuestionCodeList, ['Q-07']);
      expect(find.text('1 attached'), findsOneWidget);
      // Once attached it is no longer offered as a result.
      expect(find.byKey(const Key('quiz_add_Q-07')), findsNothing);
      expect(find.byKey(const Key('quiz_remove_Q-07')), findsOneWidget);
    });

    testWidgets('a search hides questions already on the quiz',
        (tester) async {
      when(() => repo.searchQuestions(any())).thenAnswer((_) async => [
            _question('Q-01', '<p>Already on the quiz.</p>'),
            _question('Q-09', '<p>Not yet.</p>'),
          ]);

      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditQuiz(quizData: _fixture().first), vm);

      await vm.searchQuestions('Q');
      await tester.pump();

      expect(vm.questionList.map((q) => q.questionCode).toList(), ['Q-09']);
    });

    testWidgets('removing takes a question off the quiz', (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900),
          EditQuiz(quizData: _fixture().first), vm);

      await tester.ensureVisible(find.byKey(const Key('quiz_remove_Q-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quiz_remove_Q-01')));
      await tester.pump();

      expect(vm.selectedQuestionCodeList, ['Q-02']);
      expect(find.text('1 attached'), findsOneWidget);
    });
  });

  group('the form', () {
    testWidgets('an invalid submit marks every offending field',
        (tester) async {
      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddQuiz(), vm);

      await tester.tap(find.byKey(const Key('quiz_save_button')));
      await tester.pump();

      expect(find.text('Give the quiz a code'), findsOneWidget);
      expect(find.text('Give the quiz a name'), findsOneWidget);
      expect(find.text('Choose a status'), findsOneWidget);
      expect(find.text('Choose whether it is free or paid'), findsOneWidget);
      expect(find.text('Set how long the quiz runs'), findsOneWidget);
      expect(find.text('Set the total marks'), findsOneWidget);
      verifyNever(() => repo.addQuiz(any()));
    });

    testWidgets('hours and minutes are summed into one number', (tester) async {
      when(() => repo.addQuiz(any())).thenAnswer((_) async => 'new-id');
      when(() => repo.getQuestionsByCodes(any())).thenAnswer((_) async => []);

      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900), const AddQuiz(), vm);

      await tester.enterText(find.byType(TextField).at(0), 'mock-09');
      await tester.enterText(find.byType(TextField).at(1), 'Trial run');
      await tester.tap(find.byKey(const Key('quiz_status_live')));
      await tester.tap(find.byKey(const Key('quiz_type_free')));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(2), '2');
      await tester.enterText(find.byType(TextField).at(3), '15');
      await tester.enterText(find.byType(TextField).at(4), '50');
      await tester.pump();

      expect(find.text('Students get 2h 15m.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quiz_save_button')));
      await tester.pump();
      await tester.pump();

      final QuizModel saved =
          verify(() => repo.addQuiz(captureAny())).captured.single as QuizModel;
      expect(saved.totalTime, 135);
      expect(saved.code, 'MOCK-09', reason: 'codes are stored upper-cased');
      expect(saved.status, 'LIVE');
    });

    testWidgets(
        'a quiz whose questions failed to load cannot be saved until retried',
        (tester) async {
      when(() => repo.updateQuiz(any(), any())).thenAnswer((_) async {});
      when(() => repo.getQuestionsByCodes(any()))
          .thenThrow(Exception('offline'));
      final QuizModel quiz = _quiz('c', 'MOCK-04', 'Has questions',
          questionCodes: ["Q-01", "Q-02"]);

      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900), EditQuiz(quizData: quiz), vm);

      expect(find.text("Couldn't load this quiz's questions"), findsOneWidget);
      expect(find.text('No questions attached yet'), findsNothing);

      // Saving now would wipe the questions, so it is refused.
      await tester.ensureVisible(find.byKey(const Key('quiz_save_button')));
      await tester.tap(find.byKey(const Key('quiz_save_button')));
      await tester.pump();
      verifyNever(() => repo.updateQuiz(any(), any()));

      // Retry loads them, and saving keeps them.
      when(() => repo.getQuestionsByCodes(any())).thenAnswer((_) async => [
            _question('Q-01', '<p>One</p>'),
            _question('Q-02', '<p>Two</p>'),
          ]);
      await tester.ensureVisible(find.byKey(const Key('field_retry')));
      await tester.tap(find.byKey(const Key('field_retry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quiz_save_button')));
      await tester.pump();
      await tester.pump();

      final QuizModel saved =
          verify(() => repo.updateQuiz(captureAny(), 'c')).captured.single
              as QuizModel;
      expect(saved.questionCodeList, ['Q-01', 'Q-02']);
    });

    testWidgets('the question count is derived from the questions attached',
        (tester) async {
      when(() => repo.updateQuiz(any(), any())).thenAnswer((_) async {});

      // Valid rules, but a stored count that disagrees with its questions.
      final QuizModel stale = _quiz('c', 'MOCK-04', 'Stale count',
          totalQuestion: 5, questionCodes: ["Q-01"]);

      final vm = QuizViewModel(quizRepo: repo);
      await _pump(tester, const Size(1024, 900), EditQuiz(quizData: stale), vm);

      // It claims 5 questions but names one; the repo returns two.
      await tester.tap(find.byKey(const Key('quiz_save_button')));
      await tester.pump();
      await tester.pump();

      final QuizModel saved =
          verify(() => repo.updateQuiz(captureAny(), 'c')).captured.single
              as QuizModel;
      // It used to be a number typed by hand, with nothing keeping the two
      // in step.
      expect(saved.totalQuestion, saved.questionCodeList.length);
      expect(saved.questionCodeList, ['Q-01', 'Q-02']);
    });

  // The name and the code are what an admin pastes elsewhere -- into a
  // search box, a spreadsheet, another module's form -- so they render as
  // SelectableLabel rather than plain Text.
  testWidgets('names and codes in the list are selectable', (tester) async {
    await _pump(tester, const Size(1440, 900),
        const Scaffold(body: QuizList()), QuizViewModel(quizRepo: repo));

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

  group('the model', () {
    test('int fields fall back to an int', () {
      // They defaulted to `stringDefault` ("NA"), so a document missing any
      // one of them threw a type error on read.
      expect(intDefault, isA<int>());
    });
  });
}
