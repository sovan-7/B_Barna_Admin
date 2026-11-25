import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/books/screen/edit_book.dart';
import 'package:bbarna/books/viewModel/book_view_model.dart';
import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/money.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the book list: cover, name, author and price; priority /
/// visibility chips and a tappable in-stock toggle; edit / delete buttons.
class BookCard extends StatelessWidget {
  /// The item shown in this row.
  final BookModel bookData;

  /// Called after something changed, so the list can refresh.
  final VoidCallback onChanged;

  const BookCard({required this.bookData, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(context),
        actions: _actions(context, layout.showActions),
      ),
    );
  }

  /// Left part of the row: cover, name, author and price.
  Widget _identity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImageOrInitial(
          imageUrl: bookData.image,
          initial:
              bookData.name.isEmpty ? "?" : bookData.name.characters.first,
          size: 42,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableLabel(
                bookData.name,
                style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              const SizedBox(height: 4),
              Text(_priceLine(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.body),
            ],
          ),
        ),
      ],
    );
  }

  /// "A. Sarkar · ₹199 (MRP ₹250)".
  String _priceLine() {
    final String price = bookData.mrp > bookData.price
        ? "${formatRupees(bookData.price)} (MRP ${formatRupees(bookData.mrp)})"
        : formatRupees(bookData.price);
    if (bookData.author.trim().isEmpty) return price;
    return "${bookData.author} · $price";
  }

  /// Priority and visibility chips, and the in-stock toggle.
  Widget _chips(BuildContext context) {
    final BookViewModel bookViewModel =
        Provider.of<BookViewModel>(context, listen: false);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: Icons.low_priority,
          label: "Priority ${bookData.displayPriority}",
          color: AppTokens.inkMuted,
        ),
        StatusChip(
          icon: bookData.willDisplay
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          label: bookData.willDisplay ? "Visible" : "Hidden",
          color: bookData.willDisplay
              ? const Color(0xFF108460)
              : AppTokens.inkFaint,
          filled: true,
        ),
        ToggleChip(
          buttonKey: Key('book_stock_${bookData.docId}'),
          icon: bookData.inStock
              ? Icons.inventory_2_outlined
              : Icons.remove_shopping_cart_outlined,
          label: bookData.inStock ? "In stock" : "Out of stock",
          on: bookData.inStock,
          onColor: const Color(0xFF108460),
          tooltip: bookData.inStock ? "Mark out of stock" : "Mark in stock",
          busy: bookViewModel.isTogglingStock(bookData.docId),
          onTap: () => bookViewModel.toggleInStock(bookData),
        ),
      ],
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(BuildContext context, bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('book_edit_${bookData.docId}'),
          tooltip: "Edit book",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => EditBook(bookData: bookData)),
          ).ifSaved(onChanged),
        ),
        CardDeleteButton(
          buttonKey: Key('book_delete_${bookData.docId}'),
          tooltip: "Delete book",
          onTap: () {
            final BookViewModel bookViewModel =
                Provider.of<BookViewModel>(context, listen: false);
            final String docId = bookData.docId;
            confirmDelete(
              title: bookData.name,
              delete: () => bookViewModel.deleteBook(docId),
              successMessage: "Book deleted successfully",
            );
          },
        ),
      ],
    );
  }
}
