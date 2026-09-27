import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A subject (`subject` collection): sits under one course, is what
/// students buy and enrol in, and units hang off it.
class SubjectModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Subject code, stored upper-case (`subject_code`).
  String code = stringDefault;

  /// Code of the course it belongs to (`course_code`).
  String courseCode = stringDefault;

  /// Name of that course, copied for display (`course_name`).
  String courseName = stringDefault;

  /// "Full Course", "Part Course" or "Mock Test" (`course_type`).
  String courseType = stringDefault;

  /// Creation time in epoch milliseconds (`created_at`).
  int timeStamp = intDefault;

  /// Free-text description (`subject_description`).
  String description = stringDefault;

  /// Display name (`subject_name`).
  String name = stringDefault;

  /// Download URL of the thumbnail (`subject_image`).
  String image = stringDefault;

  /// List price in rupees (`subject_price`).
  double price = doubleDefault;

  /// What a student actually pays (`selling_price`).
  double sellingPrice = doubleDefault;

  /// Sort order in the app; lower comes first (`display_priority`).
  int displayPriority = intDefault;

  /// Whether the app shows the subject at all (`willDisplay`).
  bool willDisplay = boolDefault;

  /// Visible but not purchasable/openable (`isLocked`).
  bool isLocked = boolDefault;

  /// UI-only tick state for pickers; never stored.
  bool isSelected = boolDefault;

  /// Highlighted on the app home screen (`isPopular`).
  bool isPopular = boolDefault;

  /// The coupon on this subject, as the student app reads it:
  /// `couponDiscount` is a flat rupee amount off `sellingPrice`, not a
  /// percentage, and `couponValidTill` is epoch millis.
  ///
  /// All three are editable from Add/Edit Subject (see [SubjectForm]) and
  /// are included in [toMap]; a subject with no coupon writes the NA/-1
  /// defaults for each.
  String couponCode = stringDefault;

  /// Flat rupee discount off [sellingPrice] (`couponDiscount`).
  double couponDiscount = doubleDefault;

  /// Last moment the coupon works, epoch millis (`couponValidTill`).
  int couponValidTill = intDefault;

  /// Creates a subject from the Add/Edit form values.
  SubjectModel(
    this.courseCode,
    this.courseType,
    this.courseName,
    this.price,
    this.sellingPrice,
    this.code,
    this.description,
    this.name,
    this.image,
    this.displayPriority,
    this.timeStamp,
    this.willDisplay,
    this.isLocked,
    this.isPopular, {
    String? couponCode,
    double? couponDiscount,
    int? couponValidTill,
  })  : couponCode = couponCode ?? stringDefault,
        couponDiscount = couponDiscount ?? doubleDefault,
        couponValidTill = couponValidTill ?? intDefault;

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "course_code": courseCode,
      "course_type": courseType,
      "course_name": courseName,
      "subject_code": code.trim(),
      "subject_description": description,
      "subject_name": name,
      "created_at": timeStamp,
      "subject_image": image,
      "display_priority": displayPriority,
      "subject_price": price,
      "selling_price": sellingPrice,
      "willDisplay": willDisplay,
      "isLocked": isLocked,
      "isPopular": isPopular,
      "couponCode": couponCode.trim(),
      "couponDiscount": couponDiscount,
      "couponValidTill": couponValidTill,
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  SubjectModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        courseCode = doc.data()!["course_code"] ?? stringDefault,
        courseType = doc.data()!["course_type"] ?? stringDefault,
        courseName = doc.data()!["course_name"] ?? stringDefault,
        code = doc.data()!["subject_code"] ?? stringDefault,
        description = doc.data()!["subject_description"] ?? stringDefault,
        name = doc.data()!["subject_name"] ?? stringDefault,
        image = doc.data()!["subject_image"] ?? stringDefault,
        price = doc.data()!["subject_price"] ?? doubleDefault,
        sellingPrice = doc.data()!["selling_price"] ?? doubleDefault,
        displayPriority = doc.data()!["display_priority"] ?? intDefault,
        willDisplay = doc.data()!["willDisplay"] ?? boolDefault,
        isLocked = doc.data()!["isLocked"] ?? boolDefault,
        timeStamp = doc.data()!["created_at"] ?? intDefault,
        isPopular = doc.data()!["isPopular"] ?? boolDefault,
        couponCode = doc.data()!["couponCode"] ?? stringDefault,
        // Firestore hands a whole number back as an int, so cast through num
        // rather than assuming double.
        couponDiscount = (doc.data()!["couponDiscount"] as num?)?.toDouble() ??
            doubleDefault,
        couponValidTill = doc.data()!["couponValidTill"] ?? intDefault,
        isSelected = false;
}
