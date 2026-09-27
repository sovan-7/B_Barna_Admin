import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/question/repo/question_repo.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Question module: the paged/searchable
/// question list (inherited from [PagedListViewModel]) plus create, update
/// and delete.
///
/// Form state (the rich-text editors) lives in the form widget itself, so
/// two open forms never share a buffer. This class only holds what the
/// list needs.
class QuestionViewModel extends PagedListViewModel<Question> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final QuestionRepo _questionRepo;

  QuestionViewModel({QuestionRepo? questionRepo})
      : _questionRepo = questionRepo ?? QuestionRepo();

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "questions";

  @override
  Future<List<Question>> fetchFirstPage(int limit) =>
      _questionRepo.getFirstQuestionList(limit);

  @override
  Future<List<Question>> fetchNextPage(int limit) =>
      _questionRepo.getNextQuestionList(limit);

  @override
  Future<int> fetchTotalCount() => _questionRepo.getQuestionListLength();

  @override
  Future<List<Question>> fetchSearchResults(String query) =>
      _questionRepo.searchQuestion(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Questions currently on screen (a page, or search results).
  List<Question> get questionList => items;

  /// Total questions in the collection.
  int get questionListLength => totalCount;

  /// Loads the first page of questions.
  Future<void> fetchFirstQuestionList() => loadFirstPage();

  /// Appends the next page of questions.
  Future<void> fetchNextQuestionList() => loadNextPage();

  /// Debounced prefix search on the question code.
  Future<void> searchQuestion({required String searchText}) =>
      search(searchText);

  // ---- Create / update / delete ------------------------------------------

  /// Saves a new question built from the form's [draft], stamped with the
  /// current time. Returns `false` (and shows a toast) on failure.
  Future<bool> createQuestion(QuestionDraft draft) async {
    try {
      await _questionRepo.addQuestion(
          draft.toMap(timeStamp: DateTime.now().millisecondsSinceEpoch));
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while adding the question", isSuccess: false);
      return false;
    }
  }

  /// Overwrites question [docId] with [draft]. [timeStamp] is the original
  /// creation time, kept so the list order does not change.
  Future<bool> updateQuestion(String docId, QuestionDraft draft,
      {required int timeStamp}) async {
    try {
      await _questionRepo.updateQuestion(
          docId, draft.toMap(timeStamp: timeStamp));
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the question", isSuccess: false);
      return false;
    }
  }

  /// Deletes by document id and, on success, drops that row from the list
  /// and lowers the total count.
  Future<bool> deleteQuestion(String docId) async {
    try {
      await _questionRepo.deleteQuestion(docId);
      items = items.where((question) => question.docId != docId).toList();
      if (totalCount > 0) totalCount--;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the question", isSuccess: false);
      return false;
    }
  }
}
