import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A teacher as the class form needs them: a name to show and the document
/// id to store (the student app uses the id to mark who is teaching in the
/// live room's chat and people list).
class LiveClassTeacher {
  /// Teacher document id.
  final String id;

  /// Display name.
  final String name;

  /// Phone number; empty when not set.
  final String phoneNumber;
  const LiveClassTeacher(
      {required this.id, required this.name, this.phoneNumber = ""});
}

/// A subject as the class form needs it: the name shown on the student's
/// class card, and the code stored alongside it.
class LiveClassSubject {
  /// Subject code stored on the class.
  final String code;

  /// Subject name printed on the student's class card.
  final String name;
  const LiveClassSubject({required this.code, required this.name});
}

/// Firestore access for live classes, plus the teacher / subject lookups
/// the class form's dropdowns need. Firestore is injectable for tests.
///
/// Every method throws on failure; [LiveClassViewModel] catches and
/// reports.
class LiveClassRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore;

  LiveClassRepo({FirebaseFirestore? firestore})
      : _fireStore = firestore ?? FirebaseFirestore.instance;

  /// Adds the class with server-stamped `createdAt`/`updatedAt`, so a wrong
  /// clock on the admin's machine cannot skew ordering.
  Future<void> addLiveClass(LiveClassModel liveClassModel) async {
    await _fireStore.collection(liveClasses).add({
      ...liveClassModel.toMap(),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// Leaves `createdAt` untouched — only `updatedAt` is re-stamped.
  Future<void> updateLiveClass(LiveClassModel liveClassModel) async {
    await _fireStore.collection(liveClasses).doc(liveClassModel.docId).update({
      ...liveClassModel.toMap(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  /// Rewrites a class that is still in the old shape.
  ///
  /// Like [updateLiveClass], but also deletes the four superseded keys —
  /// `update()` merges, so otherwise the document would keep both
  /// spellings of every field.
  Future<void> migrateToAppSchema(LiveClassModel liveClassModel) async {
    await _fireStore.collection(liveClasses).doc(liveClassModel.docId).update({
      ...liveClassModel.toMap(),
      "updatedAt": FieldValue.serverTimestamp(),
      "startDateTime": FieldValue.delete(),
      "endDateTime": FieldValue.delete(),
      "description": FieldValue.delete(),
      "youtubeLink": FieldValue.delete(),
    });
  }

  /// Deletes the class document.
  Future<void> deleteLiveClass(String docId) async {
    await _fireStore.collection(liveClasses).doc(docId).delete();
  }

  /// Every class, newest-scheduled first. The whole collection is fetched
  /// at once (no paging).
  ///
  /// Sorted in memory rather than with `orderBy`: Firestore's `orderBy`
  /// silently drops documents missing the field, which would hide classes
  /// still saved in the old shape.
  Future<List<LiveClassModel>> getLiveClassList() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fireStore.collection(liveClasses).get();
    final List<LiveClassModel> classes = snapshot.docs
        .map((docSnapshot) => LiveClassModel.fromDocumentSnapshot(docSnapshot))
        .toList();
    classes.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
    return classes;
  }

  /// Options for the Teacher dropdown, read from the `teacher` collection.
  /// Sorted case-insensitively; blank / default names are dropped.
  Future<List<LiveClassTeacher>> getTeachers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fireStore.collection(teacher).get();
    final List<LiveClassTeacher> teachers = snapshot.docs
        .map((doc) => LiveClassTeacher(
            id: doc.id,
            name: (doc.data()["name"] ?? "").toString().trim(),
            phoneNumber: (doc.data()["phone_number"] ?? "").toString().trim()))
        .where((t) => t.name.isNotEmpty && t.name != stringDefault)
        .toList();
    teachers
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return teachers;
  }

  /// Options for the Subject dropdown, read from the `subject` collection.
  /// Sorted case-insensitively; blank / default names are dropped.
  Future<List<LiveClassSubject>> getSubjects() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fireStore.collection(subject).get();
    final List<LiveClassSubject> subjects = snapshot.docs
        .map((doc) => LiveClassSubject(
              code: (doc.data()["subject_code"] ?? "").toString().trim(),
              name: (doc.data()["subject_name"] ?? "").toString().trim(),
            ))
        .where((s) => s.name.isNotEmpty && s.name != stringDefault)
        .toList();
    subjects
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return subjects;
  }
}
