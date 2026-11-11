import 'package:bbarna/book_orders/model/book_order_model.dart';
import 'package:bbarna/book_orders/repo/book_order_repo.dart';
import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// State and actions for the Book orders module: the order list with a
/// status filter, and moving an order to its next status.
class BookOrderViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final BookOrderRepo _repo;
  BookOrderViewModel({BookOrderRepo? repo}) : _repo = repo ?? BookOrderRepo();

  /// Every loaded order, newest first.
  List<BookOrderModel> _allOrders = [];

  /// True while the list is loading (drives the skeleton rows).
  bool isLoading = true;

  /// Why the list could not be loaded, or null.
  String? loadError;

  /// Status being shown, or null for "All".
  String? statusFilter;

  /// Ids of orders whose status is being saved right now.
  final Set<String> _saving = <String>{};

  /// Whether [docId]'s status is mid-save.
  bool isSaving(String docId) => _saving.contains(docId);

  /// Orders matching [statusFilter], newest first.
  List<BookOrderModel> get orderList => statusFilter == null
      ? _allOrders
      : _allOrders.where((order) => order.status == statusFilter).toList();

  /// How many loaded orders have [status] (null = all of them).
  int countFor(String? status) => status == null
      ? _allOrders.length
      : _allOrders.where((order) => order.status == status).length;

  /// Loads the newest orders.
  Future<void> getOrders() async {
    isLoading = _allOrders.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      _allOrders = await _repo.getOrders();
    } catch (e) {
      loadError = "Couldn't load book orders";
      Helper.showSnackBarMessage(
          msg: "Error while fetching book orders", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Shows only orders with [status] (null = all).
  void setStatusFilter(String? status) {
    statusFilter = status;
    notifyListeners();
  }

  /// Moves [order] to [status] and updates the row in place. Returns
  /// `false` (and shows a toast) on failure.
  Future<bool> setStatus(BookOrderModel order, String status) async {
    if (order.status == status || _saving.contains(order.docId)) return false;
    _saving.add(order.docId);
    notifyListeners();
    try {
      await _repo.setStatus(order.docId, status);
      order.status = status;
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while updating the order", isSuccess: false);
      return false;
    } finally {
      _saving.remove(order.docId);
      notifyListeners();
    }
  }
}
