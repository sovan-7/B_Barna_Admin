import 'package:cloud_firestore/cloud_firestore.dart';

/// The values a book order's `status` can hold. Shared with the student
/// app (`b_barna_app/lib/books/model/book_order_model.dart`).
class BookOrderStatus {
  const BookOrderStatus._();

  static const String placed = "placed";
  static const String shipped = "shipped";
  static const String delivered = "delivered";
  static const String cancelled = "cancelled";

  /// Every status, in the order an order normally moves through them.
  static const List<String> all = [placed, shipped, delivered, cancelled];

  /// Human label for [status].
  static String label(String status) {
    switch (status) {
      case shipped:
        return "Shipped";
      case delivered:
        return "Delivered";
      case cancelled:
        return "Cancelled";
      default:
        return "New order";
    }
  }
}

/// One line of an order: a book and how many copies.
class BookOrderItem {
  /// Title as it was when ordered (`name`).
  final String name;

  /// Cover URL as it was when ordered (`image`).
  final String image;

  /// Price paid per copy (`price`).
  final double price;

  /// Number of copies (`qty`).
  final int quantity;

  const BookOrderItem({
    required this.name,
    required this.image,
    required this.price,
    required this.quantity,
  });

  /// Price paid for this line.
  double get lineTotal => price * quantity;

  /// Reads one entry of the order's `items` array.
  factory BookOrderItem.fromMap(Map<String, dynamic> data) {
    return BookOrderItem(
      name: data["name"] as String? ?? "",
      image: data["image"] as String? ?? "",
      price: (data["price"] as num?)?.toDouble() ?? 0,
      quantity: (data["qty"] as num?)?.toInt() ?? 1,
    );
  }
}

/// A paid book order placed from the student app (`book_orders`
/// collection). The admin panel only ever changes its [status].
class BookOrderModel {
  /// Firestore document id.
  final String docId;

  /// Name given at checkout (`student_name`).
  final String studentName;

  /// Phone given at checkout (`phone`).
  final String phone;

  /// Delivery address as one line, built from the `address` map.
  final String address;

  /// What was ordered (`items`).
  final List<BookOrderItem> items;

  /// Delivery charge included in [amountPaid] (`delivery_charge`).
  final double deliveryCharge;

  /// Total paid (`total_amount`).
  final double amountPaid;

  /// Razorpay payment id (`payment_id`).
  final String paymentId;

  /// Receipt / order number shown to the student (`receipt_no`).
  final String receiptNo;

  /// One of [BookOrderStatus] (`status`).
  String status;

  /// When the order was placed (`created_at`); null until the server has
  /// stamped it.
  final DateTime? createdAt;

  BookOrderModel({
    required this.docId,
    required this.studentName,
    required this.phone,
    required this.address,
    required this.items,
    required this.deliveryCharge,
    required this.amountPaid,
    required this.paymentId,
    required this.receiptNo,
    required this.status,
    required this.createdAt,
  });

  /// Total number of copies across every line.
  int get copies => items.fold(0, (total, item) => total + item.quantity);

  /// Reads a Firestore document.
  factory BookOrderModel.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? const {};
    final Object? createdAt = data["created_at"];
    return BookOrderModel.fromMap(
        doc.id, data, createdAt is Timestamp ? createdAt.toDate() : null);
  }

  /// Reads the stored map; missing fields fall back to safe values.
  factory BookOrderModel.fromMap(
      String docId, Map<String, dynamic> data, DateTime? createdAt) {
    final Object? rawItems = data["items"];
    final Object? rawAddress = data["address"];
    final Map<String, dynamic> address = rawAddress is Map
        ? Map<String, dynamic>.from(rawAddress)
        : <String, dynamic>{};

    // "12 College Road, Gopsai, Midnapore, West Bengal - 721101"
    final List<String> parts = [
      for (final String key in const ["line1", "locality", "city", "state"])
        if ((address[key] as String? ?? "").trim().isNotEmpty)
          (address[key] as String).trim(),
    ];
    final String pinCode = (address["pin_code"] as String? ?? "").trim();
    final String addressLine = pinCode.isEmpty
        ? parts.join(", ")
        : "${parts.join(", ")} - $pinCode";

    return BookOrderModel(
      docId: docId,
      studentName: data["student_name"] as String? ?? "",
      phone: data["phone"] as String? ?? "",
      address: addressLine,
      items: [
        if (rawItems is List)
          for (final Object? entry in rawItems)
            if (entry is Map)
              BookOrderItem.fromMap(Map<String, dynamic>.from(entry)),
      ],
      deliveryCharge: (data["delivery_charge"] as num?)?.toDouble() ?? 0,
      amountPaid: (data["total_amount"] as num?)?.toDouble() ?? 0,
      paymentId: data["payment_id"] as String? ?? "",
      receiptNo: data["receipt_no"] as String? ?? "",
      status: data["status"] as String? ?? BookOrderStatus.placed,
      createdAt: createdAt,
    );
  }
}
