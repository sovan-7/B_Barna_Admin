import 'dart:typed_data';

import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/repo/topic_repo.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// What [Topic1Repo.uploadPdfFile] stored: the download URL and the
/// Storage path it sits at.
typedef Topic1UploadedPdf = ({String url, String path});

/// Firestore / Storage access for the `topic1` collection: the topics
/// themselves, the subject/unit lookups the form's dropdowns need, the
/// audio/quiz codes, and the PDFs and videos stored on each topic.
/// Firestore and Storage are injectable for tests.
///
/// Every method throws on failure (except the deliberately quiet
/// [deletePdfFiles]); [Topic1ViewModel] catches and reports.
class Topic1Repo {
  /// Firestore client passed in by a test; null means the real one.
  final FirebaseFirestore? _fireStoreOverride;

  /// Storage client passed in by a test; null means the real one.
  final FirebaseStorage? _storageOverride;

  Topic1Repo({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _fireStoreOverride = firestore,
        _storageOverride = storage;

  /// Firestore client.
  FirebaseFirestore get _fireStore =>
      _fireStoreOverride ?? FirebaseFirestore.instance;

  /// Storage client, looked up only when a PDF is uploaded or deleted.
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// The `topic1` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(topic1);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<Topic1Model> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => Topic1Model.fromDocumentSnapshot(doc)).toList();

  /// Adds a Topic1 and returns the new document's id.
  Future<String> addTopic(Topic1Model topicModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(topicModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<Topic1Model>> getFirstTopicList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<Topic1Model>> getNextTopicList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Overwrites the topic's own fields (never its content, see
  /// [Topic1Model.toMap]).
  Future<void> updateTopic(Topic1Model topicModel, String docId) async {
    await _collection.doc(docId).update(topicModel.toMap());
  }

  /// Deletes the topic document. Its PDF files are removed separately with
  /// [deletePdfFiles].
  Future<void> deleteTopic(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Replaces the audio or quiz codes ([kind]) on topic [docId].
  Future<void> setContentCodes(
      String docId, ContentKind kind, List<String> codes) async {
    await _collection.doc(docId).update({kind.field: codes});
  }

  /// Replaces the topic's `pdf_list`.
  Future<void> setPdfList(String docId, List<Topic1Pdf> pdfs) async {
    await _collection
        .doc(docId)
        .update({"pdf_list": pdfs.map((p) => p.toMap()).toList()});
  }

  /// Replaces the topic's `video_list`.
  Future<void> setVideoList(String docId, List<Topic1Video> videos) async {
    await _collection
        .doc(docId)
        .update({"video_list": videos.map((v) => v.toMap()).toList()});
  }

  /// Uploads [bytes] as a new PDF file of topic [docId] and returns its
  /// download URL and Storage path.
  ///
  /// Every upload gets a path of its own (`topic1_pdf/<docId>/<new id>.pdf`)
  /// rather than reusing the entry's, so replacing a file never overwrites
  /// the one still saved on the topic: if saving the list then fails, the
  /// new file can be deleted and the saved one is untouched.
  Future<Topic1UploadedPdf> uploadPdfFile(String docId, Uint8List bytes) async {
    final String path = "topic1_pdf/$docId/${newTopic1ItemId()}.pdf";
    final String url = await uploadToStorage(
      _storage.ref().child(path),
      bytes,
      contentType: 'application/pdf',
    );
    return (url: url, path: path);
  }

  /// Deletes the files at [paths], ignoring blanks and failures (a file
  /// that is already gone, say): by the time this runs nothing points at
  /// them any more, so a leftover file is harmless.
  Future<void> deletePdfFiles(Iterable<String> paths) async {
    await Future.wait([
      for (final String path in paths.toSet())
        if (path.trim().isNotEmpty) _deleteQuietly(path),
    ]);
  }

  /// Deletes one file, swallowing any error.
  Future<void> _deleteQuietly(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (_) {
      // Already gone, or not ours to delete — nothing to do.
    }
  }

  /// Looks audio / quiz codes up in their own collection and returns
  /// `code -> title` (see [resolveContentTitlesIn]).
  Future<Map<String, String>> resolveContentTitles(
          ContentKind kind, List<String> codes) =>
      resolveContentTitlesIn(_fireStore, kind, codes);

  /// All subjects whose `course_code` is [courseCode] (form dropdown).
  Future<List<SubjectModel>> getSubjectList(
      {required String courseCode}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _fireStore
        .collection(subject)
        .where("course_code", isEqualTo: courseCode)
        .get();
    return snapshot.docs
        .map((docSnapshot) => SubjectModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// All units whose `subject_code` is [subjectCode] (form dropdown).
  Future<List<UnitModel>> getUnitList({required String subjectCode}) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _fireStore
        .collection(unit)
        .where("subject_code", isEqualTo: subjectCode)
        .get();
    return snapshot.docs
        .map((docSnapshot) => UnitModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Total Topic1 documents in the collection.
  Future<int> getTopicListLength() => countDocuments(_collection);

  /// Topic1 documents whose `topic_code` starts with [searchText].
  Future<List<Topic1Model>> searchTopic(String searchText) async =>
      _toModels(await prefixSearch(_collection, "topic_code", searchText));
}
