import 'dart:async';
import 'dart:typed_data';

import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/repo/audio_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AudioViewModel with ChangeNotifier {
  // Constructor-injectable so the paging, search and save logic can be
  // exercised without real Firebase.
  final AudioRepo _audioRepo;
  AudioViewModel({AudioRepo? audioRepo}) : _audioRepo = audioRepo ?? AudioRepo();

  List<AudioModel> audioList = [];

  /// How many the collection holds in total, so the list can say
  /// "showing 50 of 320" rather than just "50".
  int audioListLength = 0;
  final int limit = 50;

  bool isLoading = true;
  bool isLoadingMore = false;

  /// Set while a search is showing, because searching queries the server
  /// separately and paging does not apply to the result.
  bool isSearching = false;

  Timer? _debounce;
  bool _disposed = false;

  bool get hasMore => !isSearching && audioList.length < audioListLength;

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [AudioList] is mounted from
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

  Future<void> getFirstAudioList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      audioList = await _audioRepo.getFirstAudioList(limit);
      audioListLength = await _audioRepo.getAudioListLength();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching audio clips", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getNextAudioList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      audioList.addAll(await _audioRepo.getNextAudioList(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more audio clips", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its file as one operation.
  ///
  /// An audio row exists only to point at a file, so a document whose upload
  /// failed is not a partial clip — it is a broken row. The empty document
  /// is removed again and the caller is told the truth.
  Future<bool> createAudio(AudioModel audioModel, Uint8List file) async {
    String? docId;
    try {
      docId = await _audioRepo.addAudio(audioModel);
      await _audioRepo.uploadAudio(file, docId);
      return true;
    } catch (e) {
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

  /// [file] is null when the admin did not pick a new one — the existing
  /// file is then left exactly as it is.
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

  Future<bool> deleteAudio(String docId) async {
    try {
      await _audioRepo.deleteAudio(docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the audio clip", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and so [refresh]
  /// puts the same results back instead of the unfiltered first page.
  String searchText = "";

  /// Debounced prefix search on the audio clip code, run server-side because the
  /// collection is paged and most of it is not in memory.
  Future<void> searchAudio({required String searchText}) async {
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
      await getFirstAudioList();
      return;
    }

    isSearching = true;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _audioRepo.searchAudio(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile.
      if (query != searchText.trim()) return;
      audioList = results;
    } catch (e) {
      audioList = [];
      // The old catch popped the current route before showing this —
      // a failed search took the whole page off the navigator.
      Helper.showSnackBarMessage(
          msg: "Error while searching audio clips", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
