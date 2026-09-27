import 'dart:typed_data';

import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `banners` collection (the images on
/// the student app's home carousel).
///
/// Every method throws on failure; [BannersViewModel] catches and reports.
class BannersRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `banners` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(banners);

  /// Adds a banner and returns the new document's id.
  Future<String> addBanner(BannersModel bannersModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(bannersModel.toMap());
    return doc.id;
  }

  /// Every banner.
  Future<List<BannersModel>> getBannersList() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _collection.get();
    return snapshot.docs
        .map((docSnapshot) => BannersModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Uploads [image] to `images/<timestamp>_img` and stores its download
  /// URL as `banner_image` on document [bannerId].
  Future<void> uploadBannerImage(Uint8List image, String bannerId) async {
    final int timeStamp = DateTime.now().millisecondsSinceEpoch;
    final String url = await uploadToStorage(
      storageReference.child("images").child("${timeStamp}_img"),
      image,
      contentType: jpegContentType,
    );
    await _collection.doc(bannerId).update({"banner_image": url});
  }

  /// Deletes the banner document.
  Future<void> deleteBanner(String bannerId) async {
    await _collection.doc(bannerId).delete();
  }
}
