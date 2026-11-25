import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A unit (`unit` collection): sits under a subject, and topics hang off
/// it. It can also be shared into other subjects via [subjectCodeList].
class UnitModel {
  /// Firestore document id (not stored inside the document).
  String id = stringDefault;

  /// Unit code, stored upper-case (`unit_code`).
  String code = stringDefault;

  /// Code of the course it belongs to (`course_code`).
  String courseCode = stringDefault;

  /// Name of that course, copied for display (`course_name`).
  String courseName = stringDefault;

  /// Code of its main subject (`subject_code`).
  String subjectCode = stringDefault;

  /// Name of that subject, copied for display (`subject_name`).
  String subjectName = stringDefault;

  /// Visible but not openable in the app (`lock_status`).
  bool lockStatus = boolDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Free-text description (`unit_description`).
  String description = stringDefault;

  /// Display name (`unit_name`).
  String name = stringDefault;

  /// Download URL of the thumbnail (`unit_image`).
  String image = stringDefault;

  /// Sort order in the app; lower comes first (`display_priority`).
  int displayPriority = intDefault;

  /// Whether the app shows the unit at all (`willShow`).
  bool willShow = boolDefault;

  /// UI-only tick state for pickers; never stored.
  bool isSelected = boolDefault;

  /// Every subject code the unit appears under, including its main one
  /// (`subjectCodeList`).
  List<String> subjectCodeList = [];

  /// Creates a unit from the Add/Edit form values.
  UnitModel(
      this.courseCode,
      this.courseName,
      this.subjectCode,
      this.subjectName,
      this.lockStatus,
      this.code,
      this.description,
      this.name,
      this.image,
      this.displayPriority,
      this.timeStamp,
      this.willShow,
      this.subjectCodeList);

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "course_code": courseCode,
      "course_name": courseName,
      "subject_code": subjectCode,
      "subject_name": subjectName,
      "unit_name": name,
      "unit_code": code.trim(),
      "unit_description": description,
      "timeStamp": timeStamp,
      "lock_status": lockStatus,
      "unit_image": image,
      "display_priority": displayPriority,
      "willShow": willShow,
      "subjectCodeList": subjectCodeList
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  UnitModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        courseCode = doc.data()!["course_code"] ?? stringDefault,
        courseName = doc.data()!["course_name"] ?? stringDefault,
        subjectCode = doc.data()!["subject_code"] ?? stringDefault,
        subjectName = doc.data()!["subject_name"] ?? stringDefault,
        code = doc.data()!["unit_code"] ?? stringDefault,
        description = doc.data()!["unit_description"] ?? stringDefault,
        name = doc.data()!["unit_name"] ?? stringDefault,
        image = doc.data()!["unit_image"] ?? stringDefault,
        lockStatus = doc.data()!["lock_status"] ?? boolDefault,
        displayPriority = doc.data()!["display_priority"] ?? intDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault,
        willShow = doc.data()!["willShow"] ?? boolDefault,
        subjectCodeList = List<String>.from(
            doc.data()!["subjectCodeList"] ?? const <String>[]),
        isSelected = false;
}
