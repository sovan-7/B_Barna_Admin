import 'package:bbarna/core/viewModel/async_list.dart';
import 'package:bbarna/core/mixins/safe_notifier.dart';
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
  final int limit = 50;

  /// True while the first page is loading (drives the skeleton rows).
  bool isLoading = true;

  /// Why the list could not be loaded, or null. While set and nothing is
  /// loaded, the screen shows an error with Retry instead of "No students
  /// yet".
  String? loadError;

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
    final StudentSort previous = sort;
    sort = next;
    // fetchFirstStudentList notifies straight away, which also updates the
    // sort toggle.
    await fetchFirstStudentList();
    // The rows are still in the old order if the reload failed, so the
    // toggle goes back to match them.
    if (loadError != null && copyStudentList.isNotEmpty) {
      sort = previous;
      notifyListeners();
    }
  }

  /// Loads the first page in the current [sort] order, re-applies the
  /// search, and refreshes the counts.
  Future<void> fetchFirstStudentList() async {
    // Skeleton only when nothing is on screen yet.
    isLoading = copyStudentList.isEmpty;
    loadError = null;
    isSearching = false;
    notifyListeners();
    // The page and the counts are independent queries: run them together.
    // Future.sync turns a synchronous throw into a failed future.
    final Future<List<Student>> page =
        Future.sync(() => _studentRepo.getFirstStudentList(limit, sort: sort));
    final Future<int> total = Future.sync(_studentRepo.getStudentListLength);
    final Future<int>? signedIn = sort == StudentSort.lastActive
        ? Future.sync(_studentRepo.getSignedInStudentCount)
        : null;
    try {
      copyStudentList = await page;
      _applySearch();
      studentListLength = await total;
      if (signedIn != null) signedInStudentCount = await signedIn;
    } catch (e) {
      loadError = "Couldn't load students";
      total.ignore();
      signedIn?.ignore();
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

  /// Signs the student out of the phone holding their login, and mirrors
  /// that on the loaded row.
  Future<bool> signOutDevice(String studentId) async {
    try {
      await _studentRepo.signOutDevice(studentId);
      for (final Student student in studentList) {
        if (student.studentId == studentId) {
          // Keep the sign-in time for the row's "Active ..." label: the phone
          // really was active then, even though the stored field is deleted.
          student.loginTime = student.lastLoginAt?.millisecondsSinceEpoch ??
              student.loginTime;
          student.activeDeviceId = "";
          student.activeDeviceName = "";
          student.activeLoginAt = null;
        }
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

  /// Courses offered in the enrol picker, with their loading / error state.
  final AsyncList<CourseModel> courseOptions = AsyncList<CourseModel>();

  /// Subjects of the course picked in the enrol card (loading / error).
  final AsyncList<SubjectModel> subjectOptions = AsyncList<SubjectModel>();

  /// Units of the subject picked in the enrol card (loading / error).
  final AsyncList<UnitModel> unitOptions = AsyncList<UnitModel>();

  /// The options in [courseOptions].
  List<CourseModel> get courseList => courseOptions.items;

  /// The options in [subjectOptions].
  List<SubjectModel> get subjectList => subjectOptions.items;

  /// The options in [unitOptions].
  List<UnitModel> get unitList => unitOptions.items;

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

  /// True while the student's enrolments are loading.
  bool isLoadingEnrolment = false;

  /// Why the student's enrolments could not be loaded, or null.
  String? enrolmentError;

  /// True while an enrolment is being saved (the Enrol button spins).
  bool isEnrolling = false;

  /// True while the "edit units" dialog is saving.
  bool isSavingUnits = false;

  /// True while the units for the "edit units" dialog are loading.
  bool isLoadingEditUnits = false;

  /// Why the units for the "edit units" dialog failed to load, or null.
  String? editUnitsError;

  /// The enrolled subject currently being edited.
  EnrolledCourseModel? selectedSubjectModel;

  /// Resets the per-student enrolment state when the settings screen opens
  /// for a different student.
  void clearStudentData() {
    enrolledCourseBaseModel = null;
    enrolmentError = null;
    selectedEditUnitList = [];
    unitOptions.reset();
  }

  // ---- Enrolment actions ------------------------------------------------

  /// Loads the student's enrolment document into
  /// [enrolledCourseBaseModel] (null when they have none). On failure the
  /// last loaded enrolments stay and [enrolmentError] is set.
  Future<void> getEnrolledCourseList(String studentId) async {
    isLoadingEnrolment = true;
    enrolmentError = null;
    notifyListeners();
    try {
      // The repo returns null when the student has no enrolments.
      enrolledCourseBaseModel =
          await _studentRepo.getEnrolledCourseList(studentId);
    } catch (e) {
      enrolmentError = "Couldn't load the enrolments";
    } finally {
      isLoadingEnrolment = false;
      notifyListeners();
    }
  }

  /// Loads the courses for the enrol picker. Uses no loader dialog: it is
  /// called from `initState`, where a delayed dialog could end up popping
  /// the page instead of itself.
  Future<void> getCourseList() async {
    await courseOptions.load(
      _studentRepo.getCourseList,
      errorMessage: "Couldn't load courses",
      onChange: notifyListeners,
    );
    if (courseOptions.error != null) {
      Helper.showSnackBarMessage(
          msg: "Error while fetching courses", isSuccess: false);
    }
  }

  /// Loads the subjects of [courseCode] and clears the unit picker.
  Future<void> getSubjectList(String courseCode) {
    clearUnitList();
    return subjectOptions.load(
      () => _studentRepo.getSubjectList(courseCode),
      errorMessage: "Couldn't load subjects",
      onChange: notifyListeners,
    );
  }

  /// Loads the units of [subjectCode] with none ticked.
  Future<void> getUnitList({required String subjectCode}) {
    clearUnitList();
    return unitOptions.load(
      () => _studentRepo.getUnitList(subjectCode: subjectCode),
      errorMessage: "Couldn't load units",
      onChange: notifyListeners,
      // One empty slot per unit: none ticked.
      onLoaded: (units) => selectedUnitList =
          List<String>.filled(units.length, "", growable: true),
    );
  }

  /// Empties the unit picker.
  // Reassign rather than `.clear()`: `selectedUnitList` comes from
  // `List.filled`, which is fixed-length and throws on clear.
  void clearUnitList() {
    selectedUnitList = [];
    unitOptions.reset();
    selectedUnitLength = 0;
  }

  /// Empties the subject picker.
  void clearSubjectList() {
    subjectOptions.reset();
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
  /// [accessTill] (epoch ms), then reloads their enrolments. The Enrol button shows
  /// [isEnrolling]; returns true when the enrolment was saved.
  Future<bool> enrolledCourse(
    String subjectCode,
    String subjectName,
    String subjectImage,
    int accessTill,
    String studentId,
    String studentName,
  ) async {
    // Ignore a second tap while the first enrol is still saving.
    if (isEnrolling) return false;
    isEnrolling = true;
    notifyListeners();
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

      Helper.showSnackBarMessage(
          msg: "Enrolled in $subjectName", isSuccess: true);
      await getEnrolledCourseList(studentId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while enrolling the student", isSuccess: false);
      return false;
    } finally {
      isEnrolling = false;
      notifyListeners();
    }
  }

  /// Returns true when the change was saved (the local state already
  /// matches); false means the caller should reload the enrolment.
  ///
  /// Removes enrolled subject [courseId]. If it was the last one, the whole
  /// enrolment document is deleted. Pops the open confirmation dialog.
  Future<bool> removeCourse(String courseId) async {
    final EnrolledCourseBaseModel? enrolment = enrolledCourseBaseModel;
    if (enrolment == null) return false;

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
      return true;
    } catch (e) {
      Navigator.pop(navigatorKey.currentContext!);
      Helper.showSnackBarMessage(
          msg: "Sorry something went wrong", isSuccess: false);
      return false;
    }
  }

  /// Prepares the "edit units" dialog for enrolled subject [subjectCode]:
  /// loads all its units and pre-ticks the ones already enrolled.
  Future<void> setEditedUnitList(String subjectCode) async {
    selectedEditUnitList = [];
    editedUnitList = [];
    selectedEditedUnitListLength = 0;
    editUnitsError = null;
    isLoadingEditUnits = true;
    selectedSubjectModel = enrolledCourseBaseModel?.enrolledCourseList
        .where((element) => element.subjectCode == subjectCode)
        .firstOrNull;
    notifyListeners();

    try {
      selectedEditUnitList =
          await _studentRepo.getUnitList(subjectCode: subjectCode);
    } catch (e) {
      selectedEditUnitList = [];
      editUnitsError = "Couldn't load the units";
    } finally {
      isLoadingEditUnits = false;
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

  /// Returns true when saved (local state already matches); false means
  /// the caller should reload the enrolment.
  ///
  /// Saves the edit dialog: replaces enrolled subject [courseId]'s unit
  /// list with the ticked units ([isSavingUnits] while saving).
  Future<bool> updateEditUnitCourse(String courseId) async {
    final EnrolledCourseBaseModel? enrolment = enrolledCourseBaseModel;
    if (enrolment == null || isSavingUnits) return false;

    final int courseIndex = enrolment.enrolledCourseList
        .indexWhere((element) => element.subjectCode == courseId);
    if (courseIndex == -1) return false;
    enrolment.enrolledCourseList[courseIndex].unitCodeList =
        editedUnitList.where((element) => element != "").toList();

    // The dialog's Save button spins while this runs.
    isSavingUnits = true;
    notifyListeners();
    try {
      await _studentRepo.updateEnrolment(enrolment.docId, enrolment.toMap());
      Helper.showSnackBarMessage(
          msg: "Course updated successfully", isSuccess: true);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Sorry something went wrong", isSuccess: false);
      return false;
    } finally {
      isSavingUnits = false;
      notifyListeners();
    }
  }
}
