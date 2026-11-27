import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/repo/transaction_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// Which purchases to show.
enum TransactionFilter { all, paid, free }

/// Which purchases the list covers by date.
enum TransactionRange {
  thisMonth("This month"),
  last30("Last 30 days"),
  all("All");

  const TransactionRange(this.label);

  /// Chip text.
  final String label;
}

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

  /// The date range picked above the list; everything by default.
  TransactionRange range = TransactionRange.all;

  /// Picks a date range.
  void setRange(TransactionRange value) {
    range = value;
    notifyListeners();
  }

  /// Where [range] starts at [now] (null for all time).
  DateTime? rangeStart(DateTime now) => switch (range) {
        TransactionRange.thisMonth => DateTime(now.year, now.month),
        TransactionRange.last30 => now.subtract(const Duration(days: 30)),
        TransactionRange.all => null,
      };

  /// Whether [t] falls on or after [start]. A purchase the server has not
  /// stamped yet is brand new, so it is in every range.
  static bool _since(TransactionModel t, DateTime? start) {
    final DateTime? at = t.createdAt;
    return start == null || at == null || !at.isBefore(start);
  }

  /// What was collected in the period just before [range] (last month, or
  /// the 30 days before the last 30), or null when that period is not
  /// fully loaded yet — a partial number would only mislead.
  double? previousCollected({DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    final (DateTime, DateTime)? period = switch (range) {
      TransactionRange.thisMonth => (
          DateTime(at.year, at.month - 1),
          DateTime(at.year, at.month)
        ),
      TransactionRange.last30 => (
          at.subtract(const Duration(days: 60)),
          at.subtract(const Duration(days: 30))
        ),
      TransactionRange.all => null,
    };
    if (period == null) return null;
    final (DateTime from, DateTime to) = period;
    final DateTime? oldest = _all.isEmpty ? null : _all.last.createdAt;
    final bool covered = !hasMore || (oldest != null && oldest.isBefore(from));
    if (!covered) return null;
    return _all
        .where((t) =>
            t.createdAt != null &&
            !t.createdAt!.isBefore(from) &&
            t.createdAt!.isBefore(to))
        .fold<double>(0, (sum, t) => sum + t.amountPaid);
  }

  /// Loaded purchases matching the search and [range], before the filter.
  List<TransactionModel> get _matching {
    final String query = searchText.trim().toLowerCase();
    final DateTime? start = rangeStart(DateTime.now());
    final List<TransactionModel> inRange =
        start == null ? _all : _all.where((t) => _since(t, start)).toList();
    if (query.isEmpty) return inRange;
    return inRange.where((t) {
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
