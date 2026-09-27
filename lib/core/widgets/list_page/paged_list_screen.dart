import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Builds one row of the list. [onChanged] must be called by the card after
/// it edits or deletes the item, so the list reloads.
typedef PagedListItemBuilder<T> = Widget Function(
    BuildContext context, T item, VoidCallback onChanged);

/// A complete list screen for any [PagedListViewModel]: header with count
/// and "NEW …" button, server-side code search, skeleton while loading,
/// empty state, the cards, and a "Load more" footer.
///
/// Used by Audio, PDF, Video, Quiz, Question, Unit and Topic. Each of those
/// screens only supplies its texts, sizes, the Add screen and a card
/// builder, e.g.:
///
/// ```dart
/// PagedListScreen<PdfViewModel, PdfModel>(
///   title: "PDFs",
///   ...
///   itemBuilder: (context, pdf, onChanged) =>
///       PdfCard(key: ValueKey(pdf.docId), pdfData: pdf, onChanged: onChanged),
/// )
/// ```
///
/// [VM] is looked up with Provider, so it must be provided above the app.
class PagedListScreen<VM extends PagedListViewModel<T>, T>
    extends StatefulWidget {
  // ---- Header --------------------------------------------------------------

  /// Page title, e.g. "PDFs".
  final String title;

  /// One-line description under the title.
  final String subtitle;

  /// Text on the header's add button, e.g. "NEW PDF".
  final String addButtonLabel;

  /// Builds the Add screen opened by the add buttons.
  final WidgetBuilder addScreenBuilder;

  // ---- Search ----------------------------------------------------------------

  /// Search box placeholder, e.g. "Search by PDF code".
  final String searchHint;

  // ---- Loading / empty states -----------------------------------------------

  /// Height of each skeleton row (match the card height).
  final double skeletonRowHeight;

  /// Icon shown when the collection is empty.
  final IconData emptyIcon;

  /// Heading shown when the collection is empty, e.g. "No PDFs yet".
  final String emptyTitle;

  /// Explanation shown when the collection is empty.
  final String emptyMessage;

  /// Explanation shown when a search matched nothing.
  final String filteredMessage;

  /// Label of the empty state's add button, e.g. "Add a PDF".
  final String emptyAddLabel;

  // ---- Rows ------------------------------------------------------------------

  /// Builds one card.
  final PagedListItemBuilder<T> itemBuilder;

  /// Extra work to do after the first frame, next to loading the list
  /// (e.g. preloading the course list the Add form needs).
  final void Function(BuildContext context)? onFirstFrame;

  const PagedListScreen({
    required this.title,
    required this.subtitle,
    required this.addButtonLabel,
    required this.addScreenBuilder,
    required this.searchHint,
    required this.skeletonRowHeight,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.filteredMessage,
    required this.emptyAddLabel,
    required this.itemBuilder,
    this.onFirstFrame,
    super.key,
  });

  @override
  State<PagedListScreen<VM, T>> createState() => _PagedListScreenState<VM, T>();
}

/// State: owns the search box controller.
class _PagedListScreenState<VM extends PagedListViewModel<T>, T>
    extends State<PagedListScreen<VM, T>> {
  /// Text in the search box.
  final TextEditingController searchController = TextEditingController();

  /// The view model, read without listening (for callbacks).
  VM get _viewModel => Provider.of<VM>(context, listen: false);

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left; the
    // view model keeps it across Add/Edit and module switches.
    searchController.text = _viewModel.searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewModel.refresh();
      widget.onFirstFrame?.call(context);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VM>(builder: (context, viewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: widget.title,
            count: viewModel.totalCount,
            subtitle: widget.subtitle,
            trailing: AddWidget(
              title: widget.addButtonLabel,
              addCall: () => _openAdd(viewModel),
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          // The hint names the code on purpose: the search is a server-side
          // prefix match on the code field, not a match on titles.
          ListSearchField(
            controller: searchController,
            hintText: widget.searchHint,
            onChanged: (text) {
              viewModel.search(text);
              setState(() {});
            },
            onCleared: () {
              viewModel.search("");
              setState(() {});
            },
          ),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(viewModel)),
          // Footer only once there are rows to count.
          if (!viewModel.isLoading && viewModel.items.isNotEmpty)
            PagedListFooter(
              shown: viewModel.items.length,
              total: viewModel.totalCount,
              isSearching: viewModel.isSearching,
              hasMore: viewModel.hasMore,
              isLoadingMore: viewModel.isLoadingMore,
              pageSize: viewModel.limit,
              onLoadMore: viewModel.loadNextPage,
            ),
        ],
      );
    });
  }

  /// Opens the Add screen and reloads the list if something was
  /// saved.
  void _openAdd(VM viewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: widget.addScreenBuilder),
    ).ifSaved(() {
      viewModel.refresh();
    });
  }

  /// Skeleton while loading, an error with Retry when loading failed, the
  /// empty state when there are no rows, otherwise the cards.
  Widget _body(VM viewModel) {
    if (viewModel.isLoading) {
      return ListSkeleton(rowHeight: widget.skeletonRowHeight);
    }

    final List<T> items = viewModel.items;
    // A failed load or search: say so, with Retry, rather than "No X yet".
    final String? loadError = viewModel.loadError;
    if (items.isEmpty && loadError != null) {
      return ListErrorState(title: loadError, onRetry: viewModel.refresh);
    }
    if (items.isEmpty) {
      return ListEmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        filteredMessage: widget.filteredMessage,
        addLabel: widget.emptyAddLabel,
        onAdd: () => _openAdd(viewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          widget.itemBuilder(context, items[index], viewModel.refresh),
    );
  }
}
