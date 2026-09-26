import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class LiveClassViewModel with ChangeNotifier {
  // Constructor-injectable like TeacherViewModel (and unlike the older
  // ViewModels, which new their repo inline) so the list/status logic below
  // can be exercised without real Firebase.
  final LiveClassRepo _liveClassRepo;
  LiveClassViewModel({LiveClassRepo? liveClassRepo})
      : _liveClassRepo = liveClassRepo ?? LiveClassRepo();

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame.
  ///
  /// [LiveClassList] is mounted from `Sidebar.screenList[selectedIndex]`
  /// *during* a build, and the refresh entry points below (a route's
  /// `whenComplete`, the search field, tab selection) can each land while
  /// the framework is mid-build — notifying then throws "setState() or
  /// markNeedsBuild() called during build" and the list is left showing a
  /// stale frame. Deferring to the end of the current frame keeps every
  /// caller free of scheduling concerns; outside a build it notifies
  /// synchronously as usual.
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

  List<LiveClassModel> liveClassList = [];
  List<LiveClassModel> copyLiveClassList = [];
  List<LiveClassTeacher> teachers = [];
  List<LiveClassSubject> subjects = [];

  /// Drives the inline spinner/empty state on [LiveClassList]. This module
  /// deliberately uses an in-place loading flag rather than the global
  /// LoaderDialogs overlay: the list is embedded in the sidebar shell, so
  /// there is no pushed route for the dialog's `Navigator.pop` to unwind.
  ///
  /// Starts true so the first frame — rendered before the deferred
  /// [getLiveClassList] in LiveClassList.initState runs — shows the loader
  /// rather than flashing "No upcoming classes".
  bool isLoading = true;

  /// The tab currently selected on the list screen.
  LiveClassStatus selectedStatus = LiveClassStatus.upcoming;

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

  Future<void> getTeachers() async {
    try {
      teachers = await _liveClassRepo.getTeachers();
    } catch (e) {
      teachers = [];
    }
    notifyListeners();
  }

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

  int countFor(LiveClassStatus status, {DateTime? now}) =>
      classesFor(status, now: now).length;

  /// Returns true on success; on failure shows a snackbar and returns false,
  /// leaving the caller on the form (same contract as TeacherViewModel).
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

  /// Local filter over the already-fetched list (matches title or teacher),
  /// mirroring TeacherViewModel.searchTeacher.
  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and is
  /// re-applied after every refetch instead of showing everything.
  String searchText = "";

  void searchLiveClass({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

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
