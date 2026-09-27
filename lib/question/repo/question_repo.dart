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
