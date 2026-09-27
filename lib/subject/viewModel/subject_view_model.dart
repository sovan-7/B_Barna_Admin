import 'dart:typed_data';

import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/repo/subject_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// State and actions for the Subject module: the full subject list with a
/// local search, create/update/delete with image upload, and the lock /
/// popular toggles.
class SubjectViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final SubjectRepo _subjectRepo;
  SubjectViewModel({SubjectRepo? subjectRepo})
      : _subjectRepo = subjectRepo ?? SubjectRepo();

  /// Subjects currently shown (after the search filter), newest first.
  List<SubjectModel> subjectList = [];

  /// Every subject, unfiltered; the search filters this.
  List<SubjectModel> copySubjectList = [];

  /// True while the list is loading (drives the skeleton rows).
  bool isLoading = true;

  /// Loads every subject, sorts newest first and re-applies the search.
  Future<void> getSubjectList() async {
    // Skeleton only when nothing is on screen yet; otherwise keep the
    // current rows visible while refreshing.
    isLoading = copySubjectList.isEmpty;
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

  /// Deletes the subject. Returns `false` (and shows a toast) on failure.
  Future<bool> deleteSubject(String subjectId) async {
    try {
      await _subjectRepo.deleteSubject(subjectId);
      // Drop it from both lists instead of refetching every subject.
      subjectList = subjectList.where((s) => s.docId != subjectId).toList();
      copySubjectList =
          copySubjectList.where((s) => s.docId != subjectId).toList();
      notifyListeners();
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

  /// Flips the "popular" heart the same way as [toggleLocked].
  Future<bool> togglePopular(SubjectModel subjectModel) async {
    final bool next = !subjectModel.isPopular;
    final bool ok = await _setFlag(subjectModel.docId, "isPopular", next);
    if (ok) {
      subjectModel.isPopular = next;
      notifyListeners();
    }
    return ok;
  }

  /// Writes one boolean [field]; toasts and returns `false` on failure.
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

  /// Filters [subjectList] by code, name or course name
  /// (case-insensitive).
  void searchSubject({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  /// Rebuilds [subjectList] from [copySubjectList] using [searchText].
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

  /// Sorts [subjectList] newest first.
  void filterSubject() {
    subjectList.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
  }
}
