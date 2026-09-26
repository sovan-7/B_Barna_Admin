import 'dart:async';
import 'dart:typed_data';

import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/repo/pdf_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PdfViewModel with ChangeNotifier {
  // Constructor-injectable so the paging, search and save logic can be
  // exercised without real Firebase.
  final PdfRepo _pdfRepo;
  PdfViewModel({PdfRepo? pdfRepo}) : _pdfRepo = pdfRepo ?? PdfRepo();

  List<PdfModel> pdfList = [];

  /// How many the collection holds in total, so the list can say
  /// "showing 50 of 320" rather than just "50".
  int pdfListLength = 0;
  final int limit = 50;

  bool isLoading = true;
  bool isLoadingMore = false;

  /// Set while a search is showing, because searching queries the server
  /// separately and paging does not apply to the result.
  bool isSearching = false;

  Timer? _debounce;
  bool _disposed = false;

  bool get hasMore => !isSearching && pdfList.length < pdfListLength;

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [PDFList] is mounted from
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

  Future<void> getFirstPdfList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      pdfList = await _pdfRepo.getFirstPdfList(limit);
      pdfListLength = await _pdfRepo.getPdfListLength();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching PDFs", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getNextPdfList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      pdfList.addAll(await _pdfRepo.getNextPdfList(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more PDFs", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its file as one operation.
  ///
  /// A PDF row exists only to point at a file, so a document whose upload
  /// failed is not a partial PDF — it is a broken row. The empty document
  /// is removed again and the caller is told the truth.
  Future<bool> createPdf(PdfModel pdfModel, Uint8List file) async {
    String? docId;
    try {
      docId = await _pdfRepo.addPdf(pdfModel);
      await _pdfRepo.uploadPdf(file, docId);
      return true;
    } catch (e) {
      if (docId != null) {
        try {
          await _pdfRepo.deletePdf(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while adding the PDF", isSuccess: false);
      return false;
    }
  }

  /// [file] is null when the admin did not pick a new one — the existing
  /// file is then left exactly as it is.
  Future<bool> updatePdf(PdfModel pdfModel, String docId,
      {Uint8List? file}) async {
    try {
      await _pdfRepo.updatePdf(pdfModel, docId);
      if (file != null) {
        await _pdfRepo.uploadPdf(file, docId);
      }
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the PDF", isSuccess: false);
      return false;
    }
  }

  Future<bool> deletePdf(String docId) async {
    try {
      await _pdfRepo.deletePdf(docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the PDF", isSuccess: false);
      return false;
    }
  }

  /// Flips the lock and updates the row in place. The old toggle wrote to
  /// Firestore and did nothing else at all — not even a refetch — so the
  /// padlock stayed as it was until you left the screen and came back.
  Future<bool> toggleLocked(PdfModel pdfModel) async {
    final bool next = !pdfModel.isLocked;
    final bool ok = await _setFlag(pdfModel.docId, "is_locked", next);
    if (ok) {
      pdfModel.isLocked = next;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> toggleDownloadable(PdfModel pdfModel) async {
    final bool next = !pdfModel.isDownloadable;
    final bool ok = await _setFlag(pdfModel.docId, "is_downloadable", next);
    if (ok) {
      pdfModel.isDownloadable = next;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _setFlag(String docId, String field, bool value) async {
    try {
      await _pdfRepo.setPdfFlag(docId, field, value);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the PDF", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and so [refresh]
  /// puts the same results back instead of the unfiltered first page.
  String searchText = "";

  /// Debounced prefix search on the PDF code, run server-side because the
  /// collection is paged and most of it is not in memory.
  Future<void> searchPdf({required String searchText}) async {
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
      await getFirstPdfList();
      return;
    }

    isSearching = true;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _pdfRepo.searchPdf(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile.
      if (query != searchText.trim()) return;
      pdfList = results;
    } catch (e) {
      pdfList = [];
      // The old catch popped the current route before showing this —
      // a failed search took the whole page off the navigator.
      Helper.showSnackBarMessage(
          msg: "Error while searching PDFs", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
