import 'dart:typed_data';

import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  /// The subject's `course_type` ("Full Course", "Part Course", ...).
  final String courseType;
  const LiveClassSubject(
      {required this.code,
      required this.name,
      this.courseType = courseTypeFullCourse});
}

/// Firestore / Storage access for live classes, plus the teacher / subject
/// lookups the class form's dropdowns need. Firestore and Storage are
/// injectable for tests.
///
/// Every method throws on failure; [LiveClassViewModel] catches and
/// reports.
class LiveClassRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore;

  /// Storage client passed in by a test; null means the real one.
  final FirebaseStorage? _storageOverride;

  LiveClassRepo({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _fireStore = firestore ?? FirebaseFirestore.instance,
        _storageOverride = storage;

  /// Storage client, looked up only when a PDF is uploaded or deleted.
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Where class [docId]'s notes PDF is stored. One fixed path per class,
  /// so a class can only ever have one file: uploading again overwrites it,
  /// and deleting the class finds it without knowing its URL.
  Reference classPdfRef(String docId) =>
      _storage.ref().child("live_class_pdf").child("pdf_$docId");

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

  /// Deletes the class document, then its notes PDF (if it has one).
  ///
  /// The PDF goes only here — deleting the chat leaves it alone. A failure
  /// to remove the file (most often: the class never had one) is ignored,
  /// since the class itself is already gone.
  Future<void> deleteLiveClass(String docId) async {
    await _fireStore.collection(liveClasses).doc(docId).delete();
    try {
      await classPdfRef(docId).delete();
    } catch (_) {
      // No PDF was uploaded, or it is already gone.
    }
  }

  /// Uploads [bytes] as class [docId]'s notes PDF, replacing any earlier
  /// one, and stores its download URL and [fileName] on the class as
  /// `pdfLink` / `pdfName`. Returns the download URL.
  ///
  /// A replaced file gets a new download token, so the URL changes and the
  /// student app's URL-keyed PDF cache fetches the new file.
  Future<String> uploadClassPdf(
      String docId, Uint8List bytes, String fileName) async {
    final String url = await uploadToStorage(classPdfRef(docId), bytes,
        contentType: "application/pdf");
    await _fireStore.collection(liveClasses).doc(docId).update({
      "pdfLink": url,
      "pdfName": fileName.trim(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
    return url;
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

  /// Asks for the class's chat to be deleted. The panel has no Firebase Auth,
  /// so it cannot touch the Realtime Database itself: the
  /// `deleteLiveClassChat` Cloud Function (b_barna_app/functions) sees this
  /// stamp, removes `live_rooms/{docId}/messages`, then stamps
  /// `chatDeletedAt` and clears this field.
  Future<void> requestChatDelete(String docId) async {
    await _fireStore.collection(liveClasses).doc(docId).update({
      "chatDeleteRequestedAt": FieldValue.serverTimestamp(),
    });
  }

  /// True for a subject the student app gives live classes to: a full
  /// course. Compared the way the app does (trimmed, any casing).
  static bool isFullCourse(String courseType) =>
      courseType.trim().toLowerCase() ==
      courseTypeFullCourse.toLowerCase();

  /// Options for the Subject dropdown: the Full Course subjects of the
  /// `subject` collection, since only those show live classes in the app.
  /// Filtered in memory so odd casing in `course_type` is still matched.
  /// Sorted case-insensitively; blank / default names are dropped.
  Future<List<LiveClassSubject>> getSubjects() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _fireStore.collection(subject).get();
    final List<LiveClassSubject> subjects = snapshot.docs
        .map((doc) => LiveClassSubject(
              code: (doc.data()["subject_code"] ?? "").toString().trim(),
              name: (doc.data()["subject_name"] ?? "").toString().trim(),
              courseType: (doc.data()["course_type"] ?? "").toString(),
            ))
        .where((s) =>
            s.name.isNotEmpty &&
            s.name != stringDefault &&
            isFullCourse(s.courseType))
        .toList();
    subjects
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return subjects;
  }
}
