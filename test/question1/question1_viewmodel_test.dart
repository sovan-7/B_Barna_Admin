import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bbarna/question1/model/question1.dart';
import 'package:bbarna/question1/question1_viewmodel/question1_viewmodel.dart';
import 'package:bbarna/question1/repo/question1_repo.dart';
import 'package:bbarna/resources/constant.dart';

class MockQuestion1Repo extends Mock implements Question1Repo {}

Question1 _sampleQuestion({String docId = 'doc-1', int timeStamp = 1000}) =>
    Question1(
      docId: docId,
      questionCode: 'Q1',
      question: 'What is 2+2?',
      questionBody: 'body',
      hints: 'hint',
      solution: 'solution',
      answer: '4',
      option1: '3',
      option2: '4',
      option3: '5',
      option4: '6',
      timeStamp: timeStamp,
    );

/// Fills every field the validator checks and marks option 2 ("4") as
/// correct, mirroring what `Question1HtmlEditor`'s `onContentChanged`
/// callbacks would do as the user types.
void _fillValidForm(Question1ViewModel viewModel) {
  viewModel.questionCodeController.text = 'Q1';
  viewModel.onQuestionChanged('What is 2+2?');
  viewModel.onQuestionBodyChanged('body');
  viewModel.onSolutionChanged('solution');
  viewModel.onOption1Changed('3');
  viewModel.onOption2Changed('4');
  viewModel.onOption3Changed('5');
  viewModel.onOption4Changed('6');
  viewModel.onHintsChanged('hint');
  viewModel.setSelectedIndex(2);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_sampleQuestion());
  });

  late MockQuestion1Repo repo;
  late Question1ViewModel viewModel;

  setUp(() {
    repo = MockQuestion1Repo();
    viewModel = Question1ViewModel(repo: repo);
  });

  group('validate', () {
    test('rejects an empty question code', () {
      _fillValidForm(viewModel);
      viewModel.questionCodeController.text = '';
      expect(viewModel.validate(), 'Please add question code');
    });

    test('rejects an empty question', () {
      _fillValidForm(viewModel);
      viewModel.onQuestionChanged('');
      expect(viewModel.validate(), 'Please add question');
    });

    test('rejects an empty question body', () {
      _fillValidForm(viewModel);
      viewModel.onQuestionBodyChanged('');
      expect(viewModel.validate(), 'Please add question body');
    });

    test('rejects each empty option individually', () {
      _fillValidForm(viewModel);
      viewModel.onOption1Changed('');
      expect(viewModel.validate(), 'Please add option A');

      _fillValidForm(viewModel);
      viewModel.onOption2Changed('');
      expect(viewModel.validate(), 'Please add option B');

      _fillValidForm(viewModel);
      viewModel.onOption3Changed('');
      expect(viewModel.validate(), 'Please add option C');

      _fillValidForm(viewModel);
      viewModel.onOption4Changed('');
      expect(viewModel.validate(), 'Please add option D');
    });

    test('rejects an empty hints field', () {
      _fillValidForm(viewModel);
      viewModel.onHintsChanged('');
      expect(viewModel.validate(), 'Please add hints');
    });

    test('rejects an empty solution', () {
      _fillValidForm(viewModel);
      viewModel.onSolutionChanged('');
      expect(viewModel.validate(), 'Please add solution');
    });

    test('rejects when no answer is selected', () {
      _fillValidForm(viewModel);
      viewModel.selectIndex = -1;
      expect(viewModel.validate(), 'Please select the correct answer');
    });

    test('passes when every field is filled and an answer is selected', () {
      _fillValidForm(viewModel);
      expect(viewModel.validate(), isNull);
    });
  });

  group('editor readiness', () {
    test('allEditorsReady flips true only after all 8 editors report init', () {
      expect(viewModel.allEditorsReady, isFalse);
      for (var i = 0; i < 7; i++) {
        viewModel.onEditorInit();
        expect(viewModel.allEditorsReady, isFalse);
      }
      viewModel.onEditorInit();
      expect(viewModel.allEditorsReady, isTrue);
    });
  });

  // loadForEdit's controller.setText() calls reach into html_editor_enhanced's
  // real HtmlEditorController, which fires an unawaited async exception
  // ("HTML editor is still loading") whenever no live WebView is attached —
  // unavoidable without mounting a real platform WebView, which the VM test
  // runner can't do. Same reason the old module had zero tests at all.
  group('loadForEdit', () {
    test('populates the text cache and matches the selected option', () {
      final question = _sampleQuestion();
      viewModel.loadForEdit(question);

      expect(viewModel.questionCodeController.text, 'Q1');
      expect(viewModel.selectIndex, 2);
      expect(viewModel.validate(), isNull);
    },
        skip:
            'HtmlEditorController.setText() throws async without a live WebView');

    test('leaves no option selected when the answer matches nothing', () {
      final question = _sampleQuestion().copyWithAnswer('nonexistent');
      viewModel.loadForEdit(question);

      expect(viewModel.selectIndex, -1);
    },
        skip:
            'HtmlEditorController.setText() throws async without a live WebView');
  });

  group('addQuestion (needs a live navigator context for the snackbar)', () {
    // Success calls resetForm(), which hits the same HtmlEditorController
    // limitation as loadForEdit above (see that group's comment) — covered
    // instead by the repo test's `addQuestion` group asserting the map shape.
    testWidgets('calls the repo with the form data and resets on success',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
      when(() => repo.addQuestion(any())).thenAnswer((_) async {});
      _fillValidForm(viewModel);

      final result = await viewModel.addQuestion();

      expect(result, isTrue);
      final captured = verify(() => repo.addQuestion(captureAny()))
          .captured
          .single as Question1;
      expect(captured.questionCode, 'Q1');
      expect(captured.answer, '4');
      expect(viewModel.questionCodeController.text, isEmpty);
    }, skip: true);

    testWidgets('returns false and keeps form data when the repo throws',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
      when(() => repo.addQuestion(any())).thenThrow(Exception('boom'));
      _fillValidForm(viewModel);

      final result = await viewModel.addQuestion();

      expect(result, isFalse);
      expect(viewModel.questionCodeController.text, 'Q1');
    });
  });

  group('updateQuestion (needs a live navigator context for the snackbar)', () {
    testWidgets('reuses the given timeStamp rather than the current time',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
      when(() => repo.updateQuestion(any(), any())).thenAnswer((_) async {});
      _fillValidForm(viewModel);

      final result =
          await viewModel.updateQuestion(docId: 'doc-1', timeStamp: 555);

      expect(result, isTrue);
      final captured = verify(() => repo.updateQuestion('doc-1', captureAny()))
          .captured
          .single as Question1;
      expect(captured.timeStamp, 555);
    });
  });

  group('deleteQuestion (needs a live navigator context for the snackbar)', () {
    testWidgets('removes the item locally and refreshes the count on success',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
      viewModel.questionList = [_sampleQuestion(docId: 'doc-1')];
      when(() => repo.deleteQuestion('doc-1')).thenAnswer((_) async {});
      when(() => repo.getQuestionCount()).thenAnswer((_) async => 0);

      final result = await viewModel.deleteQuestion(docId: 'doc-1', index: 0);

      expect(result, isTrue);
      expect(viewModel.questionList, isEmpty);
      expect(viewModel.questionListLength, 0);
    });

    testWidgets(
        'returns false and leaves the list untouched when the repo throws',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox()),
      ));
      viewModel.questionList = [_sampleQuestion(docId: 'doc-1')];
      when(() => repo.deleteQuestion('doc-1')).thenThrow(Exception('boom'));

      final result = await viewModel.deleteQuestion(docId: 'doc-1', index: 0);

      expect(result, isFalse);
      expect(viewModel.questionList, hasLength(1));
    });
  });
}

extension on Question1 {
  Question1 copyWithAnswer(String answer) => Question1(
        docId: docId,
        questionCode: questionCode,
        question: question,
        questionBody: questionBody,
        hints: hints,
        solution: solution,
        answer: answer,
        option1: option1,
        option2: option2,
        option3: option3,
        option4: option4,
        timeStamp: timeStamp,
      );
}
