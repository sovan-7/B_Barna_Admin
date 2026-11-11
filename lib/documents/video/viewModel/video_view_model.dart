import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/repo/video_repo.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Video module: the paged/searchable video list
/// (inherited from [PagedListViewModel]) plus add, update and delete.
/// Videos are links, so there is no file upload here.
class VideoViewModel extends PagedListViewModel<VideoModel> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final VideoRepo _videoRepo;

  VideoViewModel({VideoRepo? videoRepo})
      : _videoRepo = videoRepo ?? VideoRepo();

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "videos";

  @override
  Future<List<VideoModel>> fetchFirstPage(int limit) =>
      _videoRepo.getFirstVideoList(limit);

  @override
  Future<List<VideoModel>> fetchNextPage(int limit) =>
      _videoRepo.getNextVideoList(limit);

  @override
  Future<int> fetchTotalCount() => _videoRepo.getVideoListLength();

  @override
  Future<List<VideoModel>> fetchSearchResults(String query) =>
      _videoRepo.searchVideo(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Videos currently on screen (a page, or search results).
  List<VideoModel> get videoList => items;

  /// Total videos in the collection.
  int get videoListLength => totalCount;

  /// Loads the first page of videos.
  Future<void> getFirstVideoList() => loadFirstPage();

  /// Appends the next page of videos.
  Future<void> getNextVideoList() => loadNextPage();

  /// Debounced prefix search on the video code.
  Future<void> searchVideo({required String searchText}) => search(searchText);

  // ---- Create / update / delete ------------------------------------------

  /// Adds a new video document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> addVideo(VideoModel videoModel) async {
    try {
      await _videoRepo.addVideo(videoModel);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while adding the video", isSuccess: false);
      return false;
    }
  }

  /// Saves the edited video. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> updateVideo(VideoModel videoModel, String docId) async {
    try {
      await _videoRepo.updateVideo(videoModel, docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the video", isSuccess: false);
      return false;
    }
  }

  /// Deletes the video document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> deleteVideo(String docId) async {
    try {
      await _videoRepo.deleteVideo(docId);
      removeLocally((item) => item.docId == docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the video", isSuccess: false);
      return false;
    }
  }
}
