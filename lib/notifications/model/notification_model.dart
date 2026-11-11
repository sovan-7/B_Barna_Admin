import 'package:cloud_firestore/cloud_firestore.dart';

/// Where a notification is in its life: queued by the panel, then sent (or
/// not) by the `sendAdminNotification` Cloud Function.
enum NotificationStatus {
  /// Written by the panel; the Cloud Function has not finished with it.
  pending,

  /// Handed to Firebase Cloud Messaging for every app user.
  sent,

  /// The Cloud Function could not send it ([NotificationModel.error] says
  /// why).
  failed;

  /// The stored value -> status. Anything unknown counts as [pending].
  static NotificationStatus fromName(Object? name) {
    for (final NotificationStatus status in values) {
      if (status.name == name) return status;
    }
    return pending;
  }
}

/// One push notification sent from the panel (`notifications` collection).
///
/// The panel only ever creates these with [NotificationStatus.pending]; the
/// Cloud Function sends it to the `all_users` topic and fills in
/// `status`, `sent_at`, `message_id` and `error`.
class NotificationModel {
  /// Firestore document id (not stored inside the document).
  final String docId;

  /// Bold first line on the phone (`title`).
  final String title;

  /// Text under the title; may be empty (`body`).
  final String body;

  /// Download URL of the picture, or null for a text-only one
  /// (`image_url`).
  final String? imageUrl;

  /// See [NotificationStatus] (`status`).
  final NotificationStatus status;

  /// Why sending failed (`error`), when [status] is failed.
  final String? error;

  /// When the panel queued it (`created_at`). Null for a moment right after
  /// writing, before the server timestamp comes back.
  final DateTime? createdAt;

  /// When it was sent (`sent_at`).
  final DateTime? sentAt;

  /// Teacher document id of whoever sent it (`created_by`).
  final String? createdBy;

  const NotificationModel({
    required this.title,
    required this.body,
    this.imageUrl,
    this.docId = "",
    this.status = NotificationStatus.pending,
    this.error,
    this.createdAt,
    this.sentAt,
    this.createdBy,
  });

  /// Whether a picture goes with it.
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// The document the panel writes. `created_at` is set by the repo (it
  /// needs the server's clock).
  Map<String, dynamic> toMap() {
    return {
      "title": title,
      "body": body,
      "image_url": hasImage ? imageUrl : null,
      "status": status.name,
      "created_by": createdBy,
    };
  }

  /// Reads a Firestore document; missing fields fall back to empty.
  factory NotificationModel.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? const {};
    return NotificationModel(
      docId: doc.id,
      title: data["title"] as String? ?? "",
      body: data["body"] as String? ?? "",
      imageUrl: data["image_url"] as String?,
      status: NotificationStatus.fromName(data["status"]),
      error: data["error"] as String?,
      createdAt: _date(data["created_at"]),
      sentAt: _date(data["sent_at"]),
      createdBy: data["created_by"] as String?,
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
