import 'package:bbarna/book_orders/model/book_order_model.dart';
import 'package:bbarna/book_orders/viewModel/book_order_view_model.dart';
import 'package:bbarna/book_orders/widgets/book_order_card.dart';
import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The book order list (sidebar module): paid orders from the student
/// app's Books tab, newest first, with a filter per status. Each row can
/// be moved to shipped / delivered / cancelled.
class BookOrderList extends StatefulWidget {
  const BookOrderList({super.key});

  @override
  State<BookOrderList> createState() => _BookOrderListState();
}

class _BookOrderListState extends State<BookOrderList> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BookOrderViewModel>(context, listen: false).getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookOrderViewModel>(builder: (context, viewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Book orders",
            count: viewModel.orderList.length,
            subtitle:
                "Paid orders from the app, newest first. Mark each one as you ship and deliver it.",
            trailing: AddWidget(
              title: "REFRESH",
              icon: Icons.refresh,
              addCall: viewModel.getOrders,
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          _filters(viewModel),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(viewModel)),
        ],
      );
    });
  }

  /// "All 12 · New order 3 · Shipped 4 …" — one chip per status.
  Widget _filters(BookOrderViewModel viewModel) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip(viewModel, null, "All"),
        for (final String status in BookOrderStatus.all)
          _filterChip(viewModel, status, BookOrderStatus.label(status)),
      ],
    );
  }

  /// One filter chip; the selected one is filled.
  Widget _filterChip(
      BookOrderViewModel viewModel, String? status, String label) {
    final bool selected = viewModel.statusFilter == status;
    final Color color = status == null
        ? AppTokens.ink
        : BookOrderStatusLook.color(status);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        key: Key('book_order_filter_${status ?? "all"}'),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: () => viewModel.setStatusFilter(status),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .10) : AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
                color: selected
                    ? color.withValues(alpha: .40)
                    : AppTokens.hairline),
          ),
          child: Text(
            "$label  ${viewModel.countFor(status)}",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppTokens.inkMuted),
          ),
        ),
      ),
    );
  }

  /// Skeleton while loading, empty state when there are no rows, otherwise
  /// the order cards.
  Widget _body(BookOrderViewModel viewModel) {
    if (viewModel.isLoading) {
      return const ListSkeleton(rowHeight: 120, rowCount: 4);
    }

    final List<BookOrderModel> orders = viewModel.orderList;
    final String? loadError = viewModel.loadError;
    if (orders.isEmpty && loadError != null) {
      return ListErrorState(title: loadError, onRetry: viewModel.getOrders);
    }
    if (orders.isEmpty) {
      return ListEmptyState(
        isFiltered: viewModel.statusFilter != null,
        icon: Icons.local_shipping_outlined,
        title: "No book orders yet",
        message:
            "When a student buys books in the app, the order appears here for you to deliver.",
        filteredMessage: "No orders with this status.",
        messageWidth: 320,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: orders.length,
      itemBuilder: (context, index) => BookOrderCard(
        key: ValueKey(orders[index].docId),
        order: orders[index],
      ),
    );
  }
}
