import 'dart:typed_data';

import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/repo/subject_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SubjectViewModel with ChangeNotifier {
  // Constructor-injectable so the list, search and save logic can be
  // exercised without real Firebase.
  final SubjectRepo _subjectRepo;
  SubjectViewModel({SubjectRepo? subjectRepo})
      : _subjectRepo = subjectRepo ?? SubjectRepo();

  List<SubjectModel> subjectList = [];
  List<SubjectModel> copySubjectList = [];

  /// Drives the list's own skeletons. The module used to reach for the
  /// global [LoaderDialogs] overlay, which pushes a route — from
  /// `initState`, while the sidebar shell was still building.
  bool isLoading = true;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [SubjectList] is mounted
  /// from `Sidebar.screenList[selectedIndex]` *during* a build.
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

  Future<void> getSubjectList() async {
    isLoading = true;
    notifyListeners();
    try {
      subjectList = await _subjectRepo.getSubjectList();
      filterSubject();
      copySubjectList = List<SubjectModel>.from(subjectList);
      _applySearch();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching subjects", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its image as one operation, so a
  /// failed upload does not leave a subject the list can only draw as a
  /// broken thumbnail.
  Future<bool> createSubject(SubjectModel subjectModel, Uint8List image) async {
    String? docId;
    try {
      docId = await _subjectRepo.addSubject(subjectModel);
      await _subjectRepo.uploadSubjectImage(image, docId);
      return true;
    } catch (e) {
      if (docId != null) {
        try {
          await _subjectRepo.deleteSubject(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while adding the subject", isSuccess: false);
      return false;
    }
  }

  /// [image] is null when the admin did not pick a new one — the existing
  /// picture is then left exactly as it is.
  Future<bool> updateSubject(SubjectModel subjectModel, String subjectId,
      {Uint8List? image}) async {
    try {
      await _subjectRepo.updateSubject(subjectModel, subjectId);
      if (image != null) {
        await _subjectRepo.uploadSubjectImage(image, subjectId);
      }
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the subject", isSuccess: false);
      return false;
    }
  }

  Future<bool> deleteSubject(String subjectId) async {
    try {
      await _subjectRepo.deleteSubject(subjectId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the subject", isSuccess: false);
      return false;
    }
  }

  /// Flips the lock and updates the row in place — no full refetch, so the
  /// list does not blink and lose its scroll position over one boolean.
  Future<bool> toggleLocked(SubjectModel subjectModel) async {
    final bool next = !subjectModel.isLocked;
    final bool ok = await _setFlag(subjectModel.docId, "isLocked", next);
    if (ok) {
      subjectModel.isLocked = next;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> togglePopular(SubjectModel subjectModel) async {
    final bool next = !subjectModel.isPopular;
    final bool ok = await _setFlag(subjectModel.docId, "isPopular", next);
    if (ok) {
      subjectModel.isPopular = next;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> _setFlag(String docId, String field, bool value) async {
    try {
      await _subjectRepo.setSubjectFlag(docId, field, value);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the subject", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and is
  /// re-applied after every refetch instead of showing everything.
  String searchText = "";

  void searchSubject({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    final String query = searchText.toLowerCase().trim();
    if (query.isEmpty) {
      subjectList = List<SubjectModel>.from(copySubjectList);
    } else {
      subjectList = copySubjectList
          .where((subject) =>
              subject.code.toLowerCase().contains(query) ||
              subject.name.toLowerCase().contains(query) ||
              subject.courseName.toLowerCase().contains(query))
          .toList();
    }
  }

  /// Newest first.
  void filterSubject() {
    subjectList.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
  }
}
