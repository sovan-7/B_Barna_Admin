import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A course — the top level of the catalogue (`course` collection).
/// Subjects and units hang off it.
class CourseModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Course code, stored upper-case (`course_code`).
  String code = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Free-text description (`course_description`).
  String description = stringDefault;

  /// Display name (`course_name`).
  String name = stringDefault;

  /// Download URL of the thumbnail (`course_image`).
  String image = stringDefault;

  /// Sort order in the app; lower comes first (`display_priority`).
  int displayPriority = intDefault;

  /// Whether the app shows the course at all (`willDisplay`).
  bool willDisplay = boolDefault;

  /// Visible but not openable in the app (`isLocked`).
  bool isLocked = boolDefault;

  /// Creates a course from the Add/Edit form values.
  CourseModel(this.code, this.description, this.name, this.image,
      this.displayPriority, this.timeStamp, this.willDisplay, this.isLocked);

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "course_code": code.trim(),
      "course_description": description,
      "course_name": name,
      "timeStamp": timeStamp,
      "course_image": image,
      "display_priority": displayPriority,
      "willDisplay": willDisplay,
      "isLocked": isLocked
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  CourseModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        code = doc.data()!["course_code"] ?? stringDefault,
        description = doc.data()!["course_description"] ?? stringDefault,
        name = doc.data()!["course_name"] ?? stringDefault,
        image = doc.data()!["course_image"] ?? stringDefault,
        displayPriority = doc.data()!["display_priority"] ?? intDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault,
        willDisplay = doc.data()!["willDisplay"] ?? boolDefault,
        isLocked = doc.data()!["isLocked"] ?? boolDefault;
}
