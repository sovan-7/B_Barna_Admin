import 'package:bbarna/question1/model/question1.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One page of results plus the raw docs needed as pagination cursors —
/// makes the Firestore-cursor coupling explicit at the repo boundary instead
/// of leaking `DocumentSnapshot`s through the ViewModel/UI as a side list.
class Question1Page {
  Question1Page({required this.items, required this.docs});
  final List<Question1> items;
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;
}

/// Single source of truth for all `question` collection access used by the
/// Question1 module — every Firestore call for this feature goes through
/// here, so the collection name/schema is never duplicated across screens.
class Question1Repo {
  Question1Repo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(question);

  Future<void> addQuestion(Question1 question) =>
      _collection.add(question.toMap());

  Future<void> updateQuestion(String docId, Question1 question) =>
      _collection.doc(docId).update(question.toMap());

  Future<void> deleteQuestion(String docId) => _collection.doc(docId).delete();

  Future<int> getQuestionCount() async {
    final snapshot = await _collection.count().get();
    return snapshot.count ?? 0;
  }

  /// Fetches one page ordered by newest first. Pass [startAfter] (a doc from
  /// a previously fetched page) to page forward or backward — the caller
  /// (the ViewModel) is responsible for tracking which cursor to re-query
  /// with, so every page — including "previous" — is a real Firestore query
  /// rather than a truncation of an in-memory list.
  Future<Question1Page> getPage({
    required int limit,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query =
        _collection.orderBy("timeStamp", descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snapshot = await query.get();
    return Question1Page(
      items: snapshot.docs
          .map((doc) => Question1.fromDocumentSnapshot(doc))
          .toList(),
      docs: snapshot.docs,
    );
  }

  Future<List<Question1>> searchByCode(String prefix) async {
    final snapshot = await _collection
        .where("question_code", isGreaterThanOrEqualTo: prefix)
        .where("question_code", isLessThan: '${prefix}z')
        .get();
    return snapshot.docs
        .map((doc) => Question1.fromDocumentSnapshot(doc))
        .toList();
  }
}
