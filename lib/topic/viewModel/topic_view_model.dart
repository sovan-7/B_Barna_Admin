import 'dart:async';

import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/repo/topic_repo.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class TopicViewModel with ChangeNotifier {
  // Constructor-injectable so the paging, search and save logic can be
  // exercised without real Firebase.
  final TopicRepo _topicRepo;
  TopicViewModel({TopicRepo? topicRepo}) : _topicRepo = topicRepo ?? TopicRepo();

  List<TopicModel> topicList = [];
  List<SubjectModel> subjectList = [];
  List<UnitModel> unitList = [];

  /// How many topics the collection holds in total, so the list can say
  /// "showing 50 of 320" rather than just "50".
  int topicLength = 0;
  final int limit = 50;

  /// True while the first page is in flight — drives the skeletons. The
  /// module used to reach for the global `LoaderDialogs` overlay, which
  /// pushes a route, from `initState` while the shell was still building.
  bool isLoading = true;

  /// True while a further page is in flight, so "Load more" can show a
  /// spinner without blanking the rows already on screen.
  bool isLoadingMore = false;

  /// Set while a search is showing, because searching queries the server
  /// separately and paging does not apply to the result.
  bool isSearching = false;

  Timer? _debounce;
  bool _disposed = false;

  bool get hasMore => !isSearching && topicList.length < topicLength;

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [TopicList] is mounted from
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

  /// Loads the first page and the total count together.
  Future<void> getFirstTopicList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      topicList = await _topicRepo.getFirstTopicList(limit);
      topicLength = await _topicRepo.getTopicListLength();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching topics", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page. This is what the old "Next" button did too —
  /// it grew one list rather than turning a page, which is why its
  /// "Previous" counterpart could only ever chop rows back off the end.
  Future<void> getNextTopicList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      topicList.addAll(await _topicRepo.getNextTopicList(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more topics", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> getSubjectList({required String courseCode}) async {
    try {
      subjectList = await _topicRepo.getSubjectList(courseCode: courseCode);
    } catch (e) {
      subjectList = [];
    }
    notifyListeners();
  }

  Future<void> getUnitList({required String subjectCode}) async {
    try {
      unitList = await _topicRepo.getUnitList(subjectCode: subjectCode);
    } catch (e) {
      unitList = [];
    }
    notifyListeners();
  }

  Future<bool> createTopic(TopicModel topicModel) async {
    try {
      await _topicRepo.addTopic(topicModel);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while adding the topic", isSuccess: false);
      return false;
    }
  }

  Future<bool> updateTopic(TopicModel topicModel, String docId) async {
    try {
      await _topicRepo.updateTopic(topicModel, docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the topic", isSuccess: false);
      return false;
    }
  }

  /// The row is only dropped from the list once the delete has actually
  /// gone through. The old version removed it first and reported success
  /// from `whenComplete`, which runs on failure too — a failed delete left
  /// the topic in Firestore but gone from the screen.
  Future<bool> deleteTopic(String docId) async {
    try {
      await _topicRepo.deleteTopic(docId);
      topicList.removeWhere((element) => element.docId == docId);
      if (topicLength > 0) topicLength--;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the topic", isSuccess: false);
      return false;
    }
  }

  /// Writes one content array and mirrors it onto the in-memory model, so
  /// the list's counts are right without refetching the whole page.
  Future<bool> saveContentCodes(
      TopicModel topicModel, ContentKind kind, List<String> codes) async {
    try {
      await _topicRepo.setContentCodes(topicModel.docId, kind, codes);
      topicModel.setContentCodes(kind, codes);
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while saving ${kind.inlineLabel} codes",
          isSuccess: false);
      return false;
    }
  }

  /// Which of [codes] actually exist in their own collection, as
  /// `code -> title`. Anything missing from the result is a code that
  /// points at nothing.
  Future<Map<String, String>> resolveContentTitles(
      ContentKind kind, List<String> codes) async {
    try {
      return await _topicRepo.resolveContentTitles(kind, codes);
    } catch (e) {
      return <String, String>{};
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and so [refresh]
  /// puts the same results back instead of the unfiltered first page.
  String searchText = "";

  /// Debounced prefix search on the topic code, run server-side because
  /// the collection is paged and most of it is not in memory.
  Future<void> searchTopic({required String searchText}) async {
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
      await getFirstTopicList();
      return;
    }

    isSearching = true;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _topicRepo.searchTopic(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile.
      if (query != searchText.trim()) return;
      topicList = results;
    } catch (e) {
      topicList = [];
      // The old catch popped the current route before showing this —
      // a failed search took the whole page off the navigator.
      Helper.showSnackBarMessage(
          msg: "Error while searching topics", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
