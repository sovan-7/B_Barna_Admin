import 'package:cloud_firestore/cloud_firestore.dart';

/// A Firestore document as returned by a query.
typedef FirestoreDoc = QueryDocumentSnapshot<Map<String, dynamic>>;

/// Cursor-based paging over one Firestore collection, newest first.
///
/// Every paged repo (audio, PDF, video, quiz, question, unit, topic) owns
/// one of these. The cursor — a sealed Firestore [DocumentSnapshot] — stays
/// inside the repo, so view models only ever see plain models and can be
/// tested with a mocked repo.
///
/// ```dart
/// late final FirestorePager _pager = FirestorePager(_fireStore.collection(pdf));
/// Future<List<PdfModel>> getFirstPdfList(int limit) async =>
///     (await _pager.firstPage(limit)).map(PdfModel.fromDocumentSnapshot).toList();
/// ```
class FirestorePager {
  FirestorePager(this._collection, {this.orderField = "timeStamp"});

  /// The collection being paged.
  final CollectionReference<Map<String, dynamic>> _collection;

  /// Field the pages are ordered by (descending, so newest first).
  final String orderField;

  /// Last document of the most recent page; `null` before the first page or
  /// when the first page was empty.
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  /// Base query shared by both page calls.
  Query<Map<String, dynamic>> get _ordered =>
      _collection.orderBy(orderField, descending: true);

  /// Fetches the first [limit] documents and resets the cursor.
  Future<List<FirestoreDoc>> firstPage(int limit) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _ordered.limit(limit).get();
    _cursor = snapshot.docs.isEmpty ? null : snapshot.docs.last;
    return snapshot.docs;
  }

  /// Fetches the [limit] documents after the previous page. Returns an empty
  /// list when there is no cursor yet or nothing further to read.
  Future<List<FirestoreDoc>> nextPage(int limit) async {
    final DocumentSnapshot<Map<String, dynamic>>? cursor = _cursor;
    if (cursor == null) return const [];

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _ordered.startAfterDocument(cursor).limit(limit).get();
    // Only move the cursor forward when this page actually had rows.
    if (snapshot.docs.isNotEmpty) _cursor = snapshot.docs.last;
    return snapshot.docs;
  }
}

/// Number of documents in [collection], using Firestore's server-side
/// `count()` aggregate (no documents are downloaded).
Future<int> countDocuments(
    CollectionReference<Map<String, dynamic>> collection) async {
  final AggregateQuerySnapshot countSnapshot = await collection.count().get();
  return countSnapshot.count ?? 0;
}

/// Most documents one prefix search returns. Codes are short, so a one- or
/// two-letter search could otherwise read a large part of a collection.
const int searchResultLimit = 50;

/// Documents in [collection] whose [field] starts with [prefix] (at most
/// [limit], in code order).
///
/// Firestore has no "starts with", so this asks for
/// `prefix <= field < prefix + 'z'`. Run server-side because the paged
/// collections are too big to filter in memory.
Future<List<FirestoreDoc>> prefixSearch(
  CollectionReference<Map<String, dynamic>> collection,
  String field,
  String prefix, {
  int limit = searchResultLimit,
}) async {
  final QuerySnapshot<Map<String, dynamic>> snapshot = await collection
      .where(field, isGreaterThanOrEqualTo: prefix)
      .where(field, isLessThan: '${prefix}z')
      .limit(limit)
      .get();
  return snapshot.docs;
}
