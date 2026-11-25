import 'dart:typed_data';

import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/repo/pdf_repo.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the PDF module: the paged/searchable PDF list
/// (inherited from [PagedListViewModel]) plus create, update, delete and
/// the lock / downloadable toggles.
class PdfViewModel extends PagedListViewModel<PdfModel> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final PdfRepo _pdfRepo;

  PdfViewModel({PdfRepo? pdfRepo}) : _pdfRepo = pdfRepo ?? PdfRepo();

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "PDFs";

  @override
  Future<List<PdfModel>> fetchFirstPage(int limit) =>
      _pdfRepo.getFirstPdfList(limit);

  @override
  Future<List<PdfModel>> fetchNextPage(int limit) =>
      _pdfRepo.getNextPdfList(limit);

  @override
  Future<int> fetchTotalCount() => _pdfRepo.getPdfListLength();

  @override
  Future<List<PdfModel>> fetchSearchResults(String query) =>
      _pdfRepo.searchPdf(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// PDFs currently on screen (a page, or search results).
  List<PdfModel> get pdfList => items;

  /// Total PDFs in the collection.
  int get pdfListLength => totalCount;

  /// Loads the first page of PDFs.
  Future<void> getFirstPdfList() => loadFirstPage();

  /// Appends the next page of PDFs.
  Future<void> getNextPdfList() => loadNextPage();

  /// Debounced prefix search on the PDF code.
  Future<void> searchPdf({required String searchText}) => search(searchText);

  // ---- Create / update / delete ------------------------------------------

  /// Creates the document and uploads its file as one operation.
  ///
  /// A PDF row exists only to point at a file, so if the upload fails the
  /// new (empty) document is deleted again and `false` is returned.
  Future<bool> createPdf(PdfModel pdfModel, Uint8List file) async {
    String? docId;
    try {
      docId = await _pdfRepo.addPdf(pdfModel);
      await _pdfRepo.uploadPdf(file, docId);
      return true;
    } catch (e) {
      // Roll back the half-created row; ignore a failure to do so.
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

  /// Saves the edited fields. [file] is null when the admin did not pick a
  /// new file — the existing one is then left exactly as it is.
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

  /// Deletes the PDF document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> deletePdf(String docId) async {
    try {
      await _pdfRepo.deletePdf(docId);
      removeLocally((item) => item.docId == docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the PDF", isSuccess: false);
      return false;
    }
  }

  // ---- Flags ---------------------------------------------------------------

  /// Flips `is_locked` in Firestore and, on success, on the in-memory row
  /// so the padlock updates without a refetch.
  Future<bool> toggleLocked(PdfModel pdfModel) async {
    final bool next = !pdfModel.isLocked;
    final bool ok = await _setFlag(pdfModel.docId, "is_locked", next);
    if (ok) {
      pdfModel.isLocked = next;
      notifyListeners();
    }
    return ok;
  }

  /// Flips `is_downloadable` the same way as [toggleLocked].
  Future<bool> toggleDownloadable(PdfModel pdfModel) async {
    final bool next = !pdfModel.isDownloadable;
    final bool ok = await _setFlag(pdfModel.docId, "is_downloadable", next);
    if (ok) {
      pdfModel.isDownloadable = next;
      notifyListeners();
    }
    return ok;
  }

  /// `docId/field` of the flag writes still in flight, so a card can show
  /// the toggle as busy and a second tap is ignored.
  final Set<String> _flagsInFlight = <String>{};

  /// True while [field] on [docId] is being saved.
  bool isFlagBusy(String docId, String field) =>
      _flagsInFlight.contains("$docId/$field");

  /// Writes one boolean [field] on the document; toasts and returns
  /// `false` on failure.
  Future<bool> _setFlag(String docId, String field, bool value) async {
    final String key = "$docId/$field";
    if (!_flagsInFlight.add(key)) return false;
    notifyListeners();
    try {
      await _pdfRepo.setPdfFlag(docId, field, value);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the PDF", isSuccess: false);
      return false;
    } finally {
      _flagsInFlight.remove(key);
      notifyListeners();
    }
  }
}
