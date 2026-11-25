import 'dart:typed_data';

import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/image_sizes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore / Storage access for the `books` collection and the book
/// shop's one setting (the delivery charge). Books are few, so the whole
/// collection is loaded at once (no paging).
///
/// Every method throws on failure; [BookViewModel] catches and reports.
class BookRepo {
  /// Firestore client.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Root of Firebase Storage; uploads go under it.
  final Reference storageReference = FirebaseStorage.instance.ref();

  /// The `books` collection.
  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(books);

  /// `app_settings/books`, where the student app reads the delivery charge.
  DocumentReference<Map<String, dynamic>> get _settings =>
      _firestore.collection(appSettings).doc(bookSettingsDoc);

  /// Adds a book and returns the new document's id.
  Future<String> addBook(BookModel book) async {
    final DocumentReference<Map<String, dynamic>> doc =
        await _collection.add(book.toMap());
    return doc.id;
  }

  /// Every book, in Firestore's default order (the view model sorts).
  Future<List<BookModel>> getBookList() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _collection.get();
    return snapshot.docs
        .map((docSnapshot) => BookModel.fromDocumentSnapshot(docSnapshot))
        .toList();
  }

  /// Shrinks and uploads [image] to `images/book_<bookId>` and stores its
  /// download URL as `image`.
  Future<void> uploadBookImage(Uint8List image, String bookId) async {
    final String url = await uploadImageToStorage(
      storageReference.child("images").child("book_$bookId"),
      image,
      maxSide: ImageSizes.thumbnail,
    );
    await _collection.doc(bookId).update({"image": url});
  }

  /// Overwrites the book's fields.
  Future<void> updateBook(BookModel book, String docId) async {
    await _collection.doc(docId).update(book.toMap());
  }

  /// Sets only the `in_stock` flag.
  Future<void> setInStock(String docId, bool inStock) async {
    await _collection.doc(docId).update({"in_stock": inStock});
  }

  /// Deletes the book document.
  Future<void> deleteBook(String docId) async {
    await _collection.doc(docId).delete();
  }

  /// The flat delivery charge per order; 0 when it has never been set.
  Future<double> getDeliveryCharge() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _settings.get();
    final Object? value = doc.data()?["delivery_charge"];
    return value is num && value > 0 ? value.toDouble() : 0;
  }

  /// Saves the delivery charge (creating the settings document if needed).
  Future<void> setDeliveryCharge(double charge) async {
    await _settings.set({"delivery_charge": charge}, SetOptions(merge: true));
  }
}
