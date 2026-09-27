import 'package:bbarna/core/mixins/safe_notifier.dart';
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

/// State and actions for the Student module.
///
/// Two parts:
/// 1. **The list** – paged (300 per page) with a *local* search over the
///    loaded pages (name / phone / email), and two sort orders.
/// 2. **Enrolment** – the student settings screen: picking a course →
///    subject → units to enrol in, and editing or removing existing
///    enrolments.
class StudentViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final StudentRepo _studentRepo;
  StudentViewModel({StudentRepo? studentRepo})
      : _studentRepo = studentRepo ?? StudentRepo();

  // ---- List state -----------------------------------------------------

  /// Students currently shown (the loaded pages after the search filter).
  List<Student> studentList = [];

  /// Every loaded student, unfiltered; the search filters this.
  List<Student> copyStudentList = [];

  /// How many the collection holds in total, so the list can say
  /// "showing 300 of 4,200" rather than just "300".
  int studentListLength = 0;

  /// Students fetched per page.
  final int limit = 300;

  /// True while the first page is loading (drives the skeleton rows).
  bool isLoading = true;

  /// True while a further page is loading.
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

  /// Whether another page can be loaded (never while searching).
  bool get hasMore => !isSearching && studentList.length < reachableTotal;

  // ---- The list -------------------------------------------------------

  /// Re-orders the list. Paging restarts: a cursor from one ordering means
  /// nothing to the other.
  Future<void> setSort(StudentSort next) async {
    if (sort == next) return;
    sort = next;
    notifyListeners();
    await fetchFirstStudentList();
  }

  /// Loads the first page in the current [sort] order, re-applies the
  /// search, and refreshes the counts.
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

  /// Appends the next page (no-op while loading or when nothing is left).
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

  /// Refreshes just [studentListLength]. [fetchFirstStudentList] already
  /// does this; kept for screens that call it on its own.
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

  /// Filters the loaded students locally by name, phone or email.
  void searchStudent({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  /// Rebuilds [studentList] from [copyStudentList] using [searchText].
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

  /// Deletes by document id and, on success, drops that student from both
  /// the shown and the unfiltered list (so clearing the search does not
  /// bring them back) and lowers the total.
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

  /// Signs the student out of every device by resetting their device
  /// count, and mirrors that on the loaded row.
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

  // ---- Enrolment state (student settings screen) ---------------------
  //
  // The picker lists (courseList → subjectList → unitList) feed the
  // "Enrol" card. Unit selection is tracked positionally: selectedUnitList
  // has one slot per unit in unitList, holding the unit code when ticked
  // and "" when not. The "edit" lists do the same for an existing
  // enrolment's units.

  /// Courses offered in the enrol picker.
  List<CourseModel> courseList = [];

  /// Subjects of the course picked in the enrol card.
  List<SubjectModel> subjectList = [];

  /// Units of the subject picked in the enrol card.
  List<UnitModel> unitList = [];

  /// One slot per [unitList] entry: the unit code if ticked, else "".
  List<String> selectedUnitList = [];

  /// One slot per [selectedEditUnitList] entry: the unit code if ticked,
  /// else "" (editing an existing enrolment).
  List<String> editedUnitList = [];

  /// The student's enrolment document (all enrolled subjects), or null
  /// when they have none.
  EnrolledCourseBaseModel? enrolledCourseBaseModel;

  /// How many units are ticked in [selectedUnitList].
  int selectedUnitLength = 0;

  /// How many units are ticked in [editedUnitList].
  int selectedEditedUnitListLength = 0;

  /// All units of the enrolled subject being edited.
  List<UnitModel> selectedEditUnitList = [];

  /// Units handed to the edit dialog by the screen.
  List<UnitModel> editUnitList = [];

  /// The enrolled subject currently being edited.
  EnrolledCourseModel? selectedSubjectModel;

  /// Resets the per-student enrolment state when the settings screen opens
  /// for a different student.
  void clearStudentData() {
    enrolledCourseBaseModel = null;
    selectedEditUnitList = [];
    unitList = [];
  }

  // ---- Enrolment actions ------------------------------------------------

  /// Loads the student's enrolment document into
  /// [enrolledCourseBaseModel] (null when they have none or on error).
  Future<void> getEnrolledCourseList(String studentId) async {
    try {
      // The repo returns null when the student has no enrolments.
      enrolledCourseBaseModel =
          await _studentRepo.getEnrolledCourseList(studentId);
    } catch (e) {
      enrolledCourseBaseModel = null;
    }
    notifyListeners();
  }

  /// Loads the courses for the enrol picker. Uses no loader dialog: it is
  /// called from `initState`, where a delayed dialog could end up popping
  /// the page instead of itself.
  Future<void> getCourseList() async {
    try {
      courseList = await _studentRepo.getCourseList();
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching courses", isSuccess: false);
    }
    notifyListeners();
  }

  /// Loads the subjects of [courseCode] and clears the unit picker.
  Future<void> getSubjectList(String courseCode) async {
    try {
      subjectList = await _studentRepo.getSubjectList(courseCode);
    } catch (e) {
      subjectList = [];
    }
    clearUnitList();
    notifyListeners();
  }

  /// Loads the units of [subjectCode] with none ticked.
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

  /// Empties the unit picker.
  // Reassign rather than `.clear()`: `selectedUnitList` comes from
  // `List.filled`, which is fixed-length and throws on clear.
  void clearUnitList() {
    selectedUnitList = [];
    unitList = [];
    selectedUnitLength = 0;
  }

  /// Empties the subject picker.
  void clearSubjectList() {
    subjectList = [];
    selectedSubjectModel = null;
  }

  /// Ticks / unticks unit [index] in the enrol card.
  void updateCheckList(int index) {
    selectedUnitList[index] =
        selectedUnitList[index] == "" ? unitList[index].code : "";
    selectedUnitLength =
        selectedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  /// "Select all" in the enrol card: ticks every unit, or unticks all of
  /// them if every one was already ticked.
  void setAllCheckList() {
    final bool selectAll = selectedUnitList.contains("");
    for (int i = 0; i < unitList.length; i++) {
      selectedUnitList[i] = selectAll ? unitList[i].code : "";
    }
    selectedUnitLength =
        selectedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  /// Enrols the student in [subjectCode] with the ticked units, valid until
  /// [accessTill] (epoch ms), then reloads their enrolments. Shows the
  /// global loader dialog while saving.
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

  /// Removes enrolled subject [courseId]. If it was the last one, the whole
  /// enrolment document is deleted. Pops the open confirmation dialog.
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

  /// Prepares the "edit units" dialog for enrolled subject [subjectCode]:
  /// loads all its units and pre-ticks the ones already enrolled.
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

  /// "Select all" in the edit dialog (same toggle rule as
  /// [setAllCheckList]).
  void updateEditedUnitList() {
    final bool selectAll = editedUnitList.contains("");
    for (int i = 0; i < editedUnitList.length; i++) {
      editedUnitList[i] = selectAll ? selectedEditUnitList[i].code : "";
    }
    selectedEditedUnitListLength =
        editedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  /// Ticks / unticks unit [index] in the edit dialog.
  void updateEditedCheckList(int index) {
    editedUnitList[index] =
        editedUnitList[index] == "" ? selectedEditUnitList[index].code : "";
    selectedEditedUnitListLength =
        editedUnitList.where((element) => element != "").length;
    notifyListeners();
  }

  /// Stores the units the edit dialog should show.
  void setEditUnitData(List<UnitModel> unitData) {
    editUnitList = unitData;
    notifyListeners();
  }

  /// Saves the edit dialog: replaces enrolled subject [courseId]'s unit
  /// list with the ticked units. Shows the global loader dialog.
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
