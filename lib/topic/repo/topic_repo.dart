import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access for the `topic` collection, the subject/unit lookups
/// the topic form's dropdowns need, and the topic's attached content.
///
/// Every method throws on failure; [TopicViewModel] catches and reports.
class TopicRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// The `topic` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(topic);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<TopicModel> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => TopicModel.fromDocumentSnapshot(doc)).toList();

  /// Adds a topic and returns the new document's id.
  Future<String> addTopic(TopicModel topicModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(topicModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<TopicModel>> getFirstTopicList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<TopicModel>> getNextTopicList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Overwrites the topic's fields.
  Future<void> updateTopic(TopicModel topicModel, String docId) async {
    await _collection.doc(docId).update(topicModel.toMap());
  }

  /// Deletes the topic document.
  Future<void> deleteTopic(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Replaces one content array ([kind]: videos, PDFs, audio, quizzes) on
  /// topic [docId].
  Future<void> setContentCodes(
      String docId, ContentKind kind, List<String> codes) async {
    await _collection.doc(docId).update({kind.field: codes});
  }

  /// Looks the codes up in their own collection and returns
  /// `code -> title`. A code with no document simply does not come back, so
  /// the caller can tell attached-and-real from attached-and-a-typo.
  ///
  /// `whereIn` takes at most 30 values per query, so this goes in chunks
  /// of 30. Blank and duplicate codes are ignored.
  Future<Map<String, String>> resolveContentTitles(
      ContentKind kind, List<String> codes) async {
    final List<String> unique =
        codes.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return <String, String>{};

    final Map<String, String> titles = <String, String>{};
    for (int i = 0; i < unique.length; i += 30) {
      final List<String> chunk =
          unique.sublist(i, i + 30 > unique.length ? unique.length : i + 30);
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _fireStore
          .collection(kind.collection)
          .where(kind.codeField, whereIn: chunk)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Object? code = doc.data()[kind.codeField];
        final Object? title = doc.data()[kind.titleField];
        if (code is String) titles[code] = title is String ? title : "";
      }
    }
    return titles;
  }

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

  /// Total topics in the collection.
  Future<int> getTopicListLength() => countDocuments(_collection);

  /// Topics whose `topic_code` starts with [searchText].
  Future<List<TopicModel>> searchTopic(String searchText) async =>
      _toModels(await prefixSearch(_collection, "topic_code", searchText));
}
