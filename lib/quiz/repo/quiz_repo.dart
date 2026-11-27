import 'package:bbarna/core/repo/firestore_pager.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access for the `quiz` collection, plus the `question` lookups
/// the quiz form's question picker needs.
///
/// Every method throws on failure; [QuizViewModel] catches and reports.
class QuizRepo {
  /// Firestore client.
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

  /// The `quiz` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _fireStore.collection(quiz);

  /// The `question` collection (read-only here).
  CollectionReference<Map<String, dynamic>> get _questions =>
      _fireStore.collection(question);

  /// Newest-first paging with the cursor kept here, not in the view model.
  late final FirestorePager _pager = FirestorePager(_collection);

  /// Converts raw quiz documents into models.
  List<QuizModel> _toModels(List<FirestoreDoc> docs) =>
      docs.map((doc) => QuizModel.fromDocumentSnapshot(doc)).toList();

  /// Converts raw question documents into models.
  List<Question> _toQuestions(Iterable<FirestoreDoc> docs) =>
      docs.map((doc) => Question.fromDocumentSnapshot(doc)).toList();

  // ---- Quizzes -------------------------------------------------------------

  /// Adds a quiz and returns the new document's id.
  Future<String> addQuiz(QuizModel quizModel) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(quizModel.toMap());
    return doc.id;
  }

  /// First page, newest first. Resets the paging cursor.
  Future<List<QuizModel>> getFirstQuizList(int limit) async =>
      _toModels(await _pager.firstPage(limit));

  /// The page after the last one returned (empty when there is none).
  Future<List<QuizModel>> getNextQuizList(int limit) async =>
      _toModels(await _pager.nextPage(limit));

  /// Overwrites the quiz's fields.
  Future<void> updateQuiz(QuizModel quizModel, String docId) async {
    await _collection.doc(docId).update(quizModel.toMap());
  }

  /// Deletes the quiz document.
  Future<void> deleteQuiz(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// Ids of the quizzes whose `quiz_code` is exactly [code].
  Future<List<String>> quizIdsWithCode(String code) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _collection.where("quiz_code", isEqualTo: code).get();
    return [for (final doc in snapshot.docs) doc.id];
  }

  /// Total quizzes in the collection.
  Future<int> getQuizListLength() => countDocuments(_collection);

  /// Live / upcoming / pending counts for the tiles above the list, as
  /// students see them: an upcoming quiz whose opening time has passed
  /// counts as live. Upcoming quizzes are few, so they are read and judged
  /// here rather than with a range query that would need its own index.
  Future<Map<String, int>> getQuizStats({DateTime? now}) async {
    final DateTime at = now ?? DateTime.now();
    final List<Object> results = await Future.wait<Object>([
      countQuery(
          _collection.where("quiz_status", isEqualTo: QuizModel.statusLive)),
      countQuery(_collection.where("quiz_status", isEqualTo: "PENDING")),
      _collection
          .where("quiz_status", isEqualTo: QuizModel.statusUpcoming)
          .get(),
    ]);
    int opened = 0;
    int upcoming = 0;
    for (final QuizModel quiz in _toModels(
        (results[2] as QuerySnapshot<Map<String, dynamic>>).docs)) {
      if (quiz.statusAt(at) == QuizModel.statusLive) {
        opened++;
      } else {
        upcoming++;
      }
    }
    return {
      "live": (results[0] as int) + opened,
      "upcoming": upcoming,
      "pending": results[1] as int,
    };
  }

  /// Quizzes whose `quiz_code` starts with [searchText].
  Future<List<QuizModel>> searchQuiz(String searchText) async =>
      _toModels(await prefixSearch(_collection, "quiz_code", searchText));

  // ---- Questions (for the picker) -----------------------------------------

  /// Questions whose `question_code` starts with [questionCode].
  Future<List<Question>> searchQuestions(String questionCode) async =>
      _toQuestions(
          await prefixSearch(_questions, "question_code", questionCode));

  /// The questions named by [codes].
  ///
  /// Firestore's `whereIn` accepts at most 30 values, so the codes are
  /// queried in chunks of 25 and the results concatenated.
  Future<List<Question>> getQuestionsByCodes(List<String> codes) async {
    const int chunkSize = 25;
    final List<List<String>> chunks = [
      for (int i = 0; i < codes.length; i += chunkSize)
        codes.sublist(
            i, i + chunkSize > codes.length ? codes.length : i + chunkSize),
    ];

    // The chunks are independent, so query them all at once; results are
    // concatenated in chunk order.
    final List<QuerySnapshot<Map<String, dynamic>>> snapshots =
        await Future.wait([
      for (final List<String> chunk in chunks)
        _questions.where("question_code", whereIn: chunk).get(),
    ]);
    return [
      for (final QuerySnapshot<Map<String, dynamic>> snapshot in snapshots)
        ..._toQuestions(snapshot.docs),
    ];
  }
}
