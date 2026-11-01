import 'package:bbarna/book_orders/model/book_order_model.dart';
import 'package:bbarna/book_orders/viewModel/book_order_view_model.dart';
import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Colour and icon for each order status, shared by the card's chip and
/// the list's filter.
class BookOrderStatusLook {
  const BookOrderStatusLook._();

  /// Chip colour for [status].
  static Color color(String status) {
    switch (status) {
      case BookOrderStatus.shipped:
        return const Color(0xFF175CD3);
      case BookOrderStatus.delivered:
        return const Color(0xFF108460);
      case BookOrderStatus.cancelled:
        return AppTokens.danger;
      default:
        return const Color(0xFFB54708);
    }
  }

  /// Chip icon for [status].
  static IconData icon(String status) {
    switch (status) {
      case BookOrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case BookOrderStatus.delivered:
        return Icons.check_circle_outline;
      case BookOrderStatus.cancelled:
        return Icons.cancel_outlined;
      default:
        return Icons.fiber_new_outlined;
    }
  }
}

/// One book order: who ordered, where it goes, what is in it and what was
/// paid; a status chip; and a "Change status" menu.
class BookOrderCard extends StatelessWidget {
  /// The order shown in this row.
  final BookOrderModel order;

  const BookOrderCard({required this.order, super.key});

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(),
        // Always shown: changing the status is the whole point of this
        // row, so it is not hidden behind a hover.
        actions: _statusMenu(context),
      ),
    );
  }

  /// Order number and date, the customer, the address and the items.
  Widget _identity() {
    final DateTime? createdAt = order.createdAt;
    final String date = createdAt == null
        ? "Just now"
        : DateFormat('d MMM yyyy, h:mm a').format(createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SelectableLabel(
              order.receiptNo.isEmpty ? order.docId : order.receiptNo,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink),
            ),
            Text(date,
                style:
                    const TextStyle(fontSize: 12, color: AppTokens.inkFaint)),
          ],
        ),
        const SizedBox(height: 6),
        _line(Icons.person_outline, "${order.studentName} · ${order.phone}"),
        const SizedBox(height: 3),
        _line(Icons.location_on_outlined, order.address),
        const SizedBox(height: 8),
        for (final BookOrderItem item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              "${item.quantity} × ${item.name}  (${formatRupees(item.lineTotal)})",
              style: const TextStyle(fontSize: 13, color: AppTokens.ink),
            ),
          ),
      ],
    );
  }

  /// A small icon followed by selectable text (so a phone number or
  /// address can be copied onto a courier label).
  Widget _line(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: AppTokens.inkFaint),
        ),
        const SizedBox(width: 6),
        Expanded(child: SelectableLabel(text, style: AppTokens.body)),
      ],
    );
  }

  /// Status, amount paid and number of copies.
  Widget _chips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: BookOrderStatusLook.icon(order.status),
          label: BookOrderStatus.label(order.status),
          color: BookOrderStatusLook.color(order.status),
          filled: true,
        ),
        StatusChip(
          icon: Icons.payments_outlined,
          label: "Paid ${formatRupees(order.amountPaid)}",
          color: AppTokens.inkMuted,
        ),
        StatusChip(
          icon: Icons.auto_stories_outlined,
          label: order.copies == 1 ? "1 copy" : "${order.copies} copies",
          color: AppTokens.inkMuted,
        ),
      ],
    );
  }

  /// "Change status ▾": the other three statuses.
  Widget _statusMenu(BuildContext context) {
    final BookOrderViewModel viewModel =
        Provider.of<BookOrderViewModel>(context, listen: false);
    final bool busy = viewModel.isSaving(order.docId);

    return PopupMenuButton<String>(
      key: Key('book_order_status_${order.docId}'),
      enabled: !busy,
      tooltip: "Change status",
      color: AppTokens.surface,
      onSelected: (status) async {
        final bool success = await viewModel.setStatus(order, status);
        if (success) {
          Helper.showInfoMessage(
              msg: "Order marked ${BookOrderStatus.label(status).toLowerCase()}");
        }
      },
      itemBuilder: (context) => [
        for (final String status in BookOrderStatus.all)
          if (status != order.status)
            PopupMenuItem<String>(
              value: status,
              child: Row(
                children: [
                  Icon(BookOrderStatusLook.icon(status),
                      size: 17, color: BookOrderStatusLook.color(status)),
                  const SizedBox(width: 10),
                  Text("Mark ${BookOrderStatus.label(status).toLowerCase()}",
                      style: const TextStyle(fontSize: 13.5)),
                ],
              ),
            ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: AppTokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.edit_outlined,
                  size: 15, color: AppTokens.inkMuted),
            const SizedBox(width: 7),
            const Text("Change status",
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: AppTokens.inkMuted),
          ],
        ),
      ),
    );
  }
}
