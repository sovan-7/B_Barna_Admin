import 'dart:typed_data';

import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// State and actions for the Course module: the full course list with a
/// local search, create/update/delete with image upload, and the lock
/// toggle. Other forms read [allCourses] for their "Course" dropdown.
class CourseViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final CourseRepo _courseRepo;
  CourseViewModel({CourseRepo? courseRepo})
      : _courseRepo = courseRepo ?? CourseRepo();

  /// Courses currently shown (after the search filter), newest first.
  List<CourseModel> courseList = [];

  /// Every course, unfiltered; the search filters this.
  List<CourseModel> copyCourseList = [];

  /// True while the list is loading (drives the skeleton rows).
  bool isLoading = true;

  /// Why the list could not be loaded, or null. While set and nothing is
  /// loaded, the screen shows an error with Retry instead of "No courses
  /// yet".
  String? loadError;

  /// Loads every course, sorts newest first and re-applies the search.
  Future<void> getCourseList() async {
    // Skeleton only when nothing is on screen yet; otherwise keep the
    // current rows visible while refreshing.
    isLoading = copyCourseList.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      courseList = await _courseRepo.getCourseList();
      filterCourse();
      copyCourseList = List<CourseModel>.from(courseList);
      _applySearch();
    } catch (e) {
      loadError = "Couldn't load courses";
      Helper.showSnackBarMessage(
          msg: "Error while fetching courses", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its image as one operation. If the
  /// upload fails the new document is deleted again (so the list never
  /// shows a broken thumbnail) and `false` is returned.
  Future<bool> createCourse(CourseModel courseModel, Uint8List image) async {
    String? docId;
    try {
      docId = await _courseRepo.addCourse(courseModel);
      await _courseRepo.uploadCourseImage(image, docId);
      return true;
    } catch (e) {
      if (docId != null) {
        try {
          await _courseRepo.deleteCourse(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while adding the course", isSuccess: false);
      return false;
    }
  }

  /// [image] is null when the admin did not pick a new one — the existing
  /// picture is then left exactly as it is.
  Future<bool> updateCourse(CourseModel courseModel, String courseId,
      {Uint8List? image}) async {
    try {
      await _courseRepo.updateCourse(courseModel, courseId);
      if (image != null) {
        await _courseRepo.uploadCourseImage(image, courseId);
      }
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the course", isSuccess: false);
      return false;
    }
  }

  /// Deletes the course. Returns `false` (and shows a toast) on failure.
  Future<bool> deleteCourse(String courseId) async {
    try {
      await _courseRepo.deleteCourse(courseId);
      // Drop it from both lists instead of refetching every course.
      courseList = courseList.where((c) => c.docId != courseId).toList();
      copyCourseList =
          copyCourseList.where((c) => c.docId != courseId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the course", isSuccess: false);
      return false;
    }
  }

  /// Flips the lock and updates the row in place — no full refetch, so the
  /// list does not blink and lose its scroll position over one boolean.
  Future<bool> toggleLocked(CourseModel courseModel) async {
    final bool next = !courseModel.isLocked;
    try {
      await _courseRepo.setCourseLocked(courseModel.docId, next);
      courseModel.isLocked = next;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the course", isSuccess: false);
      return false;
    }
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and is
  /// re-applied after every refetch instead of showing everything.
  String searchText = "";

  /// Every course, whatever the Courses search is showing. The course
  /// pickers on the Subject, Topic and Unit forms read this — reading
  /// [courseList] would offer them only the courses a search matched.
  List<CourseModel> get allCourses => copyCourseList;

  /// Filters [courseList] by code or name (case-insensitive).
  void searchCourse({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  /// Rebuilds [courseList] from [copyCourseList] using [searchText].
  void _applySearch() {
    final String query = searchText.toLowerCase().trim();
    if (query.isEmpty) {
      courseList = List<CourseModel>.from(copyCourseList);
    } else {
      courseList = copyCourseList
          .where((course) =>
              course.code.toLowerCase().contains(query) ||
              course.name.toLowerCase().contains(query))
          .toList();
    }
  }

  /// Sorts [courseList] newest first.
  void filterCourse() {
    courseList.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
  }
}
