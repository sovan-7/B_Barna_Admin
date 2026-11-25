import 'dart:typed_data';

import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/repo/audio_repo.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Audio module: the paged/searchable clip list
/// (inherited from [PagedListViewModel]) plus create, update and delete.
class AudioViewModel extends PagedListViewModel<AudioModel> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final AudioRepo _audioRepo;

  AudioViewModel({AudioRepo? audioRepo})
      : _audioRepo = audioRepo ?? AudioRepo();

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "audio clips";

  @override
  Future<List<AudioModel>> fetchFirstPage(int limit) =>
      _audioRepo.getFirstAudioList(limit);

  @override
  Future<List<AudioModel>> fetchNextPage(int limit) =>
      _audioRepo.getNextAudioList(limit);

  @override
  Future<int> fetchTotalCount() => _audioRepo.getAudioListLength();

  @override
  Future<List<AudioModel>> fetchSearchResults(String query) =>
      _audioRepo.searchAudio(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Clips currently on screen (a page, or search results).
  List<AudioModel> get audioList => items;

  /// Total clips in the collection.
  int get audioListLength => totalCount;

  /// Loads the first page of clips.
  Future<void> getFirstAudioList() => loadFirstPage();

  /// Appends the next page of clips.
  Future<void> getNextAudioList() => loadNextPage();

  /// Debounced prefix search on the audio code.
  Future<void> searchAudio({required String searchText}) => search(searchText);

  // ---- Create / update / delete ------------------------------------------

  /// Creates the document and uploads its file as one operation.
  ///
  /// An audio row exists only to point at a file, so if the upload fails
  /// the new (empty) document is deleted again and `false` is returned.
  Future<bool> createAudio(AudioModel audioModel, Uint8List file) async {
    String? docId;
    try {
      docId = await _audioRepo.addAudio(audioModel);
      await _audioRepo.uploadAudio(file, docId);
      return true;
    } catch (e) {
      // Roll back the half-created row; ignore a failure to do so.
      if (docId != null) {
        try {
          await _audioRepo.deleteAudio(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while adding the audio clip", isSuccess: false);
      return false;
    }
  }

  /// Saves the edited fields. [file] is null when the admin did not pick a
  /// new file — the existing one is then left exactly as it is.
  Future<bool> updateAudio(AudioModel audioModel, String docId,
      {Uint8List? file}) async {
    try {
      await _audioRepo.updateAudio(audioModel, docId);
      if (file != null) {
        await _audioRepo.uploadAudio(file, docId);
      }
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the audio clip", isSuccess: false);
      return false;
    }
  }

  /// Deletes the clip document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> deleteAudio(String docId) async {
    try {
      await _audioRepo.deleteAudio(docId);
      removeLocally((item) => item.docId == docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the audio clip", isSuccess: false);
      return false;
    }
  }
}
