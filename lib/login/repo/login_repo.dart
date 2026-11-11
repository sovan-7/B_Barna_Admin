import 'dart:convert';

import 'package:bbarna/login/model/login_result.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Firestore access for signing a teacher / admin in.
class LoginRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// Looks up the teacher whose username and password hash both match.
  ///
  /// Returns null when nothing matches; throws when the lookup itself
  /// fails, so the caller can tell "wrong password" from "no network".
  Future<LoginResult?> signIn(String username, String password) async {
    // Teacher docs store a SHA-256 hash (see TeacherViewModel.addTeacher),
    // never the raw password — hash the typed password the same way before
    // comparing, or this query never matches.
    final String hashedPassword =
        sha256.convert(utf8.encode(password)).toString();

    // Teacher docs store the normalized username (see TeacherViewModel
    // .addTeacher) — normalize the typed one the same way before comparing,
    // or a username with any capital letter never matches.
    final String lookupUsername = normalizeUsername(username);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _fireStore
        .collection(teacher)
        .where('username', isEqualTo: lookupUsername)
        .where('password', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;
    return LoginResult(
      adminId: doc.id,
      moduleAccess: List<String>.from(doc.data()['module_access'] ?? []),
      // Same fallback as TeacherModel: a document with no role is a
      // subadmin.
      role: doc.data()['role'] as String? ?? roleSubadmin,
    );
  }
}
