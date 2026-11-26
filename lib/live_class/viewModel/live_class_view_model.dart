import 'dart:typed_data';

import 'package:bbarna/core/viewModel/async_list.dart';
import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
import 'package:bbarna/live_class/widgets/live_class_agenda.dart';
import 'package:bbarna/resources/constant.dart';
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

  /// Options for the form's Teacher dropdown, with their loading / error
  /// state.
  final AsyncList<LiveClassTeacher> teacherOptions =
      AsyncList<LiveClassTeacher>();

  /// Options for the form's Subject dropdown, with their loading / error
  /// state.
  final AsyncList<LiveClassSubject> subjectOptions =
      AsyncList<LiveClassSubject>();

  /// The options in [teacherOptions].
  List<LiveClassTeacher> get teachers => teacherOptions.items;

  /// The options in [subjectOptions].
  List<LiveClassSubject> get subjects => subjectOptions.items;

  /// True while the list is loading (drives the skeleton cards). Starts
  /// true so the first frame shows the loader rather than flashing
  /// "No upcoming classes".
  bool isLoading = true;

  /// Why the list could not be loaded, or null. While set and nothing is
  /// loaded, the screen shows an error with Retry instead of "No classes
  /// yet".
  String? loadError;

  /// The tab currently selected on the list screen.
  LiveClassStatus selectedStatus = LiveClassStatus.upcoming;

  /// Loads every class and re-applies the search.
  Future<void> getLiveClassList() async {
    // Skeleton only when nothing is on screen yet; otherwise keep the
    // current rows visible while refreshing.
    isLoading = copyLiveClassList.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      copyLiveClassList = await _liveClassRepo.getLiveClassList();
      _applySearch();
    } catch (e) {
      loadError = "Couldn't load classes";
      Helper.showSnackBarMessage(
          msg: "Error while fetching classes", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the Teacher dropdown options into [teacherOptions].
  Future<void> getTeachers() => teacherOptions.load(
        _liveClassRepo.getTeachers,
        errorMessage: "Couldn't load teachers",
        onChange: notifyListeners,
      );

  /// The loaded teacher a class points at: by [id] first, else by exact
  /// [name] (classes saved before teacher ids existed only have the name).
  /// Null when none matches, or the teachers haven't loaded.
  ///
  /// The student app spots the teacher by comparing their login number
  /// with the class's `teacherPhone`, so a save must take the phone from
  /// here: the copy held since the teacher was picked is blank on older
  /// classes and stale once the teacher's number changes.
  LiveClassTeacher? teacherFor({required String id, required String name}) {
    final String wantedId = id.trim();
    final String wantedName = name.trim();
    if (wantedId.isNotEmpty && wantedId != stringDefault) {
      final LiveClassTeacher? byId =
          teachers.where((t) => t.id == wantedId).firstOrNull;
      if (byId != null) return byId;
    }
    if (wantedName.isEmpty) return null;
    return teachers.where((t) => t.name == wantedName).firstOrNull;
  }

  /// Loads the Subject dropdown options into [subjectOptions].
  Future<void> getSubjects() => subjectOptions.load(
        _liveClassRepo.getSubjects,
        errorMessage: "Couldn't load subjects",
        onChange: notifyListeners,
      );

  /// Classes the student app cannot read yet. Empty is the healthy state.
  /// Counted over every class, not just the ones a search is showing.
  List<LiveClassModel> get classesNeedingAppSync =>
      copyLiveClassList.where((liveClass) => liveClass.needsAppSync).toList();

  /// True while [syncClassesForApp] is running.
  bool isSyncingForApp = false;

  /// Rewrites every class still in the old shape so the student app can read
  /// it.
  ///
  /// Each class is written separately (in parallel, not as one batch) so a
  /// failing class does not take the others with it, and the count reported
  /// is the count that actually landed. Returns how many were rewritten.
  Future<int> syncClassesForApp() async {
    final List<LiveClassModel> pending = classesNeedingAppSync;
    if (pending.isEmpty || isSyncingForApp) return 0;

    isSyncingForApp = true;
    notifyListeners();

    // Rewrite them all at once; each one succeeds or fails on its own, so
    // the count reported is the count that actually landed.
    final List<bool> results = await Future.wait([
      for (final LiveClassModel liveClass in pending)
        Future.sync(() => _liveClassRepo.migrateToAppSchema(liveClass)).then(
          (_) {
            liveClass.needsAppSync = false;
            return true;
          },
          // The banner stays up for whatever failed.
          onError: (Object e) => false,
        ),
    ]);
    final int migrated = results.where((ok) => ok).length;

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

  /// Every loaded class running at [now] (the search does not hide them),
  /// soonest-ending first. Feeds the live-now banner.
  List<LiveClassModel> runningClasses({DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    return copyLiveClassList
        .where((liveClass) => liveClass.statusAt(at) == LiveClassStatus.live)
        .toList()
      ..sort((a, b) => a.endDateTime.compareTo(b.endDateTime));
  }

  /// The stats strip's counts at [now], over every loaded class (the
  /// search does not change them).
  LiveClassStats statsAt(DateTime now) =>
      LiveClassStats.of(copyLiveClassList, now);

  /// How many classes are in [status] (shown on the tab).
  int countFor(LiveClassStatus status, {DateTime? now}) {
    // Counting needs no sort, unlike [classesFor].
    final DateTime at = now ?? DateTime.now();
    return liveClassList
        .where((liveClass) => liveClass.statusAt(at) == status)
        .length;
  }

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
      // Drop it locally instead of refetching every class.
      copyLiveClassList =
          copyLiveClassList.where((c) => c.docId != docId).toList();
      _applySearch();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting class", isSuccess: false);
      return false;
    }
  }

  /// Asks for [liveClass]'s chat to be deleted (a Cloud Function does the
  /// deleting). Marks the class "deleting" locally so the card updates at
  /// once; a refetch later picks up `chatDeletedAt`. Same contract as
  /// [addLiveClass].
  Future<bool> deleteChat(LiveClassModel liveClass) async {
    try {
      await _liveClassRepo.requestChatDelete(liveClass.docId);
      liveClass.chatDeleteRequestedAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting chat", isSuccess: false);
      return false;
    }
  }

  /// Largest notes PDF accepted. The student app's phone viewer downloads
  /// the whole file (with a timeout) before showing it, so a huge file
  /// would fail for students on a slow connection.
  static const int maxClassPdfBytes = 25 * 1024 * 1024;

  /// Classes whose PDF is uploading right now, by document id.
  final Set<String> _uploadingPdf = {};

  /// True while class [docId]'s PDF is uploading.
  bool isUploadingPdf(String docId) => _uploadingPdf.contains(docId);

  /// Uploads [bytes] as [liveClass]'s notes PDF, replacing any earlier one.
  /// On success the class's [LiveClassModel.pdfLink] / `pdfName` update in
  /// place so the card shows the PDF without a refetch. Same contract as
  /// [addLiveClass]; a file over [maxClassPdfBytes] is refused with a toast.
  Future<bool> uploadClassPdf(
      LiveClassModel liveClass, Uint8List bytes, String fileName) async {
    if (bytes.length > maxClassPdfBytes) {
      Helper.showSnackBarMessage(
          msg: "PDF is too large — the limit is "
              "${maxClassPdfBytes ~/ (1024 * 1024)} MB",
          isSuccess: false);
      return false;
    }
    if (!_uploadingPdf.add(liveClass.docId)) return false;
    notifyListeners();
    try {
      final String url =
          await _liveClassRepo.uploadClassPdf(liveClass.docId, bytes, fileName);
      liveClass.pdfLink = url;
      liveClass.pdfName = fileName.trim();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while uploading the PDF", isSuccess: false);
      return false;
    } finally {
      _uploadingPdf.remove(liveClass.docId);
      notifyListeners();
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
              liveClass.teacherName.toLowerCase().contains(query) ||
              liveClass.subjectNames
                  .any((name) => name.toLowerCase().contains(query)))
          .toList();
    }
  }
}
