import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One home-carousel banner (`banners` collection).
class BannersModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Download URL of the banner image (`banner_image`).
  String bannerImage = stringDefault;

  /// Creates a banner; the image URL is filled in after upload.
  BannersModel({required this.bannerImage});

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "banner_image": bannerImage,
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  BannersModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        bannerImage = doc.data()!["banner_image"] ?? stringDefault;
}
