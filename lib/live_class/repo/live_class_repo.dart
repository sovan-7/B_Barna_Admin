import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A teacher as the class form needs them: a name to show and the document
/// id to store.
///
/// The form used to work in bare names, so nothing could record *which*
/// teacher was picked — and the student app needs the id to mark who is
/// teaching in the live room's chat and people list.
class LiveClassTeacher {
  final String id;
  final String name;
  final String phoneNumber;
  const LiveClassTeacher(
      {required this.id, required this.name, this.phoneNumber = ""});
}

/// A subject as the class form needs it: the name shown on the student's
/// class card, and the code stored alongside it.
class LiveClassSubject {
  final String code;
  final String name;
  const LiveClassSubject({required this.code, required this.name});
}

class LiveClassRepo {
  final FirebaseFirestore _fireStore;

  LiveClassRepo({FirebaseFirestore? firestore})
      : _fireStore = firestore ?? FirebaseFirestore.instance;

  /// Adds the doc with server-stamped `createdAt`/`updatedAt` so ordering
  /// can't be skewed by a wrong clock on the admin's machine.
  /// Returns void rather than the new DocumentReference: no caller wants
  /// the reference, and handing back a sealed Firestore type forces every
  /// test that stubs this method to fake one.
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
  /// Beyond a plain [updateLiveClass] it also deletes the four superseded
  /// keys. `update()` merges, so without this the document would carry both
  /// spellings of every field forever — and the next person reading it would
  /// have no way to tell which one is authoritative.
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

  Future<void> deleteLiveClass(String docId) async {
    await _fireStore.collection(liveClasses).doc(docId).delete();
  }

  /// Newest-scheduled first. The whole collection is fetched in one go (no
  /// paging) — same shape as the Teacher module, and appropriate while a
  /// class list stays in the tens/low hundreds.
  ///
  /// Sorted here rather than with `orderBy`. A Firestore `orderBy` silently
  /// drops every document missing the field, so ordering on `startTime`
  /// would have hidden every class saved before the schema was aligned —
  /// exactly the documents an admin needs to find in order to re-save them.
  Future<List<LiveClassModel>> getLiveClassList() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fireStore.collection(liveClasses).get();
    final List<LiveClassModel> classes = snapshot.docs
        .map((docSnapshot) => LiveClassModel.fromDocumentSnapshot(docSnapshot))
        .toList();
    classes.sort((a, b) => b.startDateTime.compareTo(a.startDateTime));
    return classes;
  }

  /// The Teacher dropdown on the add/edit form, read straight from the
  /// `teacher` collection (same cross-collection read VideoRepo does for
  /// subjects). Sorted case-insensitively; blanks dropped.
  Future<List<LiveClassTeacher>> getTeachers() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fireStore.collection(teacher).get();
    final List<LiveClassTeacher> teachers = snapshot.docs
        .map((doc) => LiveClassTeacher(
            id: doc.id,
            name: (doc.data()["name"] ?? "").toString().trim(),
            phoneNumber:
                (doc.data()["phone_number"] ?? "").toString().trim()))
        .where((t) => t.name.isNotEmpty && t.name != stringDefault)
        .toList();
    teachers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return teachers;
  }

  /// The Subject dropdown on the add/edit form. The app prints the subject's
  /// name on every class card, so a class saved without one shows a blank
  /// line where the subject belongs.
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
    subjects.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return subjects;
  }
}
