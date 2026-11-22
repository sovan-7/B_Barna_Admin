import 'package:bbarna/core/viewModel/async_list.dart';
import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/repo/topic1_repo.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Topic1 module: the paged/searchable list
/// (inherited from [PagedListViewModel]), create/update/delete, the
/// subject/unit lists for the form dropdowns, and the content on each
/// topic — uploaded PDFs, YouTube videos, and audio/quiz codes.
class Topic1ViewModel extends PagedListViewModel<Topic1Model> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final Topic1Repo _repo;

  Topic1ViewModel({Topic1Repo? topic1Repo})
      : _repo = topic1Repo ?? Topic1Repo();

  /// Subjects of the course chosen on the Add/Edit form, with their
  /// loading / error state.
  final AsyncList<SubjectModel> subjectsForCourse = AsyncList<SubjectModel>();

  /// Units of the subject chosen on the Add/Edit form, with their loading /
  /// error state.
  final AsyncList<UnitModel> unitsForSubject = AsyncList<UnitModel>();

  /// The options in [subjectsForCourse].
  List<SubjectModel> get subjectList => subjectsForCourse.items;

  /// The options in [unitsForSubject].
  List<UnitModel> get unitList => unitsForSubject.items;

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "topics";

  @override
  Future<List<Topic1Model>> fetchFirstPage(int limit) =>
      _repo.getFirstTopicList(limit);

  @override
  Future<List<Topic1Model>> fetchNextPage(int limit) =>
      _repo.getNextTopicList(limit);

  @override
  Future<int> fetchTotalCount() => _repo.getTopicListLength();

  @override
  Future<List<Topic1Model>> fetchSearchResults(String query) =>
      _repo.searchTopic(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Topics currently on screen (a page, or search results).
  List<Topic1Model> get topicList => items;

  /// Total topics in the collection.
  int get topicLength => totalCount;

  /// Loads the first page.
  Future<void> getFirstTopicList() => loadFirstPage();

  /// Appends the next page.
  Future<void> getNextTopicList() => loadNextPage();

  /// Debounced prefix search on the topic code.
  Future<void> searchTopic({required String searchText}) => search(searchText);

  // ---- Form dropdown data ------------------------------------------------

  /// Loads the subjects of [courseCode] (and clears the unit options,
  /// which belonged to the previous subject).
  Future<void> getSubjectList({required String courseCode}) {
    unitsForSubject.reset();
    return subjectsForCourse.load(
      () => _repo.getSubjectList(courseCode: courseCode),
      errorMessage: "Couldn't load subjects",
      onChange: notifyListeners,
    );
  }

  /// Loads the units of [subjectCode].
  Future<void> getUnitList({required String subjectCode}) =>
      unitsForSubject.load(
        () => _repo.getUnitList(subjectCode: subjectCode),
        errorMessage: "Couldn't load units",
        onChange: notifyListeners,
      );

  // ---- Create / update / delete ------------------------------------------

  /// Adds a new topic document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> createTopic(Topic1Model topicModel) async {
    try {
      await _repo.addTopic(topicModel);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while adding the topic", isSuccess: false);
      return false;
    }
  }

  /// Saves the edited topic. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> updateTopic(Topic1Model topicModel, String docId) async {
    try {
      await _repo.updateTopic(topicModel, docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the topic", isSuccess: false);
      return false;
    }
  }

  /// Deletes the topic, then (quietly) its uploaded PDF files. The row is
  /// removed from the list (and the total lowered) only after Firestore
  /// confirms the delete.
  Future<bool> deleteTopic(Topic1Model topicModel) async {
    final String docId = topicModel.docId;
    try {
      await _repo.deleteTopic(docId);
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the topic", isSuccess: false);
      return false;
    }
    items.removeWhere((element) => element.docId == docId);
    if (totalCount > 0) totalCount--;
    notifyListeners();
    await _repo
        .deletePdfFiles(topicModel.pdfList.map((pdf) => pdf.storagePath));
    return true;
  }

  // ---- Content -------------------------------------------------------------

  /// Saves the PDF list from the editor's [drafts], in order.
  ///
  /// Newly picked files are uploaded first; then `pdf_list` is written in
  /// one go. If anything fails, the files uploaded by this save are
  /// deleted again and the topic keeps what it had. Once the list is
  /// saved, the files no entry points at any more (removed rows, replaced
  /// files) are deleted, and the in-memory [topicModel] is updated so the
  /// list's counts change without a refetch.
  Future<bool> savePdfs(
      Topic1Model topicModel, List<Topic1PdfDraft> drafts) async {
    final List<String> uploadedPaths = [];
    final List<Topic1Pdf> pdfs = [];
    try {
      for (final Topic1PdfDraft draft in drafts) {
        String link = draft.existing?.link ?? "";
        String path = draft.existing?.storagePath ?? "";
        String fileName = draft.existing?.fileName ?? "";
        if (draft.newBytes != null) {
          final Topic1UploadedPdf uploaded =
              await _repo.uploadPdfFile(topicModel.docId, draft.newBytes!);
          uploadedPaths.add(uploaded.path);
          link = uploaded.url;
          path = uploaded.path;
          fileName = draft.newFileName ?? "";
        }
        pdfs.add(Topic1Pdf(
          id: draft.id,
          title: draft.title,
          fileName: fileName,
          link: link,
          storagePath: path,
          type: draft.type,
          isDownloadable: draft.isDownloadable,
        ));
      }
      await _repo.setPdfList(topicModel.docId, pdfs);
    } catch (e) {
      await _repo.deletePdfFiles(uploadedPaths);
      Helper.showSnackBarMessage(
          msg: "Error while saving PDFs", isSuccess: false);
      return false;
    }

    final Set<String> stillUsed = pdfs.map((pdf) => pdf.storagePath).toSet();
    final List<String> unused = [
      for (final Topic1Pdf old in topicModel.pdfList)
        if (!stillUsed.contains(old.storagePath)) old.storagePath,
    ];
    topicModel.pdfList = pdfs;
    notifyListeners();
    await _repo.deletePdfFiles(unused);
    return true;
  }

  /// Saves the video list (links already checked and normalised by the
  /// editor) and mirrors it onto [topicModel].
  Future<bool> saveVideos(
      Topic1Model topicModel, List<Topic1Video> videos) async {
    try {
      await _repo.setVideoList(topicModel.docId, videos);
      topicModel.videoList = videos;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while saving videos", isSuccess: false);
      return false;
    }
  }

  /// Saves the audio or quiz codes ([kind]) and mirrors them onto
  /// [topicModel].
  Future<bool> saveContentCodes(
      Topic1Model topicModel, ContentKind kind, List<String> codes) async {
    try {
      await _repo.setContentCodes(topicModel.docId, kind, codes);
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
  /// `code -> title`. Returns null when the lookup failed, so a failure is
  /// never mistaken for "no item has this code".
  Future<Map<String, String>?> resolveContentTitles(
      ContentKind kind, List<String> codes) async {
    try {
      return await _repo.resolveContentTitles(kind, codes);
    } catch (e) {
      return null;
    }
  }
}
