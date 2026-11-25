import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// An admin-panel user (`teacher` collection). The document id is the
/// lower-cased username.
class TeacherModel {
  /// Firestore document id (same as [username]).
  String docId = stringDefault;

  /// Display name (`name`).
  String name = stringDefault;

  /// Download URL of the profile photo (`image_url`).
  String imageUrl = stringDefault;

  /// Lower-cased login name (`username`).
  String username = stringDefault;

  /// SHA-256 hash of the password (`password`); never the raw text.
  String password = stringDefault;

  /// Ten-digit phone number (`phone_number`).
  String phoneNumber = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Stored names of the sidebar modules this user may open
  /// (`module_access`).
  List<String> moduleAccess = const [];

  /// [roleAdmin] or [roleSubadmin] (`role`).
  String role = stringDefault;

  /// Creates a teacher (the view model fills in hash, image URL and time).
  TeacherModel({
    required this.docId,
    required this.name,
    required this.imageUrl,
    required this.username,
    required this.password,
    required this.phoneNumber,
    required this.timeStamp,
    required this.moduleAccess,
    required this.role,
  });

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "image_url": imageUrl,
      "username": username,
      "password": password,
      "phone_number": phoneNumber,
      "timeStamp": timeStamp,
      "module_access": moduleAccess,
      "role": role,
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  TeacherModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        name = doc.data()!["name"] ?? stringDefault,
        imageUrl = doc.data()!["image_url"] ?? stringDefault,
        username = doc.data()!["username"] ?? stringDefault,
        password = doc.data()!["password"] ?? stringDefault,
        phoneNumber = doc.data()!["phone_number"] ?? stringDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault,
        moduleAccess = List<String>.from(doc.data()!["module_access"] ?? []),
        role = doc.data()!["role"] ?? roleSubadmin;
}
