import 'dart:async';

import 'package:bbarna/question1/model/question1.dart';
import 'package:bbarna/question1/repo/question1_repo.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';

/// Unlike the old `QuestionViewModel` (a single app-wide singleton shared by
/// every List/Edit screen), a fresh instance of this is created per screen
/// via `ChangeNotifierProvider` at each push. That removes the old race
/// where two Edit screens opened in quick succession could cross-populate
/// each other's shared controllers.
class Question1ViewModel extends ChangeNotifier {
  Question1ViewModel({Question1Repo? repo}) : _repo = repo ?? Question1Repo();

  final Question1Repo _repo;

  // ---- form controllers ----
  final TextEditingController questionCodeController = TextEditingController();
  final HtmlEditorController questionController = HtmlEditorController();
  final HtmlEditorController questionBodyController = HtmlEditorController();
  final HtmlEditorController solutionController = HtmlEditorController();
  final HtmlEditorController optionOneController = HtmlEditorController();
  final HtmlEditorController optionTwoController = HtmlEditorController();
  final HtmlEditorController optionThreeController = HtmlEditorController();
  final HtmlEditorController optionFourController = HtmlEditorController();
  final HtmlEditorController hintController = HtmlEditorController();

  // Plain-text cache kept in sync via each editor's onChangeContent callback
  // (and set directly by loadForEdit/resetForm). Validation and save read
  // these instead of the async `controller.getText()` bridge, so both are
  // synchronous, race-free, and don't need a live editor to test.
  String _questionText = "";
  String _questionBodyText = "";
  String _solutionText = "";
  String _option1Text = "";
  String _option2Text = "";
  String _option3Text = "";
  String _option4Text = "";
  String _hintsText = "";

  int selectIndex = -1;

  // ---- editor readiness ----
  // html_editor_enhanced's controllers can't be used (setText/insertText)
  // until each editor's underlying iframe/WebView has fired onInit. The old
  // module papered over this with a blind `Future.delayed(seconds: 2)`;
  // this counts real init callbacks instead so Edit screens know exactly
  // when it's safe to populate the editors.
  static const int _editorCount = 8;
  int _readyEditorCount = 0;
  bool get allEditorsReady => _readyEditorCount >= _editorCount;

  void onEditorInit() {
    _readyEditorCount++;
    if (allEditorsReady) notifyListeners();
  }

  void onQuestionChanged(String? value) => _questionText = value ?? "";
  void onQuestionBodyChanged(String? value) => _questionBodyText = value ?? "";
  void onSolutionChanged(String? value) => _solutionText = value ?? "";
  void onOption1Changed(String? value) => _option1Text = value ?? "";
  void onOption2Changed(String? value) => _option2Text = value ?? "";
  void onOption3Changed(String? value) => _option3Text = value ?? "";
  void onOption4Changed(String? value) => _option4Text = value ?? "";
  void onHintsChanged(String? value) => _hintsText = value ?? "";

  void setSelectedIndex(int index) {
    selectIndex = index;
    notifyListeners();
  }

  void loadForEdit(Question1 question) {
    questionCodeController.text = question.questionCode;
    questionController.setText(question.question);
    questionBodyController.setText(question.questionBody);
    solutionController.setText(question.solution);
    optionOneController.setText(question.option1);
    optionTwoController.setText(question.option2);
    optionThreeController.setText(question.option3);
    optionFourController.setText(question.option4);
    hintController.setText(question.hints);

    _questionText = question.question;
    _questionBodyText = question.questionBody;
    _solutionText = question.solution;
    _option1Text = question.option1;
    _option2Text = question.option2;
    _option3Text = question.option3;
    _option4Text = question.option4;
    _hintsText = question.hints;
    selectIndex = _matchOption(question.answer, question);
    notifyListeners();
  }

  int _matchOption(String answer, Question1 question) {
    if (question.option1 == answer) return 1;
    if (question.option2 == answer) return 2;
    if (question.option3 == answer) return 3;
    if (question.option4 == answer) return 4;
    // Unlike the old module, don't silently assume option 4 when nothing
    // matches — leave no answer selected so the validator catches it.
    return -1;
  }

  void resetForm() {
    questionCodeController.clear();
    questionController.clear();
    questionBodyController.clear();
    solutionController.clear();
    optionOneController.clear();
    optionTwoController.clear();
    optionThreeController.clear();
    optionFourController.clear();
    hintController.clear();
    _questionText = "";
    _questionBodyText = "";
    _solutionText = "";
    _option1Text = "";
    _option2Text = "";
    _option3Text = "";
    _option4Text = "";
    _hintsText = "";
    selectIndex = -1;
    notifyListeners();
  }

  /// Full-field validation — the old Add screen only checked 3 of 9 fields.
  /// Returns a user-facing message, or null when the form is valid.
  String? validate() {
    if (questionCodeController.text.trim().isEmpty) {
      return "Please add question code";
    }
    if (_questionText.trim().isEmpty) return "Please add question";
    if (_questionBodyText.trim().isEmpty) return "Please add question body";
    if (_option1Text.trim().isEmpty) return "Please add option A";
    if (_option2Text.trim().isEmpty) return "Please add option B";
    if (_option3Text.trim().isEmpty) return "Please add option C";
    if (_option4Text.trim().isEmpty) return "Please add option D";
    if (_hintsText.trim().isEmpty) return "Please add hints";
    if (_solutionText.trim().isEmpty) return "Please add solution";
    if (selectIndex == -1) return "Please select the correct answer";
    return null;
  }

