import 'dart:convert';
import 'dart:typed_data';

import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/repo/teacher_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// State and actions for the Teacher module: the full teacher list with a
/// local search, and add / update / delete. Passwords are SHA-256 hashed
/// here before they reach the repo.
class TeacherViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final TeacherRepo _teacherRepo;
  TeacherViewModel({TeacherRepo? teacherRepo})
      : _teacherRepo = teacherRepo ?? TeacherRepo();

  /// Teachers currently shown (after the search filter).
  List<TeacherModel> teacherList = [];

  /// Every teacher, unfiltered; the search filters this.
  List<TeacherModel> copyTeacherList = [];

  /// True while the list is loading (drives the skeleton rows).
  bool isLoading = true;

  /// Why the list could not be loaded, or null. While set and nothing is
  /// loaded, the screen shows an error with Retry instead of "No teachers
  /// yet".
  String? loadError;

  /// Creates a teacher: uploads the photo, hashes the password, then adds
  /// the document (whose id is the normalised username).
  ///
  /// Returns true on success. On failure shows a toast explaining why and
  /// returns false, so the form can stay open.
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

    final String hashedPassword =
        sha256.convert(utf8.encode(password)).toString();

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

  /// Saves an edited teacher. Returns true on success; on failure shows a
  /// toast and returns false — same contract as [addTeacher]. Username/docId never change here (see
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

  /// Loads every teacher and re-applies the search.
  Future<void> getTeacherList() async {
    // Skeleton only when nothing is on screen yet; otherwise keep the
    // current rows visible while refreshing.
    isLoading = copyTeacherList.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      teacherList = await _teacherRepo.getTeacherList();
      copyTeacherList = List<TeacherModel>.from(teacherList);
      _applySearch();
    } catch (e) {
      loadError = "Couldn't load teachers";
      Helper.showSnackBarMessage(
          msg: "Error while fetching teachers", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes the teacher and, on success, drops them from both the shown
  /// and the unfiltered list (so clearing the search does not bring them
  /// back). Returns false (and shows a toast) on failure.
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

  /// Filters [teacherList] by name or username (case-insensitive).
  void searchTeacher({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  /// Rebuilds [teacherList] from [copyTeacherList] using [searchText].
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
