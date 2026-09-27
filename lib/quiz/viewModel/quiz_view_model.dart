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

  /// True while either question query (load or search) is in flight.
  bool isLoadingQuestions = false;

  /// The question codes the quiz will be saved with (trimmed).
  List<String> get selectedQuestionCodeList => [
        for (final Question question in quizQuestionList)
          question.questionCode.trim(),
      ];

  // ---- Question picker actions -------------------------------------------

  /// Loads the questions an existing quiz already holds (Edit Quiz). Also
  /// clears any leftover search results.
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

  /// Searches questions by code prefix, hiding any already on the quiz.
  /// An empty [questionCode] just clears the results.
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
      // Filter out questions that are already on the quiz.
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
    // Iterate over a copy: addQuestion rewrites questionList as it goes.
    for (final Question question in [...questionList]) {
      addQuestion(question);
    }
  }

  /// Resets the picker when the form closes (no notify — nobody is
  /// listening by then).
  void clearQuestionPicker() {
    questionList = [];
    quizQuestionList = [];
  }
}
