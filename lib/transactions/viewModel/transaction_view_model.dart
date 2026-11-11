import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/repo/transaction_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// Which purchases to show.
enum TransactionFilter { all, paid, free }

/// State for the Transactions module: the loaded purchases, the search and
/// filter over them, and their totals. Read-only.
class TransactionViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final TransactionRepo _repo;
  TransactionViewModel({TransactionRepo? repo})
      : _repo = repo ?? TransactionRepo();

  /// Every loaded purchase, newest first.
  List<TransactionModel> _all = [];

  /// Where the next page starts.
  Object? _cursor;

  /// Bumped by each fresh load, so a slower older answer is ignored.
  int _generation = 0;

  /// True while the first page is loading (drives the skeleton rows).
  bool isLoading = true;

  /// True while another page is loading.
  bool isLoadingMore = false;

  /// Whether older purchases may remain.
  bool hasMore = false;

  /// Why the list could not be loaded, or null.
  String? loadError;

  /// Purchases in the whole collection; null until known.
  int? totalCount;

  /// The search box's text.
  String searchText = "";

  /// The selected filter.
  TransactionFilter filter = TransactionFilter.all;

  /// How many purchases are loaded.
  int get loadedCount => _all.length;

  /// Loaded purchases matching the search, before the filter.
  List<TransactionModel> get _matching {
    final String query = searchText.trim().toLowerCase();
    if (query.isEmpty) return _all;
    return _all.where((t) {
      return t.studentName.toLowerCase().contains(query) ||
          t.phone.contains(query) ||
          t.subjectName.toLowerCase().contains(query) ||
          t.receiptNo.toLowerCase().contains(query) ||
          (t.paymentId ?? "").toLowerCase().contains(query);
    }).toList();
  }

  /// The purchases on screen: matching the search and the filter.
  List<TransactionModel> get shown {
    final List<TransactionModel> matching = _matching;
    switch (filter) {
      case TransactionFilter.paid:
        return matching.where((t) => !t.isFree).toList();
      case TransactionFilter.free:
        return matching.where((t) => t.isFree).toList();
      case TransactionFilter.all:
        return matching;
    }
  }

  /// How many search matches [option] would show.
  int countFor(TransactionFilter option) {
    final List<TransactionModel> matching = _matching;
    switch (option) {
      case TransactionFilter.paid:
        return matching.where((t) => !t.isFree).length;
      case TransactionFilter.free:
        return matching.where((t) => t.isFree).length;
      case TransactionFilter.all:
        return matching.length;
    }
  }

  /// Money collected across [shown].
  double get totalCollected =>
      shown.fold(0, (double sum, t) => sum + t.amountPaid);

  /// Offers and coupons across [shown].
  double get totalDiscounts => shown.fold(0, (double sum, t) => sum + t.saved);

  /// Loads the newest purchases, replacing what is loaded.
  Future<void> getTransactions() async {
    final int generation = ++_generation;
    isLoading = _all.isEmpty;
    isLoadingMore = false;
    loadError = null;
    notifyListeners();
    try {
      final TransactionPage page = await _repo.getPage();
      if (generation != _generation) return;
      _all = page.items;
      _cursor = page.cursor;
      hasMore = page.hasMore;
    } catch (e) {
      if (generation != _generation) return;
      loadError = "Couldn't load transactions";
      Helper.showSnackBarMessage(
          msg: "Error while fetching transactions", isSuccess: false);
    }
    isLoading = false;
    notifyListeners();
    _loadTotalCount(generation);
  }

  /// The total is only for the footer, so failing to get it is not an error.
  Future<void> _loadTotalCount(int generation) async {
    try {
      final int count = await _repo.getTotalCount();
      if (generation != _generation) return;
      totalCount = count;
      notifyListeners();
    } catch (_) {
      // The footer falls back to the number loaded.
    }
  }

  /// Adds the next page of older purchases.
  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore || isLoading) return;
    final int generation = _generation;
    isLoadingMore = true;
    notifyListeners();
    try {
      final TransactionPage page = await _repo.getPage(cursor: _cursor);
      if (generation != _generation) return;
      _all = [..._all, ...page.items];
      _cursor = page.cursor;
      hasMore = page.hasMore;
    } catch (e) {
      if (generation != _generation) return;
      Helper.showSnackBarMessage(
          msg: "Error while loading more transactions", isSuccess: false);
    }
    isLoadingMore = false;
    notifyListeners();
  }

  /// Changes the search text.
  void setSearch(String text) {
    searchText = text;
    notifyListeners();
  }

  /// Changes the filter.
  void setFilter(TransactionFilter option) {
    filter = option;
    notifyListeners();
  }
}
