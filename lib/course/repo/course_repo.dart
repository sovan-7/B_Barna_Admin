import 'dart:typed_data';

import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/image_sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `course` collection. Courses are few,
/// so the whole collection is loaded at once (no paging).
///
/// Every method throws on failure; [CourseViewModel] catches and reports.
class CourseRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; uploads go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `course` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(course);

  /// Adds a course and returns the new document's id.
  Future<String> addCourse(CourseModel courseModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(courseModel.toMap());
    return doc.id;
  }

  /// Every course, in Firestore's default order (the view model sorts).
  Future<List<CourseModel>> getCourseList() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _collection.get();
    return snapshot.docs
        .map((docSnapshot) => CourseModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Shrinks and uploads [image] to `images/img_<courseId>` and stores its download URL
  /// as `course_image`. Keyed by document id because course codes are not
  /// unique.
  Future<void> uploadCourseImage(Uint8List image, String courseId) async {
    final String url = await uploadImageToStorage(
      storageReference.child("images").child("img_$courseId"),
      image,
      maxSide: ImageSizes.thumbnail,
    );
    await _collection.doc(courseId).update({"course_image": url});
  }

  /// Overwrites the course's fields.
  Future<void> updateCourse(CourseModel courseModel, String docId) async {
    await _collection.doc(docId).update(courseModel.toMap());
  }

  /// Sets only the `isLocked` flag.
  Future<void> setCourseLocked(String docId, bool isLocked) async {
    await _collection.doc(docId).update({"isLocked": isLocked});
  }

  /// Deletes the course document.
  Future<void> deleteCourse(String docId) async {
    await _collection.doc(docId).delete();
  }
}
