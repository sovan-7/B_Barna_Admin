import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// State and actions for the Live Class module: the class list split into
/// Upcoming / Live / Past tabs with a local search, add / update / delete,
/// the teacher and subject dropdown data, and the one-off "sync classes
/// for the app" migration.
class LiveClassViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final LiveClassRepo _liveClassRepo;
  LiveClassViewModel({LiveClassRepo? liveClassRepo})
      : _liveClassRepo = liveClassRepo ?? LiveClassRepo();

  /// Classes currently shown (after the search filter).
  List<LiveClassModel> liveClassList = [];

  /// Every class, unfiltered; the search filters this.
  List<LiveClassModel> copyLiveClassList = [];

  /// Options for the form's Teacher dropdown.
  List<LiveClassTeacher> teachers = [];

  /// Options for the form's Subject dropdown.
  List<LiveClassSubject> subjects = [];

  /// True while the list is loading (drives the skeleton cards). Starts
  /// true so the first frame shows the loader rather than flashing
  /// "No upcoming classes".
  bool isLoading = true;

  /// The tab currently selected on the list screen.
  LiveClassStatus selectedStatus = LiveClassStatus.upcoming;

  /// Loads every class and re-applies the search.
  Future<void> getLiveClassList() async {
    isLoading = true;
    notifyListeners();
    try {
      copyLiveClassList = await _liveClassRepo.getLiveClassList();
      _applySearch();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching classes", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the Teacher dropdown options (empty on failure).
  Future<void> getTeachers() async {
    try {
      teachers = await _liveClassRepo.getTeachers();
    } catch (e) {
      teachers = [];
    }
    notifyListeners();
  }

  /// Loads the Subject dropdown options (empty on failure).
  Future<void> getSubjects() async {
    try {
      subjects = await _liveClassRepo.getSubjects();
    } catch (e) {
      subjects = [];
    }
    notifyListeners();
  }

  /// Classes the student app cannot read yet. Empty is the healthy state.
  /// Counted over every class, not just the ones a search is showing.
  List<LiveClassModel> get classesNeedingAppSync =>
      copyLiveClassList.where((liveClass) => liveClass.needsAppSync).toList();

  /// True while [syncClassesForApp] is running.
  bool isSyncingForApp = false;

  /// Rewrites every class still in the old shape so the student app can read
  /// it.
  ///
  /// One at a time rather than a batch: a class that fails should not take
  /// the others with it, and the count reported afterwards is then the count
  /// that actually landed. Returns how many were rewritten.
  Future<int> syncClassesForApp() async {
    final List<LiveClassModel> pending = classesNeedingAppSync;
    if (pending.isEmpty || isSyncingForApp) return 0;

    isSyncingForApp = true;
    notifyListeners();

    int migrated = 0;
    for (final LiveClassModel liveClass in pending) {
      try {
        await _liveClassRepo.migrateToAppSchema(liveClass);
        liveClass.needsAppSync = false;
        migrated++;
      } catch (e) {
        // Keep going; the banner stays up for whatever is left.
      }
    }

    isSyncingForApp = false;
    notifyListeners();

    if (migrated < pending.length) {
      Helper.showSnackBarMessage(
          msg: "Updated $migrated of ${pending.length} classes — try again "
              "for the rest",
          isSuccess: false);
    }
    return migrated;
  }

  /// Switches the list to the [status] tab.
  void selectStatus(LiveClassStatus status) {
    selectedStatus = status;
    notifyListeners();
  }

  /// Classes in [status], soonest-first for Upcoming/Live and
  /// most-recent-first for Past — the order an admin scans each tab in.
  List<LiveClassModel> classesFor(LiveClassStatus status, {DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    final List<LiveClassModel> filtered = liveClassList
        .where((liveClass) => liveClass.statusAt(at) == status)
        .toList();
    filtered.sort((a, b) => status == LiveClassStatus.past
        ? b.startDateTime.compareTo(a.startDateTime)
        : a.startDateTime.compareTo(b.startDateTime));
    return filtered;
  }

  /// How many classes are in [status] (shown on the tab).
  int countFor(LiveClassStatus status, {DateTime? now}) =>
      classesFor(status, now: now).length;

  /// Adds a class. Returns true on success; on failure shows a toast and
  /// returns false, leaving the caller on the form.
  Future<bool> addLiveClass(LiveClassModel liveClassModel) async {
    try {
      await _liveClassRepo.addLiveClass(liveClassModel);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while adding class", isSuccess: false);
      return false;
    }
  }

  /// Saves an edited class (same contract as [addLiveClass]).
  Future<bool> updateLiveClass(LiveClassModel liveClassModel) async {
    try {
      await _liveClassRepo.updateLiveClass(liveClassModel);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating class", isSuccess: false);
      return false;
    }
  }

  /// Deletes a class (same contract as [addLiveClass]).
  Future<bool> deleteLiveClass(String docId) async {
    try {
      await _liveClassRepo.deleteLiveClass(docId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting class", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and is
  /// re-applied after every refetch instead of showing everything.
  String searchText = "";

  /// Filters the loaded classes by title or teacher name
  /// (case-insensitive).
  void searchLiveClass({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  /// Rebuilds [liveClassList] from [copyLiveClassList] using [searchText].
  void _applySearch() {
    final String query = searchText.toLowerCase().trim();
    if (query.isEmpty) {
      liveClassList = copyLiveClassList;
    } else {
      liveClassList = copyLiveClassList
          .where((liveClass) =>
              liveClass.title.toLowerCase().contains(query) ||
              liveClass.teacherName.toLowerCase().contains(query))
          .toList();
    }
  }
}
