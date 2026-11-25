import 'dart:typed_data';

import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject_group/model/group_message.dart';
import 'package:bbarna/utils/image_sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for subject groups
/// (`subject_groups/{groupId}/messages`).
///
/// Every method throws on failure; [SubjectGroupViewModel] catches and
/// reports.
class SubjectGroupRepo {
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;

  /// Tests pass their own Firestore / Storage (or mock the whole repo).
  SubjectGroupRepo({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestoreOverride = firestore,
        _storageOverride = storage;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _firestore
          .collection(subjectGroups)
          .doc(groupId)
          .collection(groupMessages);

  /// The newest [limit] messages of [groupId], newest first, again every
  /// time one is added, changed or deleted.
  Stream<List<GroupMessage>> watch(String groupId, {required int limit}) {
    return _messages(groupId)
        .orderBy("created_at", descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupMessage.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Posts [message] to [groupId], stamped with the server's time, and
  /// returns the new document's id.
  Future<String> send(String groupId, GroupMessage message) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _messages(groupId).add({
      ...message.toMap(),
      "created_at": FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Shrinks and uploads a picture for [subjectCode]'s group to
  /// `images/group_<code>_<timestamp>` (beside the subject pictures), and
  /// returns its URL and size.
  Future<UploadedImage> uploadImage(String subjectCode, Uint8List image) {
    final String safeCode =
        subjectCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), "_");
    final int timeStamp = DateTime.now().millisecondsSinceEpoch;
    return uploadSizedImage(
      _storage.ref().child("images").child("group_${safeCode}_$timeStamp"),
      image,
      maxSide: ImageSizes.groupPost,
    );
  }

  /// Deletes [message] from [groupId]; students stop seeing it at once. Its
  /// picture is removed too when possible (a file left behind costs little
  /// and is never shown again).
  Future<void> delete(String groupId, GroupMessage message) async {
    await _messages(groupId).doc(message.docId).delete();
    if (message.imageUrl.isNotEmpty) await _deletePicture(message.imageUrl);
  }

  /// How many messages one round of [deleteAll] removes (a batch holds at
  /// most 500 writes).
  static const int deleteBatchSize = 300;

  /// Deletes every message in [groupId], with their pictures, and returns
  /// how many messages went. Firestore can't delete a collection in one go,
  /// so this takes them [deleteBatchSize] at a time until none are left.
  /// If it fails part-way, what was deleted stays deleted.
  Future<int> deleteAll(String groupId) async {
    int deleted = 0;
    while (true) {
      final QuerySnapshot<Map<String, dynamic>> page =
          await _messages(groupId).limit(deleteBatchSize).get();
      if (page.docs.isEmpty) return deleted;

      final WriteBatch batch = _firestore.batch();
      final List<String> pictures = [];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in page.docs) {
        batch.delete(doc.reference);
        final Object? url = doc.data()["image_url"];
        if (url is String && url.trim().isNotEmpty) pictures.add(url.trim());
      }
      await batch.commit();
      deleted += page.docs.length;
      await Future.wait(pictures.map(_deletePicture));
    }
  }

  /// Removes an uploaded picture, when possible.
  Future<void> _deletePicture(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Already gone, or not ours to delete: the message itself is gone.
    }
  }

  /// The display name of teacher [adminId], or null when it has none.
  Future<String?> teacherName(String adminId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _firestore.collection(teacher).doc(adminId).get();
    final Object? name = doc.data()?["name"];
    if (name is! String || name.trim().isEmpty || name == stringDefault) {
      return null;
    }
    return name.trim();
  }
}
