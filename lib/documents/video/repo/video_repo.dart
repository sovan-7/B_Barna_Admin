import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access for the `video` collection. Videos are links, so
/// nothing is uploaded to Storage.
///
/// Every method throws on failure; [VideoViewModel] catches and reports.
class VideoRepo {
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// The `video` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(video);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<VideoModel> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => VideoModel.fromDocumentSnapshot(doc)).toList();

  /// Adds a video and returns the new document's id.
  Future<String> addVideo(VideoModel videoModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(videoModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<VideoModel>> getFirstVideoList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<VideoModel>> getNextVideoList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Overwrites the video's fields.
  Future<void> updateVideo(VideoModel videoModel, String docId) async {
    await _collection.doc(docId).update(videoModel.toMap());
  }

  /// Deletes the video document.
  Future<void> deleteVideo(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Total videos in the collection.
  Future<int> getVideoListLength() => countDocuments(_collection);

  /// Videos whose `video_code` starts with [searchText].
  Future<List<VideoModel>> searchVideo(String searchText) async =>
      _toModels(await prefixSearch(_collection, "video_code", searchText));
}
