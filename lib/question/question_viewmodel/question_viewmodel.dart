import 'dart:async';

import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/question/repo/question_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Questions: the list, its paging, and saving one.
///
/// This used to own eight `HtmlEditorController`s and a
/// `TextEditingController` as well — the add and edit screens both wrote
/// into the same set. Two forms open at once shared one buffer, and closing
/// a form left whatever was typed in it behind for the next one. Form state
/// belongs to the form; this holds only what the list needs.
class QuestionViewModel extends ChangeNotifier {
  // Constructor-injectable so the paging, search and save logic can be
  // exercised without real Firebase.
  final QuestionRepo _questionRepo;
  QuestionViewModel({QuestionRepo? questionRepo})
      : _questionRepo = questionRepo ?? QuestionRepo();

  List<Question> questionList = [];

  /// How many the collection holds in total, so the list can say
  /// "showing 50 of 320" rather than just "50".
  int questionListLength = 0;
  final int limit = 50;

  bool isLoading = true;
  bool isLoadingMore = false;

  /// Set while a search is showing, because searching queries the server
  /// separately and paging does not apply to the result.
  bool isSearching = false;

  Timer? _debounce;
  bool _disposed = false;

  bool get hasMore =>
      !isSearching && questionList.length < questionListLength;

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [QuestionList] is mounted
  /// from `Sidebar.screenList[selectedIndex]` *during* a build.
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

  Future<void> fetchFirstQuestionList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      questionList = await _questionRepo.getFirstQuestionList(limit);
      questionListLength = await _questionRepo.getQuestionListLength();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching questions", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextQuestionList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      questionList.addAll(await _questionRepo.getNextQuestionList(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more questions", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

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

  /// Deletes by document id and drops that row from the list.
  ///
  /// It used to take a *list index* and `removeAt` it, so a delete confirmed
  /// after a search or another page had loaded removed whichever row now sat
  /// at that position.
  Future<bool> deleteQuestion(String docId) async {
    try {
      await _questionRepo.deleteQuestion(docId);
      questionList =
          questionList.where((question) => question.docId != docId).toList();
      if (questionListLength > 0) questionListLength--;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the question", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and so [refresh]
  /// puts the same results back instead of the unfiltered first page.
  String searchText = "";

  /// Debounced prefix search on the question code, run server-side because
  /// the collection is paged and most of it is not in memory.
  Future<void> searchQuestion({required String searchText}) async {
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
      await fetchFirstQuestionList();
      return;
    }

    isSearching = true;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _questionRepo
          .searchQuestion(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile.
      if (query != searchText.trim()) return;
      questionList = results;
    } catch (e) {
      questionList = [];
      // The old catch popped the current route before showing this —
      // a failed search took the whole page off the navigator.
      Helper.showSnackBarMessage(
          msg: "Error while searching questions", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
