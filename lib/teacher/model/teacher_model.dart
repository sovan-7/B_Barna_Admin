import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  String docId = stringDefault;
  String name = stringDefault;
  String imageUrl = stringDefault;
  String username = stringDefault;
  String password = stringDefault;
  String phoneNumber = stringDefault;
  int timeStamp = intDefault;
  List<String> moduleAccess = const [];
  String role = stringDefault;

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
