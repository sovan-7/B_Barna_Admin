import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access for the `question` collection.
///
/// Every method throws on failure; [QuestionViewModel] catches and reports.
class QuestionRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// The `question` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(question);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw documents into models.
  List<Question> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => Question.fromDocumentSnapshot(doc)).toList();

  /// First page, newest first. Resets the paging cursor.
  Future<List<Question>> getFirstQuestionList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<Question>> getNextQuestionList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Adds a question from a raw map and returns the new document's id.
  Future<String> addQuestion(Map<String, dynamic> data) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(data);
    return doc.id;
  }

  /// Most writes one batch commits (Firestore allows 500).
  static const int batchSize = 450;

  /// Adds every map in [maps] as a new question, [batchSize] per batch.
  ///
  /// Each batch lands whole or not at all. [onProgress] gets the number
  /// written so far after every batch; if a batch fails, the ones before it
  /// stay written and the error is rethrown.
  Future<void> addQuestions(List<Map<String, dynamic>> maps,
      {void Function(int written)? onProgress}) async {
    for (int start = 0; start < maps.length; start += batchSize) {
      final int end =
          start + batchSize > maps.length ? maps.length : start + batchSize;
      final WriteBatch batch = _fireStore.batch();
      for (final Map<String, dynamic> data in maps.sublist(start, end)) {
        batch.set(_collection.doc(), data);
      }
      await batch.commit();
      onProgress?.call(end);
    }
  }

  /// Which of [codes] some question already uses.
  ///
  /// Firestore's `whereIn` accepts at most 30 values, so the codes are
  /// queried in chunks of 25 (as in `QuizRepo.getQuestionsByCodes`).
  Future<Set<String>> existingCodes(List<String> codes) async {
    const int chunkSize = 25;
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait([
      for (int i = 0; i < codes.length; i += chunkSize)
        _collection
            .where("question_code",
                whereIn: codes.sublist(
                    i,
                    i + chunkSize > codes.length
                        ? codes.length
                        : i + chunkSize))
            .get(),
    ]);
    return {
      for (final QuerySnapshot<Map<String, dynamic>> snapshot in snapshots)
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs)
          doc.data()["question_code"] as String? ?? "",
    }..remove("");
  }

  /// Overwrites question [docId] with [data].
  Future<void> updateQuestion(String docId, Map<String, dynamic> data) async {
    await _collection.doc(docId).update(data);
  }

  /// Deletes the question document.
  Future<void> deleteQuestion(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Total questions in the collection.
  Future<int> getQuestionListLength() => countDocuments(_collection);

  /// Questions whose `question_code` starts with [searchText].
  Future<List<Question>> searchQuestion(String searchText) async =>
      _toModels(await prefixSearch(_collection, "question_code", searchText));
}
