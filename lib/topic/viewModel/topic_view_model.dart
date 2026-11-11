import 'package:bbarna/core/viewModel/async_list.dart';
import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/repo/topic_repo.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Topic module: the paged/searchable topic list
/// (inherited from [PagedListViewModel]), create/update/delete, the
/// subject/unit lists for the form dropdowns, and the topic's attached
/// content codes (videos, PDFs, audio, quizzes).
class TopicViewModel extends PagedListViewModel<TopicModel> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final TopicRepo _topicRepo;

  TopicViewModel({TopicRepo? topicRepo})
      : _topicRepo = topicRepo ?? TopicRepo();

  /// Subjects of the course chosen on the Add/Edit Topic form, with their
  /// loading / error state.
  final AsyncList<SubjectModel> subjectsForCourse = AsyncList<SubjectModel>();

  /// Units of the subject chosen on the Add/Edit Topic form, with their
  /// loading / error state.
  final AsyncList<UnitModel> unitsForSubject = AsyncList<UnitModel>();

  /// The options in [subjectsForCourse].
  List<SubjectModel> get subjectList => subjectsForCourse.items;

  /// The options in [unitsForSubject].
  List<UnitModel> get unitList => unitsForSubject.items;

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "topics";

  @override
  Future<List<TopicModel>> fetchFirstPage(int limit) =>
      _topicRepo.getFirstTopicList(limit);

  @override
  Future<List<TopicModel>> fetchNextPage(int limit) =>
      _topicRepo.getNextTopicList(limit);

  @override
  Future<int> fetchTotalCount() => _topicRepo.getTopicListLength();

  @override
  Future<List<TopicModel>> fetchSearchResults(String query) =>
      _topicRepo.searchTopic(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Topics currently on screen (a page, or search results).
  List<TopicModel> get topicList => items;

  /// Total topics in the collection.
  int get topicLength => totalCount;

  /// Loads the first page of topics.
  Future<void> getFirstTopicList() => loadFirstPage();

  /// Appends the next page of topics.
  Future<void> getNextTopicList() => loadNextPage();

  /// Debounced prefix search on the topic code.
  Future<void> searchTopic({required String searchText}) => search(searchText);

  // ---- Form dropdown data ------------------------------------------------

  /// Loads the subjects of [courseCode] (and clears the unit options,
  /// which belonged to the previous subject).
  Future<void> getSubjectList({required String courseCode}) {
    unitsForSubject.reset();
    return subjectsForCourse.load(
      () => _topicRepo.getSubjectList(courseCode: courseCode),
      errorMessage: "Couldn't load subjects",
      onChange: notifyListeners,
    );
  }

  /// Loads the units of [subjectCode].
  Future<void> getUnitList({required String subjectCode}) =>
      unitsForSubject.load(
        () => _topicRepo.getUnitList(subjectCode: subjectCode),
        errorMessage: "Couldn't load units",
        onChange: notifyListeners,
      );

  // ---- Create / update / delete ------------------------------------------

  /// Adds a new topic document. Returns `false` (and shows a toast) on
  /// failure.
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

  /// Saves the edited topic. Returns `false` (and shows a toast) on
  /// failure.
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

  /// Deletes the topic. The row is removed from the list (and the total
  /// lowered) only after Firestore confirms the delete.
  Future<bool> deleteTopic(String docId) async {
    try {
      await _topicRepo.deleteTopic(docId);
      items.removeWhere((element) => element.docId == docId);
      if (totalCount > 0) totalCount--;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the topic", isSuccess: false);
      return false;
    }
  }

  // ---- Attached content ----------------------------------------------------

  /// Saves one content array ([kind] = videos, PDFs, …) and mirrors it onto
  /// the in-memory [topicModel], so the list's counts update without a
  /// refetch.
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

  /// Looks up which of [codes] exist in their own collection, returned as
  /// `code -> title`. A code missing from the result points at nothing.
  /// Returns null when the lookup failed, so a failure is never mistaken
  /// for "no item has this code".
  Future<Map<String, String>?> resolveContentTitles(
      ContentKind kind, List<String> codes) async {
    try {
      return await _topicRepo.resolveContentTitles(kind, codes);
    } catch (e) {
      return null;
    }
  }
}
