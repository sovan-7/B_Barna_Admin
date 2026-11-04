import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// One page of purchases, and where the next one starts.
class TransactionPage {
  /// The purchases, newest first.
  final List<TransactionModel> items;

  /// Pass back to [TransactionRepo.getPage] for the next page.
  final Object? cursor;

  /// Whether older purchases may remain.
  final bool hasMore;

  const TransactionPage(this.items, this.cursor, this.hasMore);
}

/// Firestore access for the `transactions` collection. Purchases are only
/// ever created by the student app, so this class reads and never writes:
/// a payment record an admin could edit could not be trusted.
///
/// Every method throws on failure; [TransactionViewModel] catches and
/// reports.
class TransactionRepo {
  /// Firestore client.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Most purchases loaded per page.
  static const int pageSize = 300;

  /// The `transactions` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(transactions);

  /// A page of purchases, newest first, after [cursor] (null for the first).
  Future<TransactionPage> getPage({Object? cursor}) async {
    Query<Map<String, dynamic>> query =
        _collection.orderBy("created_at", descending: true).limit(pageSize);
    if (cursor != null) {
      query = query
          .startAfterDocument(cursor as DocumentSnapshot<Map<String, dynamic>>);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return TransactionPage(
      [
        for (final doc in snapshot.docs)
          TransactionModel.fromDocumentSnapshot(doc)
      ],
      snapshot.docs.isEmpty ? cursor : snapshot.docs.last,
      snapshot.docs.length == pageSize,
    );
  }

  /// How many purchases the collection holds.
  Future<int> getTotalCount() async {
    final AggregateQuerySnapshot snapshot = await _collection.count().get();
    return snapshot.count ?? 0;
  }
}
