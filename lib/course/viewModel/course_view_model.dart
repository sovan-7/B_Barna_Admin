import 'dart:typed_data';

import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/repo/course_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class CourseViewModel with ChangeNotifier {
  // Constructor-injectable so the list, search and save logic can be
  // exercised without real Firebase.
  final CourseRepo _courseRepo;
  CourseViewModel({CourseRepo? courseRepo})
      : _courseRepo = courseRepo ?? CourseRepo();

  List<CourseModel> courseList = [];
  List<CourseModel> copyCourseList = [];

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

  /// Safe to call from any point in the frame — [CourseList] is mounted
  /// from `Sidebar.screenList[selectedIndex]` *during* a build, so a
  /// synchronous notify from there would throw "setState() called during
  /// build".
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

  Future<void> getCourseList() async {
    isLoading = true;
    notifyListeners();
    try {
      courseList = await _courseRepo.getCourseList();
      filterCourse();
      copyCourseList = List<CourseModel>.from(courseList);
      _applySearch();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching courses", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its image as one operation.
  ///
  /// A course whose image upload failed is a row the list can only render
  /// as a broken thumbnail, so the empty document is removed again and the
  /// caller is told the truth instead of "added successfully".
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

  Future<bool> deleteCourse(String courseId) async {
    try {
      await _courseRepo.deleteCourse(courseId);
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

  void searchCourse({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

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

  /// Newest first.
  void filterCourse() {
    courseList.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
  }
}
