import 'dart:typed_data';

import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/utils/image_sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `unit` collection, plus the subject
/// lookup the unit form's "Subject" dropdown needs.
///
/// Every method throws on failure; [UnitViewModel] catches and reports.
class UnitRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; uploads go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `unit` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(unit);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<UnitModel> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => UnitModel.fromDocumentSnapshot(doc)).toList();

  /// Adds a unit and returns the new document's id.
  Future<String> addUnit(UnitModel unitModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(unitModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<UnitModel>> getFirstUnitList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<UnitModel>> getNextUnitList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Shrinks and uploads [image] to `images/img_unit_<unitId>` and stores its download
  /// URL as `unit_image`. Keyed by document id because unit codes are not
  /// unique across subjects.
  Future<void> uploadUnitImage(Uint8List image, String unitId) async {
    final String url = await uploadImageToStorage(
      storageReference.child("images").child("img_unit_$unitId"),
      image,
      maxSide: ImageSizes.thumbnail,
    );
    await _collection.doc(unitId).update({"unit_image": url});
  }

  /// Overwrites the unit's fields.
  Future<void> updateUnit(UnitModel unitModel, String unitId) async {
    await _collection.doc(unitId).update(unitModel.toMap());
  }

  /// Sets one boolean [field] (e.g. `lock_status`) on a unit.
  Future<void> setUnitFlag(String unitId, String field, bool value) async {
    await _collection.doc(unitId).update({field: value});
  }

  /// Deletes the unit document.
  Future<void> deleteUnit(String unitId) async {
    await _collection.doc(unitId).delete();
  }

  /// All subjects whose `course_code` is [courseCode].
  Future<List<SubjectModel>> getSubjectListByCourseCode(
      String courseCode) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _fireStore
        .collection(subject)
        .where("course_code", isEqualTo: courseCode)
        .get();
    return snapshot.docs
        .map((docSnapshot) => SubjectModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Total units in the collection.
  Future<int> getUnitListLength() => countDocuments(_collection);

  /// Units whose `unit_code` starts with [searchText].
  Future<List<UnitModel>> searchUnit(String searchText) async =>
      _toModels(await prefixSearch(_collection, "unit_code", searchText));
}
