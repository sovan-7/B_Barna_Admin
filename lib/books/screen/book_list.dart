import 'package:bbarna/books/model/book_model.dart';
import 'package:bbarna/books/screen/add_book.dart';
import 'package:bbarna/books/viewModel/book_view_model.dart';
import 'package:bbarna/books/widgets/book_card.dart';
import 'package:bbarna/books/widgets/delivery_charge_dialog.dart';
import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/money.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The book list (sidebar module): every printed book sold in the student
/// app's Books tab.
///
/// Every book is loaded at once and the search filters them locally by
/// name or author. The delivery charge for book orders is set from here
/// too.
class BookList extends StatefulWidget {
  const BookList({super.key});

  @override
  State<BookList> createState() => _BookListState();
}

class _BookListState extends State<BookList> {
  /// Text in the search box.
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final BookViewModel bookViewModel =
        Provider.of<BookViewModel>(context, listen: false);
    searchController.text = bookViewModel.searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      bookViewModel.getBookList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookViewModel>(builder: (context, bookViewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Books",
            count: bookViewModel.bookList.length,
            subtitle:
                "Sold in the app's Books tab. Hidden books are not shown to students.",
            trailing: AddWidget(
              title: "NEW BOOK",
              addCall: () => _openAdd(bookViewModel),
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          Wrap(
            spacing: AppTokens.gapMd,
            runSpacing: AppTokens.gapSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ListSearchField(
                controller: searchController,
                hintText: "Search by name or author",
                maxWidth: 360,
                onChanged: (text) =>
                    bookViewModel.searchBook(searchText: text),
                onCleared: () => bookViewModel.searchBook(searchText: ""),
              ),
              _deliveryChargeButton(bookViewModel),
            ],
          ),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(bookViewModel)),
        ],
      );
    });
  }

  /// "Delivery charge: ₹40" — opens the popup that changes it.
  Widget _deliveryChargeButton(BookViewModel bookViewModel) {
    final String amount = bookViewModel.deliveryCharge > 0
        ? formatRupees(bookViewModel.deliveryCharge)
        : "Free";

    return OutlinedButton.icon(
      key: const Key('delivery_charge_button'),
      onPressed: bookViewModel.isLoading
          ? null
          : () => DeliveryChargeDialog.show(context, bookViewModel),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTokens.ink,
        side: const BorderSide(color: AppTokens.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      ),
      icon: const Icon(Icons.local_shipping_outlined, size: 17),
      label: Text("Delivery charge: $amount",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  /// Opens Add Book and reloads the list if something was saved.
  void _openAdd(BookViewModel bookViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBook()),
    ).ifSaved(bookViewModel.getBookList);
  }

  /// Skeleton while loading, empty state when there are no rows, otherwise
  /// the book cards.
  Widget _body(BookViewModel bookViewModel) {
    if (bookViewModel.isLoading) {
      return const ListSkeleton(rowHeight: 74, rowCount: 5);
    }

    final List<BookModel> bookRows = bookViewModel.bookList;
    final String? loadError = bookViewModel.loadError;
    if (bookRows.isEmpty && loadError != null) {
      return ListErrorState(
          title: loadError, onRetry: bookViewModel.getBookList);
    }
    if (bookRows.isEmpty) {
      return ListEmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        icon: Icons.auto_stories_outlined,
        title: "No books yet",
        message:
            "Books you add here appear in the app's Books tab, where students can buy them.",
        filteredMessage: "No book matches that name or author.",
        messageWidth: 320,
        addLabel: "Add a book",
        onAdd: () => _openAdd(bookViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: bookRows.length,
      itemBuilder: (context, index) => BookCard(
        key: ValueKey(bookRows[index].docId),
        bookData: bookRows[index],
        onChanged: bookViewModel.getBookList,
      ),
    );
  }
}
