import 'dart:async';
import 'dart:typed_data';

import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/repo/unit_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class UnitViewModel with ChangeNotifier {
  // Constructor-injectable so the paging, search and save logic can be
  // exercised without real Firebase.
  final UnitRepo _unitRepo;
  UnitViewModel({UnitRepo? unitRepo}) : _unitRepo = unitRepo ?? UnitRepo();

  List<UnitModel> unitList = [];
  List<SubjectModel> subjectListByCourseId = [];

  /// How many units the collection holds in total, so the list can say
  /// "showing 50 of 320" rather than just "50".
  int unitLength = 0;
  final int limit = 50;

  /// True while the first page is in flight — drives the skeletons. The
  /// module used to reach for the global [LoaderDialogs] overlay, which
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

  bool get hasMore => !isSearching && unitList.length < unitLength;

  @override
  void dispose() {
    _debounce?.cancel();
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [UnitList] is mounted from
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
  Future<void> getFirstUnitList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      unitList = await _unitRepo.getFirstUnitList(limit);
      unitLength = await _unitRepo.getUnitListLength();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching units", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page. This is what the old "Next" button did too —
  /// it grew one list rather than turning a page, which is why its
  /// "Previous" counterpart could only ever chop rows back off the end.
  Future<void> getNextUnitList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      unitList.addAll(await _unitRepo.getNextUnitList(limit));
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more units", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> getSubjectListByCourseCode(String courseCode) async {
    try {
      subjectListByCourseId =
          await _unitRepo.getSubjectListByCourseCode(courseCode);
    } catch (e) {
      subjectListByCourseId = [];
    }
    notifyListeners();
  }

  /// Creates the document and uploads its image as one operation, so a
  /// failed upload does not leave a unit the list can only draw as a
  /// broken thumbnail.
  Future<bool> createUnit(UnitModel unitModel, Uint8List image) async {
    String? docId;
    try {
      docId = await _unitRepo.addUnit(unitModel);
      await _unitRepo.uploadUnitImage(image, docId);
      return true;
    } catch (e) {
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

  /// [image] is null when the admin did not pick a new one — the existing
  /// picture is then left exactly as it is.
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

  Future<bool> deleteUnit(String unitId) async {
    try {
      await _unitRepo.deleteUnit(unitId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the unit", isSuccess: false);
      return false;
    }
  }

  /// Flips the lock and updates the row in place — no full reload, so the
  /// list does not lose the pages it has already fetched.
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

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and so [refresh]
  /// puts the same results back instead of the unfiltered first page.
  String searchText = "";

  /// Debounced prefix search on the unit code, run server-side because the
  /// collection is paged and most of it is not in memory.
  Future<void> searchUnit({required String searchText}) async {
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
      await getFirstUnitList();
      return;
    }

    isSearching = true;
    isLoading = true;
    notifyListeners();
    try {
      final results = await _unitRepo.searchUnit(query.toUpperCase());
      // A newer search (or a refresh) has taken over meanwhile.
      if (query != searchText.trim()) return;
      unitList = results;
    } catch (e) {
      unitList = [];
      // The old catch popped the current route before showing this —
      // a failed search took the whole page off the navigator.
      Helper.showSnackBarMessage(
          msg: "Error while searching units", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
