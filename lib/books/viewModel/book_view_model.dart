import 'dart:typed_data';

import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/books/repo/book_repo.dart';
import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// State and actions for the Books module: the full book list with a local
/// search, create/update/delete with cover upload, the in-stock toggle and
/// the delivery charge.
class BookViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final BookRepo _bookRepo;
  BookViewModel({BookRepo? bookRepo}) : _bookRepo = bookRepo ?? BookRepo();

  /// Books currently shown (after the search filter), newest first.
  List<BookModel> bookList = [];

  /// Every book, unfiltered; the search filters this.
  List<BookModel> _allBooks = [];

  /// True while the list is loading (drives the skeleton rows).
  bool isLoading = true;

  /// Why the list could not be loaded, or null.
  String? loadError;

  /// Flat delivery charge per order (0 = free delivery).
  double deliveryCharge = 0;

  /// Ids of books whose in-stock toggle is being saved right now.
  final Set<String> _togglingStock = <String>{};

  /// Whether [docId]'s in-stock toggle is mid-save.
  bool isTogglingStock(String docId) => _togglingStock.contains(docId);

  /// What the search box last held; re-applied after every refetch.
  String searchText = "";

  /// Loads every book (newest first) and the delivery charge.
  Future<void> getBookList() async {
    // Skeleton only when nothing is on screen yet.
    isLoading = _allBooks.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      final List<BookModel> loaded = await _bookRepo.getBookList();
      loaded.sort((a, b) => b.timeStamp.compareTo(a.timeStamp));
      _allBooks = loaded;
      _applySearch();
      deliveryCharge = await _bookRepo.getDeliveryCharge();
    } catch (e) {
      loadError = "Couldn't load books";
      Helper.showSnackBarMessage(
          msg: "Error while fetching books", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Creates the document and uploads its cover as one operation. If the
  /// upload fails the new document is deleted again and `false` is
  /// returned.
  Future<bool> createBook(BookModel book, Uint8List image) async {
    String? docId;
    try {
      docId = await _bookRepo.addBook(book);
      await _bookRepo.uploadBookImage(image, docId);
      return true;
    } catch (e) {
      if (docId != null) {
        try {
          await _bookRepo.deleteBook(docId);
        } catch (_) {}
      }
      Helper.showSnackBarMessage(
          msg: "Error while adding the book", isSuccess: false);
      return false;
    }
  }

  /// [image] is null when the admin did not pick a new cover — the
  /// existing one is then left exactly as it is.
  Future<bool> updateBook(BookModel book, String docId,
      {Uint8List? image}) async {
    try {
      await _bookRepo.updateBook(book, docId);
      if (image != null) {
        await _bookRepo.uploadBookImage(image, docId);
      }
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the book", isSuccess: false);
      return false;
    }
  }

  /// Deletes the book. Returns `false` (and shows a toast) on failure.
  Future<bool> deleteBook(String docId) async {
    try {
      await _bookRepo.deleteBook(docId);
      _allBooks = _allBooks.where((b) => b.docId != docId).toList();
      _applySearch();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the book", isSuccess: false);
      return false;
    }
  }

  /// Flips "in stock" and updates the row in place.
  Future<void> toggleInStock(BookModel book) async {
    if (_togglingStock.contains(book.docId)) return;
    final bool next = !book.inStock;
    _togglingStock.add(book.docId);
    notifyListeners();
    try {
      await _bookRepo.setInStock(book.docId, next);
      book.inStock = next;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the book", isSuccess: false);
    } finally {
      _togglingStock.remove(book.docId);
      notifyListeners();
    }
  }

  /// Saves the delivery charge. Returns `false` (and shows a toast) on
  /// failure.
  Future<bool> saveDeliveryCharge(double charge) async {
    try {
      await _bookRepo.setDeliveryCharge(charge);
      deliveryCharge = charge;
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while saving the delivery charge", isSuccess: false);
      return false;
    }
  }

  /// Filters [bookList] by name or author (case-insensitive).
  void searchBook({required String searchText}) {
    this.searchText = searchText;
    _applySearch();
    notifyListeners();
  }

  /// Rebuilds [bookList] from every book using [searchText].
  void _applySearch() {
    final String query = searchText.toLowerCase().trim();
    if (query.isEmpty) {
      bookList = List<BookModel>.from(_allBooks);
    } else {
      bookList = _allBooks
          .where((book) =>
              book.name.toLowerCase().contains(query) ||
              book.author.toLowerCase().contains(query))
          .toList();
    }
  }
}
