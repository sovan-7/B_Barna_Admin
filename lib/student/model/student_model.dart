import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A student account created by the mobile app (`student` collection).
/// The admin only reads, signs out and deletes students.
class Student {
  /// Firestore document id.
  String studentId = stringDefault;

  /// Full name (`name`).
  String studentName = stringDefault;

  /// Mobile number (`mobile_number`).
  String studentPhoneNumber = stringDefault;

  /// WhatsApp number (`student_wp_number`).
  String studentWhatsappNumber = stringDefault;

  /// Email address (`student_email`).
  String studentEmail = stringDefault;

  /// Download URL of the profile photo (`student_image`).
  String studentProfileImage = stringDefault;

  /// Guardian's full name (`guardian_full_name`).
  String? guardianFullName = stringDefault;

  /// Date of birth as entered in the app (`birthday`).
  String? birthDay = stringDefault;

  /// Marital status (`is_married`).
  bool? isMarried = boolDefault;

  /// Highest qualification (`highest_degree`).
  String? highestDegree = stringDefault;

  /// College name (`college_name`).
  String? collegeName = stringDefault;

  /// Whether the student accepted the terms (`is_tms_accepted`).
  bool? isTmsAccepted;

  /// Postal address (`address`).
  Address? address;

  /// How many devices they are signed in on (`device_count`).
  dynamic deviceCount = intDefault;

  /// Last sign-in in epoch milliseconds (`login_time`); see [lastLoginAt].
  int? loginTime = intDefault;

  /// Creates a student (used by tests and the app).
  Student(
      {required this.studentId,
      required this.studentName,
      required this.studentProfileImage,
      required this.studentPhoneNumber,
      required this.studentWhatsappNumber,
      required this.studentEmail,
      this.guardianFullName,
      this.birthDay,
      this.isMarried,
      this.highestDegree,
      this.collegeName,
      this.isTmsAccepted,
      this.address,
      this.deviceCount,
      this.loginTime});

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "name": studentName,
      "student_image": studentProfileImage,
      "student_email": studentEmail,
      "mobile_number": studentPhoneNumber,
      "student_wp_number": studentWhatsappNumber,
      "guardian_full_name": guardianFullName,
      "birthday": birthDay,
      "is_married": isMarried,
      "highest_degree": highestDegree,
      "college_name": collegeName,
      "is_tms_accepted": isTmsAccepted,
      "address": address?.toMap()
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  Student.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : studentId = doc.id,
        studentName = doc.data()!["name"] ?? stringDefault,
        studentEmail = doc.data()!["student_email"] ?? stringDefault,
        studentProfileImage = doc.data()!["student_image"] ?? stringDefault,
        studentPhoneNumber = doc.data()!["mobile_number"] ?? stringDefault,
        studentWhatsappNumber =
            doc.data()!["student_wp_number"] ?? stringDefault,
        guardianFullName = doc.data()!["guardian_full_name"] ?? stringDefault,
        birthDay = doc.data()!["birthday"] ?? stringDefault,
        isMarried = doc.data()!["is_married"] ?? boolDefault,
        highestDegree = doc.data()!["highest_degree"] ?? stringDefault,
        collegeName = doc.data()!["college_name"] ?? stringDefault,
        isTmsAccepted = doc.data()!["is_tms_accepted"] ?? boolDefault,
        deviceCount = doc.data()!["device_count"] ?? intDefault,
        loginTime = doc.data()!["login_time"] ?? intDefault,
        address = doc.data()!["address"] != null
            ? Address.fromMap(doc.data()!["address"])
            : Address(stringDefault, stringDefault, stringDefault,
                stringDefault, stringDefault);

  /// When the student last opened the app, or null if they never have.
  ///
  /// `login_time` is -1 ([intDefault]) when the field is missing and 0 on a
  /// backfilled document; both mean "never", not 1 January 1970.
  DateTime? get lastLoginAt {
    final int? millis = loginTime;
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

/// A student's postal address (nested map `address`).
class Address {
  /// Postal PIN code (`pin_code`).
  String? pinCode = stringDefault;

  /// Street / house line (`line1`).
  String? line1 = stringDefault;

  /// Locality (`locality`).
  String? locality = stringDefault;

  /// City (`city`).
  String? city = stringDefault;

  /// State (`state`).
  String? state = stringDefault;

  /// Creates an address.
  Address(this.pinCode, this.line1, this.locality, this.city, this.state);

  /// Converts the address to its nested Firestore map.
  Map<String, dynamic> toMap() {
    return {
      "pin_code": pinCode,
      "line1": line1,
      "locality": locality,
      "city": city,
      "state": state
    };
  }

  /// Reads the nested `address` map.
  Address.fromMap(Map<String, dynamic> map)
      : pinCode = map["pin_code"],
        line1 = map["line1"],
        locality = map["locality"],
        city = map["city"],
        state = map["state"];
}
