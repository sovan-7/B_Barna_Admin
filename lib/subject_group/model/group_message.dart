import 'package:cloud_firestore/cloud_firestore.dart';

/// The group's document id for a subject: its code, encoded so a "/" in a
/// code can't split the Firestore path.
///
/// Groups are kept per code, not per subject document, because the student
/// app grants access by code: a subject listed under two courses with the
/// same code is one purchase, and so one group.
String groupIdFor(String subjectCode) => Uri.encodeComponent(subjectCode);

/// One message in a subject's group
/// (`subject_groups/{groupId}/messages/{autoId}`), shown read-only in the
/// student app's Group tab.
///
/// The field names are a contract with the student app
/// (`b_barna_app/lib/subjectGroup/model/group_message.dart`): renaming one
/// here silently blanks it there.
class GroupMessage {
  /// Firestore document id (not stored inside the document).
  final String docId;

  /// The message (`text`); empty when the post is only a picture.
  final String text;

  /// Download URL of the picture (`image_url`); empty when there is none.
  final String imageUrl;

  /// The picture's size in pixels (`image_width`, `image_height`), so the
  /// app can keep its space before it loads; 0 when unknown.
  final int imageWidth;
  final int imageHeight;

  /// Teacher document id of whoever posted it (`sender_id`).
  final String senderId;

  /// Their display name when they posted (`sender_name`).
  final String senderName;

  /// `admin` or `subadmin` (`sender_role`); the app shows Admin or Teacher.
  final String senderRole;

  /// The subject's code as stored (`subject_code`), for the console.
  final String subjectCode;

  /// When the server stamped it (`created_at`); null until it has.
  final DateTime? createdAt;

  const GroupMessage({
    this.docId = "",
    required this.text,
    this.imageUrl = "",
    this.imageWidth = 0,
    this.imageHeight = 0,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.subjectCode,
    this.createdAt,
  });

  bool get hasText => text.trim().isNotEmpty;
  bool get hasImage => imageUrl.isNotEmpty;

  /// Width / height, or null when the size wasn't saved.
  double? get imageAspectRatio =>
      imageWidth > 0 && imageHeight > 0 ? imageWidth / imageHeight : null;

  /// The fields to write. `created_at` is left to the repo, which sets the
  /// server's time.
  Map<String, dynamic> toMap() {
    return {
      "text": text,
      "image_url": imageUrl,
      "image_width": imageWidth,
      "image_height": imageHeight,
      "sender_id": senderId,
      "sender_name": senderName,
      "sender_role": senderRole,
      "subject_code": subjectCode,
    };
  }

  /// Reads a stored message; missing fields read as empty.
  factory GroupMessage.fromMap(String docId, Map<String, dynamic> data) {
    String text(String key) {
      final Object? value = data[key];
      return value is String ? value : "";
    }

    int whole(String key) {
      final Object? value = data[key];
      return value is num ? value.toInt() : 0;
    }

    final Object? created = data["created_at"];
    return GroupMessage(
      docId: docId,
      text: text("text"),
      imageUrl: text("image_url").trim(),
      imageWidth: whole("image_width"),
      imageHeight: whole("image_height"),
      senderId: text("sender_id"),
      senderName: text("sender_name").trim(),
      senderRole: text("sender_role"),
      subjectCode: text("subject_code"),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
