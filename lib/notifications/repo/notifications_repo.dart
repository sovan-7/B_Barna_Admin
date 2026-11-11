import 'dart:typed_data';

import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/image_sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `notifications` collection.
///
/// Writing a document is what sends a notification: the
/// `sendAdminNotification` Cloud Function (b_barna_app/functions) picks up
/// every new pending document and sends it to all app users.
///
/// Every method throws on failure; [NotificationsViewModel] catches and
/// reports.
class NotificationsRepo {
  /// Firestore client.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; pictures go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// How many past notifications the history shows.
  static const int historyLimit = 50;

  /// The `notifications` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(notifications);

  /// Queues [notification] for sending and returns the new document's id.
  Future<String> send(NotificationModel notification) async {
    final DocumentReference<Map<String, dynamic>> doc = await _collection.add({
      ...notification.toMap(),
      "status": NotificationStatus.pending.name,
      "created_at": FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// The most recent notifications, newest first.
  Future<List<NotificationModel>> getNotifications() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
        .orderBy("created_at", descending: true)
        .limit(historyLimit)
        .get();
    return snapshot.docs.map(NotificationModel.fromDocumentSnapshot).toList();
  }

  /// Shrinks and uploads [image] to `notifications/<timestamp>_img` and
  /// returns its download URL.
  Future<String> uploadImage(Uint8List image) async {
    final int timeStamp = DateTime.now().millisecondsSinceEpoch;
    return uploadImageToStorage(
      storageReference.child("notifications").child("${timeStamp}_img"),
      image,
      maxSide: ImageSizes.notification,
    );
  }

  /// Removes a notification from the history. Phones that already got it
  /// keep it.
  Future<void> delete(String docId) async {
    await _collection.doc(docId).delete();
  }
}
