import 'dart:typed_data';

import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/repo/unit_repo.dart';
import 'package:bbarna/utils/helper.dart';

/// State and actions for the Unit module: the paged/searchable unit list
/// (inherited from [PagedListViewModel]), create/update/delete with image
/// upload, the lock toggle, and the subject list for the form's
/// "Subject" dropdown.
class UnitViewModel extends PagedListViewModel<UnitModel> {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final UnitRepo _unitRepo;

  UnitViewModel({UnitRepo? unitRepo}) : _unitRepo = unitRepo ?? UnitRepo();

  /// Subjects of the course chosen on the Add/Edit Unit form.
  List<SubjectModel> subjectListByCourseId = [];

  // ---- Paging hooks (see PagedListViewModel) -----------------------------

  @override
  String get itemsLabel => "units";

  @override
  Future<List<UnitModel>> fetchFirstPage(int limit) =>
      _unitRepo.getFirstUnitList(limit);

  @override
  Future<List<UnitModel>> fetchNextPage(int limit) =>
      _unitRepo.getNextUnitList(limit);

  @override
  Future<int> fetchTotalCount() => _unitRepo.getUnitListLength();

  @override
  Future<List<UnitModel>> fetchSearchResults(String query) =>
      _unitRepo.searchUnit(query);

  // ---- Module-specific names used by screens and tests -------------------

  /// Units currently on screen (a page, or search results).
  List<UnitModel> get unitList => items;

  /// Total units in the collection.
  int get unitLength => totalCount;

  /// Loads the first page of units.
  Future<void> getFirstUnitList() => loadFirstPage();

  /// Appends the next page of units.
  Future<void> getNextUnitList() => loadNextPage();

  /// Debounced prefix search on the unit code.
  Future<void> searchUnit({required String searchText}) => search(searchText);

  // ---- Form dropdown data ------------------------------------------------

  /// Loads the subjects that belong to [courseCode] into
  /// [subjectListByCourseId]. On failure the list is simply emptied.
  Future<void> getSubjectListByCourseCode(String courseCode) async {
    try {
      subjectListByCourseId =
          await _unitRepo.getSubjectListByCourseCode(courseCode);
    } catch (e) {
      subjectListByCourseId = [];
    }
    notifyListeners();
  }

  // ---- Create / update / delete ------------------------------------------

  /// Creates the document and uploads its image as one operation. If the
  /// upload fails the new document is deleted again, so the list never
  /// shows a unit with a broken thumbnail.
  Future<bool> createUnit(UnitModel unitModel, Uint8List image) async {
    String? docId;
    try {
      docId = await _unitRepo.addUnit(unitModel);
      await _unitRepo.uploadUnitImage(image, docId);
      return true;
    } catch (e) {
      // Roll back the half-created row; ignore a failure to do so.
      if (docId != null) {
        try {
          await _unitRepo.deleteUnit(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while adding the unit", isSuccess: false);
      return false;
    }
  }

  /// Saves the edited fields. [image] is null when the admin did not pick
  /// a new picture — the existing one is then left exactly as it is.
  Future<bool> updateUnit(UnitModel unitModel, String unitId,
      {Uint8List? image}) async {
    try {
      await _unitRepo.updateUnit(unitModel, unitId);
      if (image != null) {
        await _unitRepo.uploadUnitImage(image, unitId);
      }
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the unit", isSuccess: false);
      return false;
    }
  }

  /// Deletes the unit document. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> deleteUnit(String unitId) async {
    try {
      await _unitRepo.deleteUnit(unitId);
      removeLocally((item) => item.id == unitId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the unit", isSuccess: false);
      return false;
    }
  }

  /// Flips `lock_status` in Firestore and on the in-memory row — no full
  /// reload, so the list keeps the pages it has already fetched.
  Future<bool> toggleLocked(UnitModel unitModel) async {
    final bool next = !unitModel.lockStatus;
    try {
      await _unitRepo.setUnitFlag(unitModel.id, "lock_status", next);
      unitModel.lockStatus = next;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the unit", isSuccess: false);
      return false;
    }
  }
}
