import 'package:cloud_firestore/cloud_firestore.dart';

/// One purchase (`transactions` collection): written by the student app
/// when a student pays or enrols for free. The field names here are the
/// ones the app's `TransactionModel.toMap` writes, so they must not change
/// on one side only.
class TransactionModel {
  /// Firestore document id.
  final String docId;

  /// `student_id`.
  final String studentId;

  /// `student_name`, copied at the time of purchase.
  final String studentName;

  /// `phone`: 10 digits, no +91.
  final String phone;

  /// `subject_code`.
  final String subjectCode;

  /// `subject_name`.
  final String subjectName;

  /// `course_type`, e.g. "Full Course".
  final String courseType;

  /// `course_price`: the full price (MRP).
  final double coursePrice;

  /// `offer_discount`: money off from the offer price.
  final double offerDiscount;

  /// `coupon_code`; null when no coupon was used.
  final String? couponCode;

  /// `coupon_discount`.
  final double couponDiscount;

  /// `amount_paid`.
  final double amountPaid;

  /// `payment_id` from Razorpay; null for a free enrolment.
  final String? paymentId;

  /// `method`: "Razorpay" or "Free".
  final String method;

  /// `receipt_no`, e.g. "BB-20260926-Q2K9XA".
  final String receiptNo;

  /// `created_at`. Null only for a purchase so new the server has not
  /// stamped it yet.
  final DateTime? createdAt;

  const TransactionModel({
    required this.docId,
    required this.studentId,
    required this.studentName,
    required this.phone,
    required this.subjectCode,
    required this.subjectName,
    required this.courseType,
    required this.coursePrice,
    required this.offerDiscount,
    required this.couponCode,
    required this.couponDiscount,
    required this.amountPaid,
    required this.paymentId,
    required this.method,
    required this.receiptNo,
    required this.createdAt,
  });

  /// True when nothing was paid.
  bool get isFree => amountPaid <= 0;

  /// Offer and coupon savings together.
  double get saved => offerDiscount + couponDiscount;

  /// Reads a Firestore document; missing fields fall back to blank or 0.
  factory TransactionModel.fromDocumentSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? const {};
    return TransactionModel.fromMap(doc.id, data);
  }

  /// Reads the stored fields of document [docId].
  factory TransactionModel.fromMap(String docId, Map<String, dynamic> data) {
    return TransactionModel(
      docId: docId,
      studentId: data['student_id'] as String? ?? '',
      studentName: data['student_name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      subjectCode: data['subject_code'] as String? ?? '',
      subjectName: data['subject_name'] as String? ?? '',
      courseType: data['course_type'] as String? ?? '',
      // Firestore hands a whole number back as an int.
      coursePrice: (data['course_price'] as num?)?.toDouble() ?? 0,
      offerDiscount: (data['offer_discount'] as num?)?.toDouble() ?? 0,
      couponCode: data['coupon_code'] as String?,
      couponDiscount: (data['coupon_discount'] as num?)?.toDouble() ?? 0,
      amountPaid: (data['amount_paid'] as num?)?.toDouble() ?? 0,
      paymentId: data['payment_id'] as String?,
      method: data['method'] as String? ?? '',
      receiptNo: data['receipt_no'] as String? ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }
}
