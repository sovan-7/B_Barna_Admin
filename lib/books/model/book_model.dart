import 'package:cloud_firestore/cloud_firestore.dart';

/// A printed book sold in the student app (`books` collection).
///
/// The field names are a contract with the student app
/// (`b_barna_app/lib/books/model/book_model.dart`): renaming one here
/// silently blanks it there.
class BookModel {
  /// Firestore document id (not stored inside the document).
  String docId;

  /// Title (`name`).
  String name;

  /// Author or publisher line; may be empty (`author`).
  String author;

  /// Free-text description shown on the book's page (`description`).
  String description;

  /// Download URL of the cover (`image`).
  String image;

  /// Printed price (`mrp`).
  double mrp;

  /// What the student pays (`selling_price`). 0 means "sell at MRP".
  double sellingPrice;

  /// False keeps the book listed but blocks "Add to cart" (`in_stock`).
  bool inStock;

  /// Whether the app shows the book at all (`willDisplay`).
  bool willDisplay;

  /// Sort order in the app; lower comes first (`display_priority`).
  int displayPriority;

  /// Creation time in epoch milliseconds (`timeStamp`); the admin list
  /// sorts newest first on it.
  int timeStamp;

  BookModel({
    this.docId = "",
    required this.name,
    required this.author,
    required this.description,
    required this.image,
    required this.mrp,
    required this.sellingPrice,
    required this.inStock,
    required this.willDisplay,
    required this.displayPriority,
    required this.timeStamp,
  });

  /// The price a student is charged for one copy.
  double get price => sellingPrice > 0 ? sellingPrice : mrp;

  /// Converts this model to the Firestore document map.
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "author": author,
      "description": description,
      "image": image,
      "mrp": mrp,
      "selling_price": sellingPrice,
      "in_stock": inStock,
      "willDisplay": willDisplay,
      "display_priority": displayPriority,
      "timeStamp": timeStamp,
    };
  }

  /// Reads a Firestore document.
  factory BookModel.fromDocumentSnapshot(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      BookModel.fromMap(doc.id, doc.data() ?? const {});

  /// Reads the stored map; missing fields fall back to safe values.
  factory BookModel.fromMap(String docId, Map<String, dynamic> data) {
    return BookModel(
      docId: docId,
      name: data["name"] as String? ?? "",
      author: data["author"] as String? ?? "",
      description: data["description"] as String? ?? "",
      image: data["image"] as String? ?? "",
      mrp: (data["mrp"] as num?)?.toDouble() ?? 0,
      sellingPrice: (data["selling_price"] as num?)?.toDouble() ?? 0,
      inStock: data["in_stock"] as bool? ?? true,
      willDisplay: data["willDisplay"] as bool? ?? false,
      displayPriority: (data["display_priority"] as num?)?.toInt() ?? 0,
      timeStamp: (data["timeStamp"] as num?)?.toInt() ?? 0,
    );
  }
}
