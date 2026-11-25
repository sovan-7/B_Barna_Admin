import 'dart:typed_data';

import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/utils/image_sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `subject` collection. The whole
/// collection is loaded at once (no paging).
///
/// Every method throws on failure; [SubjectViewModel] catches and reports.
class SubjectRepo {
  /// Firestore client.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; uploads go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `subject` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(subject);

  /// Adds a subject and returns the new document's id.
  Future<String> addSubject(SubjectModel subjectModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(subjectModel.toMap());
    return doc.id;
  }

  /// Every subject, in Firestore's default order (the view model sorts).
  Future<List<SubjectModel>> getSubjectList() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _collection.get();
    return snapshot.docs
        .map((docSnapshot) => SubjectModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Shrinks and uploads [image] to `images/img_<subjectId>` and stores its download
  /// URL as `subject_image`. Keyed by document id because subject codes are
  /// not unique across courses.
  Future<void> uploadSubjectImage(Uint8List image, String subjectId) async {
    final String url = await uploadImageToStorage(
      storageReference.child("images").child("img_$subjectId"),
      image,
      maxSide: ImageSizes.thumbnail,
    );
    await _collection.doc(subjectId).update({"subject_image": url});
  }

  /// Overwrites the subject's fields.
  Future<void> updateSubject(
      SubjectModel subjectModel, String subjectId) async {
    await _collection.doc(subjectId).update(subjectModel.toMap());
  }

  /// Sets one boolean [field] (`isLocked`, `isPopular`) on a subject.
  Future<void> setSubjectFlag(
      String subjectId, String field, bool value) async {
    await _collection.doc(subjectId).update({field: value});
  }

  /// Deletes the subject document.
  Future<void> deleteSubject(String subjectId) async {
    await _collection.doc(subjectId).delete();
  }
}
