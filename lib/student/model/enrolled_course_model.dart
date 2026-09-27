import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A student's enrolment document (`enrolledCourse` collection): one per
/// student, listing every subject they can access.
class EnrolledCourseBaseModel {
  /// The student this belongs to (`student_id`).
  String studentId = stringDefault;

  /// Student name, copied for display (`student_name`).
  String studentName = stringDefault;

  /// One entry per enrolled subject (`course_list`).
  List<EnrolledCourseModel> enrolledCourseList = [];

  /// Firestore document id.
  String docId = stringDefault;

  /// Reads the enrolment document.
  EnrolledCourseBaseModel.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc)
      : studentId = doc.data()?["student_id"] ?? stringDefault,
        studentName = doc.data()?["student_name"] ?? stringDefault,
        docId = doc.id,
        // Empty, not a placeholder. This used to build one course out of
        // leftover debug strings — "hggh", "bvnbn", "jhjh" — so a student
        // with no enrolments showed a course named "jhjh".
        enrolledCourseList = doc.data()?["course_list"] == null
            ? <EnrolledCourseModel>[]
            : List<EnrolledCourseModel>.from(
                (doc.data()?["course_list"] as List<dynamic>).map((x) =>

                    /// Reads one entry of `course_list`.
                    EnrolledCourseModel.fromMap(x as Map<String, dynamic>)));

  /// The full document, for `update()`.
  Map<String, dynamic> toMap() {
    return {
      "student_id": studentId,
      "student_name": studentName,
      "course_list":
          enrolledCourseList.map((course) => course.toMap()).toList(),
    };
  }
}

/// One enrolled subject inside [EnrolledCourseBaseModel.enrolledCourseList].
class EnrolledCourseModel {
  /// The subject's code (`subject_code`).
  String subjectCode = stringDefault;

  /// Subject name, copied for display (`subject_name`).
  String subjectName = stringDefault;

  /// Subject thumbnail URL, copied for display (`subject_image`).
  String subjectImage = stringDefault;

  /// Access end in epoch milliseconds (`access_till`); see
  /// `EnrolmentValidity` for how "unset" is detected.
  int accessTill = intDefault;

  /// How access was granted, e.g. "PAID" (`access_type`).
  String accessType = stringDefault;

  /// Units of the subject the student can open (`unit_code_list`).
  List<String> unitCodeList = [];

  /// Creates an enrolled subject.
  EnrolledCourseModel(
    this.subjectCode,
    this.subjectName,
    this.subjectImage,
    this.accessTill,
    this.accessType,
    this.unitCodeList,
  );
// Convert ResultModel to a Map for Firestore
  /// This entry as a map inside `course_list`.
  Map<String, dynamic> toMap() {
    return {
      "subject_code": subjectCode,
      "subject_name": subjectName,
      "subject_image": subjectImage,
      "access_till": accessTill,
      "access_type": accessType,
      "unit_code_list": unitCodeList,
    };
  }

  EnrolledCourseModel.fromMap(Map<String, dynamic> map)
      : subjectCode = map["subject_code"] ?? stringDefault,
        subjectName = map["subject_name"] ?? stringDefault,
        subjectImage = map["subject_image"] ?? stringDefault,
        accessTill = map["access_till"] ?? intDefault,
        accessType = map["access_type"] ?? stringDefault,
        unitCodeList = map["unit_code_list"] == null
            ? []
            : List<String>.from(map["unit_code_list"] as List<dynamic>);
}
