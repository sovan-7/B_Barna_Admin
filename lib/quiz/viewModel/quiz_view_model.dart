import 'dart:async';

import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/repo/quiz_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class QuizViewModel with ChangeNotifier {
  // Constructor-injectable so the paging, search and question-picking logic
  // can be exercised without real Firebase.
  final QuizRepo _quizRepo;
  QuizViewModel({QuizRepo? quizRepo}) : _quizRepo = quizRepo ?? QuizRepo();

  List<QuizModel> quizList = [];

  /// How many the collection holds in total, so the list can say
  /// "showing 50 of 320" rather than just "50".
  int quizLength = 0;
  final int limit = 50;

  bool isLoading = true;
  bool isLoadingMore = false;
  bool isSearching = false;

  Timer? _debounce;
  bool _disposed = false;

  bool get hasMore => !isSearching && quizList.length < quizLength;

  // ---- Question picking ------------------------------------------------

  /// Questions found by the picker's own search, minus anything already on
  /// the quiz.
  List<Question> questionList = [];

  /// The questions currently on the quiz.
  List<Question> quizQuestionList = [];

  /// True while either question query is in flight — the picker used to
  /// push the global loader dialog for these, from inside a build.
  bool isLoadingQuestions = false;

  /// The codes the quiz will be saved with.
  List<String> get selectedQuestionCodeList => [
        for (final Question question in quizQuestionList)
          question.questionCode.trim(),
      ];

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [QuizList] is mounted from
  /// `Sidebar.screenList[selectedIndex]` *during* a build.
  @override
  void notifyListeners() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        super.notifyListeners();
      });
      return;
    }
    super.notifyListeners();
  }

  Future<void> getFirstQuizList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      quizList = await _quizRepo.getFirstQuizList(limit);
      quizLength = await _quizRepo.getQuizListLength();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching quizzes", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getNextQuizList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      quizList.addAll(await _quizRepo.getNextQuizList(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more quizzes", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> addQuiz(QuizModel quizModel) async {
    try {
      await _quizRepo.addQuiz(quizModel);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while adding the quiz", isSuccess: false);
      return false;
    }
  }

  Future<bool> updateQuiz(QuizModel quizModel, String docId) async {
    try {
      await _quizRepo.updateQuiz(quizModel, docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the quiz", isSuccess: false);
      return false;
    }
  }

  Future<bool> deleteQuiz(String docId) async {
    try {
      await _quizRepo.deleteQuiz(docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the quiz", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and so [refresh]
  /// puts the same results back instead of the unfiltered first page.
  String searchText = "";

  /// Debounced prefix search on the quiz code, run server-side because the
  /// collection is paged and most of it is not in memory.
  Future<void> searchQuiz({required String searchText}) async {
    this.searchText = searchText;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  /// Reloads what the list is showing: the current search's results if
  /// there is one, otherwise the first page. The list calls this after
  /// Add/Edit rather than refetching the first page over a search.
  Future<void> refresh() {
    _debounce?.cancel();
    return _runSearch();
  }

  Future<void> _runSearch() async {
    final String query = searchText.trim();
    if (query.isEmpty) {
      await getFirstQuizList();
      return;
    }

    isSearching = true;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _quizRepo.searchQuiz(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile.
      if (query != searchText.trim()) return;
      quizList = results;
    } catch (e) {
      quizList = [];
      // The old catch popped the current route before showing this —
      // a failed search took the whole page off the navigator.
      Helper.showSnackBarMessage(
          msg: "Error while searching quizzes", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ---- The question picker --------------------------------------------

  /// Loads the questions a quiz already holds.
  Future<void> loadQuizQuestions(List<String> questionCodeList) async {
    quizQuestionList = [];
    questionList = [];
    if (questionCodeList.isEmpty) {
      notifyListeners();
      return;
    }

    isLoadingQuestions = true;
    notifyListeners();
    try {
      quizQuestionList = await _quizRepo.getQuestionsByCodes(questionCodeList);
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching the quiz's questions", isSuccess: false);
    } finally {
      isLoadingQuestions = false;
      notifyListeners();
    }
  }

  /// Searches for questions to add, hiding any already on the quiz.
  Future<void> searchQuestions(String questionCode) async {
    if (questionCode.trim().isEmpty) {
      questionList = [];
      notifyListeners();
      return;
    }

    isLoadingQuestions = true;
    notifyListeners();
    try {
      final List<Question> found =
          await _quizRepo.searchQuestions(questionCode.trim().toUpperCase());
      final Set<String> already = selectedQuestionCodeList.toSet();
      questionList = found
          .where((question) => !already.contains(question.questionCode.trim()))
          .toList();
    } catch (e) {
      questionList = [];
      Helper.showSnackBarMessage(
          msg: "Error while searching questions", isSuccess: false);
    } finally {
      isLoadingQuestions = false;
      notifyListeners();
    }
  }

  /// Moves a found question onto the quiz.
  ///
  /// The old picker toggled an `isSelected` flag on the row and left the
  /// question in both lists, so what was actually on the quiz had to be
  /// reconstructed from two half-selected lists at save time.
  void addQuestion(Question question) {
    if (selectedQuestionCodeList.contains(question.questionCode.trim())) return;
    quizQuestionList = [...quizQuestionList, question];
    questionList = questionList
        .where((candidate) => candidate.questionCode != question.questionCode)
        .toList();
    notifyListeners();
  }

  void removeQuestion(Question question) {
    quizQuestionList = quizQuestionList
        .where((candidate) => candidate.questionCode != question.questionCode)
        .toList();
    notifyListeners();
  }

  void addAllFoundQuestions() {
    for (final Question question in [...questionList]) {
      addQuestion(question);
    }
  }

  void clearQuestionPicker() {
    questionList = [];
    quizQuestionList = [];
  }
}
