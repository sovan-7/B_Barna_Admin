import 'package:bbarna/core/widgets/loader_dialog.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/student/model/enrolled_course_model.dart';
import 'package:bbarna/student/model/student_model.dart';
import 'package:bbarna/student/repo/student_repo.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class StudentViewModel with ChangeNotifier {
  // Constructor-injectable so the paging, search and enrolment logic can be
  // exercised without real Firebase.
  final StudentRepo _studentRepo;
  StudentViewModel({StudentRepo? studentRepo})
      : _studentRepo = studentRepo ?? StudentRepo();

  List<Student> studentList = [];
  List<Student> copyStudentList = [];

  /// How many the collection holds in total, so the list can say
  /// "showing 300 of 4,200" rather than just "300".
  int studentListLength = 0;
  final int limit = 300;

  bool isLoading = true;
  bool isLoadingMore = false;

  /// Search is a local filter over the loaded pages — students are looked
  /// up by name or phone number, and Firestore cannot prefix-match two
  /// fields at once. The list says so.
  bool isSearching = false;

  /// How the list is ordered.
  StudentSort sort = StudentSort.name;

  /// How many students the `login_time` ordering can return. Only fetched
  /// while sorting by last active, where it is what the page count means.
  int signedInStudentCount = 0;

  /// Students the "Last active" ordering cannot reach, because Firestore
  /// omits documents missing the field it orders on. Zero for the name
  /// ordering, which every student has.
  int get studentsNeverSignedIn => sort == StudentSort.lastActive
      ? (studentListLength - signedInStudentCount).clamp(0, studentListLength)
      : 0;

  /// The total the footer is counting towards. Sorting by last active can
  /// only ever list the students that have signed in, so counting towards
  /// the whole collection would leave "Showing 40 of 52" stuck forever.
  ///
  /// Never below what is already on screen: the page and the count are two
  /// separate queries, and a student signing in between them would
  /// otherwise be reported as "Showing 4 of 3".
  int get reachableTotal {
    final int total = sort == StudentSort.lastActive
        ? signedInStudentCount
        : studentListLength;
    return total < studentList.length ? studentList.length : total;
  }

  bool get hasMore => !isSearching && studentList.length < reachableTotal;

  // ---- Enrolment (used by the student settings screens) ---------------
  List<CourseModel> courseList = [];
  List<SubjectModel> subjectList = [];
  List<UnitModel> unitList = [];
  List<String> selectedUnitList = [];
  List<String> editedUnitList = [];
  EnrolledCourseBaseModel? enrolledCourseBaseModel;
  int selectedUnitLength = 0;
  int selectedEditedUnitListLength = 0;
  List<UnitModel> selectedEditUnitList = [];
  List<UnitModel> editUnitList = [];
  EnrolledCourseModel? selectedSubjectModel;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Safe to call from any point in the frame — [StudentList] is mounted
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

  void clearStudentData() {
    enrolledCourseBaseModel = null;
    selectedEditUnitList = [];
    unitList = [];
  }

  // ---- The list -------------------------------------------------------

  /// Re-orders the list. Paging restarts: a cursor from one ordering means
  /// nothing to the other.
  Future<void> setSort(StudentSort next) async {
    if (sort == next) return;
    sort = next;
    notifyListeners();
    await fetchFirstStudentList();
  }

  Future<void> fetchFirstStudentList() async {
    isLoading = true;
    isSearching = false;
    notifyListeners();
    try {
      copyStudentList =
          await _studentRepo.getFirstStudentList(limit, sort: sort);
      _applySearch();
      studentListLength = await _studentRepo.getStudentListLength();
      if (sort == StudentSort.lastActive) {
        signedInStudentCount = await _studentRepo.getSignedInStudentCount();
      }
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching students", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextStudentList() async {
    if (isLoadingMore || !hasMore) return;

    isLoadingMore = true;
    notifyListeners();
    try {
      studentList.addAll(await _studentRepo.getNextStudentList(limit));
      copyStudentList = List<Student>.from(studentList);
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching more students", isSuccess: false);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Kept for the screens that called it directly; the count now arrives
  /// with the first page.
  Future<void> getStudentListLength() async {
    try {
      studentListLength = await _studentRepo.getStudentListLength();
      notifyListeners();
    } catch (_) {}
  }

  /// What the search box last held. Kept here rather than on the list
  /// screen so it survives the round trip to Add/Edit, and is
  /// re-applied after every refetch instead of showing everything.
  String searchText = "";

  void searchStudent({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    final String query = searchText.toLowerCase().trim();
    isSearching = query.isNotEmpty;
    if (query.isEmpty) {
      studentList = List<Student>.from(copyStudentList);
    } else {
      studentList = copyStudentList
          .where((student) =>
              student.studentName.toLowerCase().contains(query) ||
              student.studentPhoneNumber.contains(query) ||
              student.studentEmail.toLowerCase().contains(query))
          .toList();
    }
  }

  /// Deletes by document id and drops that row from both lists.
  ///
  /// The list widget used to delete straight through
  /// `FirebaseFirestore.instance` and then call `removeStudent(index)`,
  /// which removed whatever row happened to sit at that index — and left
  /// `copyStudentList` holding the deleted student, so clearing the search
  /// brought them back.
  Future<bool> deleteStudent(String studentId) async {
    try {
      await _studentRepo.deleteStudent(studentId);
      studentList = studentList.where((s) => s.studentId != studentId).toList();
      copyStudentList =
          copyStudentList.where((s) => s.studentId != studentId).toList();
      if (studentListLength > 0) studentListLength--;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the student", isSuccess: false);
      return false;
    }
  }

  /// Signs the student out of every device.
  Future<bool> clearDeviceCount(String studentId) async {
    try {
      await _studentRepo.clearDeviceCount(studentId);
      for (final Student student in studentList) {
        if (student.studentId == studentId) student.deviceCount = 0;
      }
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while signing the student out", isSuccess: false);
      return false;
    }
  }

  // ---- Enrolment ------------------------------------------------------

  Future<void> getEnrolledCourseList(String studentId) async {
    try {
      // Null when the student has no enrolments — the repo used to take
      // `docs.first` unguarded and throw.
      enrolledCourseBaseModel =
          await _studentRepo.getEnrolledCourseList(studentId);
    } catch (e) {
      enrolledCourseBaseModel = null;
    }
    notifyListeners();
  }

  /// Loads the courses for the enrolment picker.
  ///
  /// This used to push the global loader dialog and pop it on completion.
  /// It is called from a screen's `initState`, and the dialog is scheduled
  /// 100ms out — so a fetch that finished first popped the *page* instead.
  Future<void> getCourseList() async {
    try {
      courseList = await _studentRepo.getCourseList();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching courses", isSuccess: false);
    }
    notifyListeners();
  }

  Future<void> getSubjectList(String courseCode) async {
    try {
      subjectList = await _studentRepo.getSubjectList(courseCode);
    } catch (e) {
      subjectList = [];
    }
    clearUnitList();
    notifyListeners();
  }

  Future<void> getUnitList({required String subjectCode}) async {
    clearUnitList();
    notifyListeners();
    try {
      unitList = await _studentRepo.getUnitList(subjectCode: subjectCode);
      selectedUnitList =
          List<String>.filled(unitList.length, "", growable: true);
    } catch (e) {
      unitList = [];
      selectedUnitList = [];
    }
    notifyListeners();
  }

  // Reassign rather than `.clear()`: `selectedUnitList` comes from
  // `List.filled`, which is fixed-length and throws on clear.
  void clearUnitList() {
    selectedUnitList = [];
    unitList = [];
    selectedUnitLength = 0;
  }
  void clearSubjectList() {
    subjectList = [];
    selectedSubjectModel=null;
  }
  void updateCheckList(int index) {
    selectedUnitList[index] =
        selectedUnitList[index] == "" ? unitList[index].code : "";
    selectedUnitLength =
        selectedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  void setAllCheckList() {
    final bool selectAll = selectedUnitList.contains("");
    for (int i = 0; i < unitList.length; i++) {
      selectedUnitList[i] = selectAll ? unitList[i].code : "";
    }
    selectedUnitLength =
        selectedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  Future<void> enrolledCourse(
    String subjectCode,
    String subjectName,
    String subjectImage,
    int accessTill,
    String studentId,
    String studentName,
  ) async {
    LoaderDialogs.showLoadingDialog();
    try {
      final List<String> units =
          selectedUnitList.where((element) => element != "").toList();
      await _studentRepo.addCourse({
        "access_till": accessTill,
        "access_type": "PAID",
        "subject_code": subjectCode,
        "subject_image": subjectImage,
        "subject_name": subjectName,
        "unit_code_list": units,
      }, studentId, studentName);

      Navigator.pop(navigatorKey.currentContext!);
      await getEnrolledCourseList(studentId);
    } catch (e) {
      Navigator.pop(navigatorKey.currentContext!);
      Helper.showSnackBarMessage(
          msg: "Error while enrolling the student", isSuccess: false);
    }
  }

  Future<void> removeCourse(String courseId) async {
    final EnrolledCourseBaseModel? enrolment = enrolledCourseBaseModel;
    if (enrolment == null) return;

    enrolment.enrolledCourseList
        .removeWhere((element) => element.subjectCode == courseId);
    try {
      if (enrolment.enrolledCourseList.isNotEmpty) {
        await _studentRepo.updateEnrolment(enrolment.docId, enrolment.toMap());
        Navigator.pop(navigatorKey.currentContext!);
        Helper.showInfoMessage(msg: "Course removed successfully");
      } else {
        await _studentRepo.deleteEnrolment(enrolment.docId);
        Navigator.pop(navigatorKey.currentContext!);
        enrolledCourseBaseModel = null;
      }
      notifyListeners();
    } catch (e) {
      Navigator.pop(navigatorKey.currentContext!);
      Helper.showSnackBarMessage(
          msg: "Sorry something went wrong", isSuccess: false);
    }
  }

  Future<void> setEditedUnitList(String subjectCode) async {
    selectedEditUnitList = [];
    selectedSubjectModel = enrolledCourseBaseModel?.enrolledCourseList
        .where((element) => element.subjectCode == subjectCode)
        .firstOrNull;
    notifyListeners();

    try {
      selectedEditUnitList =
          await _studentRepo.getUnitList(subjectCode: subjectCode);
    } catch (e) {
      selectedEditUnitList = [];
    }

    final List<String> alreadyEnrolled =
        selectedSubjectModel?.unitCodeList ?? const [];
    editedUnitList = [
      for (final UnitModel unit in selectedEditUnitList)
        alreadyEnrolled.contains(unit.code) ? unit.code : "",
    ];
    selectedEditedUnitListLength =
        editedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  void updateEditedUnitList() {
    final bool selectAll = editedUnitList.contains("");
    for (int i = 0; i < editedUnitList.length; i++) {
      editedUnitList[i] = selectAll ? selectedEditUnitList[i].code : "";
    }
    selectedEditedUnitListLength =
        editedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  void updateEditedCheckList(int index) {
    editedUnitList[index] =
        editedUnitList[index] == "" ? selectedEditUnitList[index].code : "";
    selectedEditedUnitListLength =
        editedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  void setEditUnitData(List<UnitModel> unitData) {
    editUnitList = unitData;
    notifyListeners();
  }

  Future<void> updateEditUnitCourse(String courseId) async {
    final EnrolledCourseBaseModel? enrolment = enrolledCourseBaseModel;
    if (enrolment == null) return;

    LoaderDialogs.showLoadingDialog();
    final int courseIndex = enrolment.enrolledCourseList
        .indexWhere((element) => element.subjectCode == courseId);
    if (courseIndex == -1) {
      Navigator.pop(navigatorKey.currentContext!);
      return;
    }
    enrolment.enrolledCourseList[courseIndex].unitCodeList =
        editedUnitList.where((element) => element != "").toList();

    try {
      await _studentRepo.updateEnrolment(enrolment.docId, enrolment.toMap());
      Navigator.pop(navigatorKey.currentContext!);
      Helper.showSnackBarMessage(
          msg: "Course updated successfully", isSuccess: true);
      notifyListeners();
    } catch (e) {
      Navigator.pop(navigatorKey.currentContext!);
      Helper.showSnackBarMessage(
          msg: "Sorry something went wrong", isSuccess: false);
    }
  }
}
