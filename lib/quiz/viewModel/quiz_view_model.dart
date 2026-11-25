import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/repo/quiz_repo.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Quiz module.
///
/// Two independent parts:
/// 1. The paged/searchable quiz list (inherited from [PagedListViewModel])
///    plus add, update and delete.
/// 2. The question picker used on the Add/Edit Quiz form: which questions
///    are on the quiz ([quizQuestionList]) and which search results can
///    still be added ([questionList]).
class QuizViewModel extends PagedListViewModel<QuizModel> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final QuizRepo _quizRepo;

  QuizViewModel({QuizRepo? quizRepo}) : _quizRepo = quizRepo ?? QuizRepo();

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "quizzes";

  @override
  Future<List<QuizModel>> fetchFirstPage(int limit) =>
      _quizRepo.getFirstQuizList(limit);

  @override
  Future<List<QuizModel>> fetchNextPage(int limit) =>
      _quizRepo.getNextQuizList(limit);

  @override
  Future<int> fetchTotalCount() => _quizRepo.getQuizListLength();

  @override
  Future<List<QuizModel>> fetchSearchResults(String query) =>
      _quizRepo.searchQuiz(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Quizzes currently on screen (a page, or search results).
  List<QuizModel> get quizList => items;

  /// Total quizzes in the collection.
  int get quizLength => totalCount;

  /// Loads the first page of quizzes.
  Future<void> getFirstQuizList() => loadFirstPage();

  /// Appends the next page of quizzes.
  Future<void> getNextQuizList() => loadNextPage();

  /// Debounced prefix search on the quiz code.
  Future<void> searchQuiz({required String searchText}) => search(searchText);

  // ---- Create / update / delete ------------------------------------------

  /// Adds a new quiz document. Returns `false` (and shows a toast) on
  /// failure.
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

  /// Whether a quiz other than [exceptDocId] already uses [code]. Null when
  /// the lookup failed (a toast says so), so the caller should not save.
  Future<bool?> isCodeTaken(String code, {String? exceptDocId}) async {
    try {
      final List<String> ids = await _quizRepo.quizIdsWithCode(code);
      return ids.any((id) => id != exceptDocId);
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Couldn't check whether the code is free — try again",
          isSuccess: false);
      return null;
    }
  }

  /// Saves the edited quiz. Returns `false` (and shows a toast) on failure.
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

  /// Deletes the quiz document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> deleteQuiz(String docId) async {
    try {
      await _quizRepo.deleteQuiz(docId);
      removeLocally((item) => item.docId == docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the quiz", isSuccess: false);
      return false;
    }
  }

  // ---- Question picker state ---------------------------------------------

  /// Questions found by the picker's search, minus anything already on the
  /// quiz.
  List<Question> questionList = [];

  /// The questions currently on the quiz, in the order they were added.
  List<Question> quizQuestionList = [];

  /// True while the questions already on the quiz are loading (Edit).
  bool isLoadingAttached = false;

  /// Why the questions already on the quiz could not be loaded, or null.
  /// While set, saving is blocked: the quiz would otherwise be saved with
  /// no questions.
  String? attachedError;

  /// True while a question search is running.
  bool isSearchingQuestions = false;

  /// Why the last question search failed, or null.
  String? questionSearchError;

  /// The codes last passed to [loadQuizQuestions], for [retryAttached].
  List<String> _attachedCodes = const [];

  /// Counts searches, so only the newest one updates the results.
  int _questionSearchSeq = 0;

  /// True while either question query (load or search) is in flight.
  bool get isLoadingQuestions => isLoadingAttached || isSearchingQuestions;

  /// Whether the quiz's own question list is known, so it can be saved.
  bool get attachedQuestionsReady =>
      !isLoadingAttached && attachedError == null;

  /// The question codes the quiz will be saved with (trimmed).
  List<String> get selectedQuestionCodeList => [
        for (final Question question in quizQuestionList)
          question.questionCode.trim(),
      ];

  // ---- Question picker actions -------------------------------------------

  /// Loads the questions an existing quiz already holds (Edit Quiz). Also
  /// clears any leftover search results.
  Future<void> loadQuizQuestions(List<String> questionCodeList) async {
    _attachedCodes = questionCodeList;
    quizQuestionList = [];
    questionList = [];
    attachedError = null;
    if (questionCodeList.isEmpty) {
      notifyListeners();
      return;
    }

    isLoadingAttached = true;
    notifyListeners();
    try {
      quizQuestionList = await _quizRepo.getQuestionsByCodes(questionCodeList);
    } catch (e) {
      attachedError = "Couldn't load this quiz's questions";
      Helper.showSnackBarMessage(
          msg: "Error while fetching the quiz's questions", isSuccess: false);
    } finally {
      isLoadingAttached = false;
      notifyListeners();
    }
  }

  /// Loads the quiz's own questions again after a failure.
  Future<void> retryAttached() => loadQuizQuestions(_attachedCodes);

  /// Searches questions by code prefix, hiding any already on the quiz.
  /// An empty [questionCode] just clears the results.
  Future<void> searchQuestions(String questionCode) async {
    final int seq = ++_questionSearchSeq;
    questionSearchError = null;
    if (questionCode.trim().isEmpty) {
      questionList = [];
      isSearchingQuestions = false;
      notifyListeners();
      return;
    }

    isSearchingQuestions = true;
    notifyListeners();
    try {
      final List<Question> found =
          await _quizRepo.searchQuestions(questionCode.trim().toUpperCase());
      // A newer search has taken over meanwhile.
      if (seq != _questionSearchSeq) return;
      // Filter out questions that are already on the quiz.
      final Set<String> already = selectedQuestionCodeList.toSet();
      questionList = found
          .where((question) => !already.contains(question.questionCode.trim()))
          .toList();
    } catch (e) {
      if (seq != _questionSearchSeq) return;
      questionList = [];
      questionSearchError = "Couldn't search questions";
      Helper.showSnackBarMessage(
          msg: "Error while searching questions", isSuccess: false);
    } finally {
      if (seq == _questionSearchSeq) {
        isSearchingQuestions = false;
        notifyListeners();
      }
    }
  }

  /// Moves one found question onto the quiz (and out of the results).
  /// Ignored if the question is already on the quiz.
  void addQuestion(Question question) {
    if (selectedQuestionCodeList.contains(question.questionCode.trim())) return;
    quizQuestionList = [...quizQuestionList, question];
    questionList = questionList
        .where((candidate) => candidate.questionCode != question.questionCode)
        .toList();
    notifyListeners();
  }

  /// Takes a question off the quiz.
  void removeQuestion(Question question) {
    quizQuestionList = quizQuestionList
        .where((candidate) => candidate.questionCode != question.questionCode)
        .toList();
    notifyListeners();
  }

  /// Adds every current search result to the quiz.
  void addAllFoundQuestions() {
    // One pass and one notify, rather than addQuestion per result.
    final Set<String> already = selectedQuestionCodeList.toSet();
    final List<Question> toAdd = [
      for (final Question question in questionList)
        if (already.add(question.questionCode.trim())) question,
    ];
    if (toAdd.isEmpty) return;
    quizQuestionList = [...quizQuestionList, ...toAdd];
    final Set<String> added = {for (final q in toAdd) q.questionCode};
    questionList = questionList
        .where((candidate) => !added.contains(candidate.questionCode))
        .toList();
    notifyListeners();
  }

  /// Resets the picker when the form closes (no notify — nobody is
  /// listening by then).
  void clearQuestionPicker() {
    questionList = [];
    quizQuestionList = [];
    attachedError = null;
    questionSearchError = null;
  }
}
