import 'dart:convert';
import 'dart:typed_data';

import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class TeacherViewModel with ChangeNotifier {
  // Constructor-injectable, unlike every other ViewModel in this codebase
  // (which instantiate their repo directly) — the minimal seam needed to
  // unit-test the orchestration below (hash-before-write, upload-then-add
  // ordering) without touching real Firebase.
  final TeacherRepo _teacherRepo;
  TeacherViewModel({TeacherRepo? teacherRepo})
      : _teacherRepo = teacherRepo ?? TeacherRepo();

  List<TeacherModel> teacherList = [];
  List<TeacherModel> copyTeacherList = [];

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

  /// Safe to call from any point in the frame — [TeacherList] is mounted
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

  /// Returns true on success. On failure, shows a snackbar explaining why
  /// and returns false — the caller (AddTeacher screen) decides what to do
  /// next (e.g. stay on the form).
  Future<bool> addTeacher({
    required String name,
    required String username,
    required String password,
    required String phoneNumber,
    required Uint8List image,
    required List<String> moduleAccess,
    required String role,
  }) async {
    final String normalizedUsername = normalizeUsername(username);
    final String storageKey = _teacherRepo.generateStorageKey();

    late final String imageUrl;
    try {
      imageUrl = await _teacherRepo.uploadTeacherImage(image, storageKey);
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while uploading photo", isSuccess: false);
      return false;
    }

    final String hashedPassword = sha256.convert(utf8.encode(password)).toString();

    final TeacherModel model = TeacherModel(
      docId: normalizedUsername,
      name: name,
      imageUrl: imageUrl,
      username: normalizedUsername,
      password: hashedPassword,
      phoneNumber: phoneNumber,
      timeStamp: DateTime.now().millisecondsSinceEpoch,
      moduleAccess: moduleAccess,
      role: role,
    );

    try {
      await _teacherRepo.addTeacher(model);
    } on UsernameTakenException {
      Helper.showSnackBarMessage(
          msg: "Username already taken", isSuccess: false);
      return false;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while creating teacher", isSuccess: false);
      return false;
    }

    return true;
  }

  /// Returns true on success. On failure, shows a snackbar and returns false
  /// — same contract as [addTeacher]. Username/docId never change here (see
  /// [TeacherRepo.updateTeacher]); [newPassword] left null or empty keeps
  /// [original]'s existing hash instead of re-hashing an empty string, and
  /// [newImage] left null keeps [original]'s existing photo instead of
  /// re-uploading.
  Future<bool> updateTeacher({
    required TeacherModel original,
    required String name,
    String? newPassword,
    required String phoneNumber,
    required List<String> moduleAccess,
    required String role,
    Uint8List? newImage,
  }) async {
    String imageUrl = original.imageUrl;
    if (newImage != null) {
      final String storageKey = _teacherRepo.generateStorageKey();
      try {
        imageUrl = await _teacherRepo.uploadTeacherImage(newImage, storageKey);
      } catch (e) {
        Helper.showSnackBarMessage(
            msg: "Error while uploading photo", isSuccess: false);
        return false;
      }
    }

    final String password = (newPassword == null || newPassword.isEmpty)
        ? original.password
        : sha256.convert(utf8.encode(newPassword)).toString();

    final TeacherModel updated = TeacherModel(
      docId: original.docId,
      name: name,
      imageUrl: imageUrl,
      username: original.username,
      password: password,
      phoneNumber: phoneNumber,
      timeStamp: original.timeStamp,
      moduleAccess: moduleAccess,
      role: role,
    );

    try {
      await _teacherRepo.updateTeacher(updated);
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating teacher", isSuccess: false);
      return false;
    }

    return true;
  }

  Future<void> getTeacherList() async {
    isLoading = true;
    notifyListeners();
    try {
      teacherList = await _teacherRepo.getTeacherList();
      copyTeacherList = List<TeacherModel>.from(teacherList);
      _applySearch();
    } catch (e) {
      // The old version had no catch at all, so a failed fetch threw out of
      // an unawaited call and left the loader dialog up for good.
      Helper.showSnackBarMessage(
          msg: "Error while fetching teachers", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true on success, and drops the teacher from both lists.
  ///
  /// It used to announce "Teacher deleted successfully" from a
  /// `whenComplete`, which runs whether the delete succeeded or threw. It
  /// also left `copyTeacherList` holding the deleted teacher, so clearing
  /// the search brought them back.
  Future<bool> deleteTeacher(String username) async {
    try {
      await _teacherRepo.deleteTeacher(username);
      teacherList = teacherList.where((t) => t.username != username).toList();
      copyTeacherList =
          copyTeacherList.where((t) => t.username != username).toList();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the teacher", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and is
  /// re-applied after every refetch instead of showing everything.
  String searchText = "";

  void searchTeacher({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    final String query = searchText.toLowerCase().trim();
    if (query.isEmpty) {
      teacherList = List<TeacherModel>.from(copyTeacherList);
    } else {
      teacherList = copyTeacherList
          .where((teacher) =>
              teacher.name.toLowerCase().contains(query) ||
              teacher.username.toLowerCase().contains(query))
          .toList();
    }
  }
}
