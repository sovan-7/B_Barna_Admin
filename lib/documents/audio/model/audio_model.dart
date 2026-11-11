import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One audio item in the `audio` collection; topics attach it by its
/// code.
class AudioModel {
  /// Firestore document id (not stored inside the document).
  String docId = stringDefault;

  /// Audio code, stored upper-case (`audio_code`).
  String code = stringDefault;

  /// Creation time in epoch milliseconds (`timeStamp`); lists sort newest
  /// first on it.
  int timeStamp = intDefault;

  /// Display title (`audio_title`).
  String title = stringDefault;

  /// Free-text description (`audio_description`).
  String description = stringDefault;

  /// Download URL of the uploaded clip (`audio_link`).
  String link = stringDefault;

  /// "FREE" or "PAID" (`audio_type`).
  String audioType = stringDefault;

  /// Creates a audio item from the Add/Edit form values.
  AudioModel(
    this.code,
    this.description,
    this.title,
    this.link,
    this.audioType,
    this.timeStamp,
  );

  /// Converts this model to the Firestore document map (field names as
  /// stored in the collection).
  Map<String, dynamic> toMap() {
    return {
      "audio_code": code.trim(),
      "audio_description": description,
      "audio_title": title,
      "timeStamp": timeStamp,
      "audio_link": link,
      "audio_type": audioType,
    };
  }

  /// Reads a Firestore document; missing fields fall back to the
  /// `*Default` placeholders from `constant.dart`.
  AudioModel.fromDocumentSnapshot(DocumentSnapshot<Map<String, dynamic>> doc)
      : docId = doc.id,
        code = doc.data()!["audio_code"] ?? stringDefault,
        description = doc.data()!["audio_description"] ?? stringDefault,
        title = doc.data()!["audio_title"] ?? stringDefault,
        link = _link(doc.data()!),
        audioType = doc.data()!["audio_type"] ?? stringDefault,
        timeStamp = doc.data()!["timeStamp"] ?? intDefault;

  /// `audio_link`, or — for clips uploaded while the upload wrongly saved
  /// the URL as `pdf_link` — that field instead. The next save of such a
  /// clip writes it back as `audio_link`.
  static String _link(Map<String, dynamic> data) {
    final String? link = data["audio_link"] as String?;
    if (link != null && link.trim().isNotEmpty && link != stringDefault) {
      return link;
    }
    return data["pdf_link"] as String? ?? link ?? stringDefault;
  }
}
