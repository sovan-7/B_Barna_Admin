import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One video item in the `video` collection; topics attach it by its
/// code.
class VideoModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Video code, stored upper-case (`video_code`).
  String code = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Display title (`video_title`).
  String title = stringDefault;

  /// Free-text description (`video_description`).
  String description = stringDefault;

  /// A link (e.g. YouTube), not an uploaded file (`video_link`).
  String link = stringDefault;

  /// "FREE" or "PAID" (`video_type`).
  String videoType = stringDefault;

  /// Creates a video item from the Add/Edit form values.
  VideoModel(
    this.code,
    this.description,
    this.title,
    this.link,
    this.videoType,
    this.timeStamp,
  );

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "video_code": code.trim(),
      "video_description": description,
      "video_title": title,
      "timeStamp": timeStamp,
      "video_link": link,
      "video_type": videoType,
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  VideoModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        code = doc.data()!["video_code"] ?? stringDefault,
        description = doc.data()!["video_description"] ?? stringDefault,
        title = doc.data()!["video_title"] ?? stringDefault,
        link = doc.data()!["video_link"] ?? stringDefault,
        videoType = doc.data()!["video_type"] ?? stringDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault;
}
