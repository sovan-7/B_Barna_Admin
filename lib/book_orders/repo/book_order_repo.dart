import 'package:bbarna/book_orders/model/book_order_model.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access for the `book_orders` collection. Orders are created
/// by the student app after payment; the admin panel reads them and
/// changes their status.
///
/// Every method throws on failure; [BookOrderViewModel] catches and
/// reports.
class BookOrderRepo {
  /// Firestore client.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Most orders loaded at once (newest first).
  static const int pageSize = 300;

  /// The `book_orders` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(bookOrders);

  /// The newest [pageSize] orders, newest first.
  Future<List<BookOrderModel>> getOrders() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
        .orderBy("created_at", descending: true)
        .limit(pageSize)
        .get();
    return snapshot.docs
        .map((docSnapshot) => BookOrderModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Sets only the order's `status` (and when it was changed).
  Future<void> setStatus(String docId, String status) async {
    await _collection.doc(docId).update({
      "status": status,
      "status_updated_at": FieldValue.serverTimestamp(),
    });
  }
}