  String get _selectedAnswerText {
    switch (selectIndex) {
      case 1:
        return _option1Text;
      case 2:
        return _option2Text;
      case 3:
        return _option3Text;
      case 4:
        return _option4Text;
      default:
        return "";
    }
  }

  Question1 _buildQuestionFromForm({String docId = "", int? timeStamp}) {
    return Question1(
      docId: docId,
      questionCode: questionCodeController.text.trim().toUpperCase(),
      question: _questionText,
      questionBody: _questionBodyText,
      hints: _hintsText,
      solution: _solutionText,
      answer: _selectedAnswerText,
      option1: _option1Text,
      option2: _option2Text,
      option3: _option3Text,
      option4: _option4Text,
      timeStamp: timeStamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> addQuestion() async {
    try {
      await _repo.addQuestion(_buildQuestionFromForm());
      resetForm();
      Helper.showSnackBarMessage(
          msg: "Question added successfully", isSuccess: true);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error adding data: $e", isSuccess: false);
      return false;
    }
  }

  /// [timeStamp] is passed in (the original doc's) and reused rather than
  /// bumped, matching the old module's behavior of not reordering a question
  /// in the list just because it was edited.
  Future<bool> updateQuestion(
      {required String docId, required int timeStamp}) async {
    try {
      await _repo.updateQuestion(
          docId, _buildQuestionFromForm(docId: docId, timeStamp: timeStamp));
      Helper.showSnackBarMessage(
          msg: "Question updated successfully", isSuccess: true);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(msg: "Error while updating", isSuccess: false);
      return false;
    }
  }

  // ---- list / pagination state ----
  List<Question1> questionList = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _docList = [];
  // Cursors of pages already visited, so "Previous" re-queries Firestore for
  // the exact prior page instead of truncating the in-memory list (the old
  // module's `removeQuestionFromLast` never reset its cursor, so a
  // subsequent "Next" could duplicate/skip items).
  final List<DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [];
  DocumentSnapshot<Map<String, dynamic>>? _currentCursor;
  int questionListLength = 0;
  int limit = 50;
  Timer? _debounce;

  Future<void> refreshCount() async {
    questionListLength = await _repo.getQuestionCount();
    notifyListeners();
  }

  /// True while a page of questions is loading; the list shows a progress
  /// bar meanwhile.
  bool loading = false;

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }

  Future<void> fetchFirstPage() async {
    try {
      _setLoading(true);
      final page = await _repo.getPage(limit: limit);
      questionList = page.items;
      _docList = page.docs;
      _cursorStack.clear();
      _currentCursor = null;
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      Helper.showSnackBarMessage(
          msg: "Error while fetching data", isSuccess: false);
    }
  }

  Future<void> fetchNextPage() async {
    if (_docList.isEmpty) return;
    try {
      _setLoading(true);
      final nextCursor = _docList.last;
      final page = await _repo.getPage(limit: limit, startAfter: nextCursor);
      if (page.items.isEmpty) {
        _setLoading(false);
        Helper.showSnackBarMessage(
            msg: "You are already in last page", isSuccess: false);
        return;
      }
      _cursorStack.add(_currentCursor);
      _currentCursor = nextCursor;
      questionList = page.items;
      _docList = page.docs;
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      Helper.showSnackBarMessage(
          msg: "Error while fetching data", isSuccess: false);
    }
  }

  Future<void> fetchPreviousPage() async {
    if (_cursorStack.isEmpty) {
      Helper.showSnackBarMessage(
          msg: "You are already in first page", isSuccess: false);
      return;
    }
    try {
      _setLoading(true);
      final prevCursor = _cursorStack.removeLast();
      final page = await _repo.getPage(limit: limit, startAfter: prevCursor);
      _currentCursor = prevCursor;
      questionList = page.items;
      _docList = page.docs;
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      Helper.showSnackBarMessage(
          msg: "Error while fetching data", isSuccess: false);
    }
  }

  Future<bool> deleteQuestion(
      {required String docId, required int index}) async {
    try {
      await _repo.deleteQuestion(docId);
      questionList.removeAt(index);
      if (index < _docList.length) _docList.removeAt(index);
      questionListLength = await _repo.getQuestionCount();
      Helper.showSnackBarMessage(
          msg: "Question deleted successfully", isSuccess: true);
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(msg: "Error while deleting", isSuccess: false);
      return false;
    }
  }

  Future<void> searchByCode(String text) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (text.isEmpty) {
        await fetchFirstPage();
        return;
      }
      try {
        questionList = await _repo.searchByCode(text);
        notifyListeners();
      } catch (e) {
        Helper.showSnackBarMessage(
            msg: "Error while fetching data", isSuccess: false);
      }
    });
  }

  @override
  void dispose() {
    questionCodeController.dispose();
    _debounce?.cancel();
    super.dispose();
    // HtmlEditorController has no dispose() method to call.
  }
}
