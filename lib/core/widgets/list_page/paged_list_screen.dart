import 'package:bbarna/core/viewModel/paged_list_view_model.dart';
import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
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

/// Builds the cells of one table row (see [PagedListScreen.tableColumns]).
/// [hovered] fades the row actions in; [onChanged] reloads the list.
typedef PagedListCellsBuilder<T> = List<Widget> Function(
    BuildContext context, T item, bool hovered, VoidCallback onChanged);

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

  /// A second header button, shown before the add button (e.g. Import).
  /// Gets the view model so it can refresh the list afterwards.
  final Widget Function(BuildContext context, VM viewModel)? extraHeaderAction;

  // ---- Stats, chips and the table ------------------------------------------

  /// The tiles above the list (usually from `viewModel.stats`); none when
  /// null.
  final List<Widget> Function(VM viewModel)? statTiles;

  /// Chips beside the search box. Their values are matched by [chipMatches]
  /// against the rows already loaded; "all" shows everything.
  final List<FilterOption<String>>? chipOptions;

  /// Whether [item] is shown under chip [filter] (never called for "all").
  final bool Function(T item, String filter)? chipMatches;

  /// Columns of the wide-screen table; the list stays cards when null.
  final List<AdminTableColumn>? tableColumns;

  /// Cells of one table row, one per [tableColumns] entry.
  final PagedListCellsBuilder<T>? rowCells;

  /// A stable id per row (the document id), for row keys.
  final String Function(T item)? rowId;

  /// Prefix of the row keys (`<prefix>_row_<id>`), for tests.
  final String rowKeyPrefix;

  /// Narrowest list width the table is used at (cards below it).
  final double tableMinWidth;

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
    this.extraHeaderAction,
    this.statTiles,
    this.chipOptions,
    this.chipMatches,
    this.tableColumns,
    this.rowCells,
    this.rowId,
    this.rowKeyPrefix = "item",
    this.tableMinWidth = 760,
    super.key,
  }) : assert(
            tableColumns == null || rowCells != null, 'a table needs rowCells');

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
            trailing: _headerActions(viewModel),
          ),
          if (widget.statTiles != null) ...[
            const SizedBox(height: AppTokens.gapMd),
            StatsStrip(tiles: widget.statTiles!(viewModel)),
          ],
          const SizedBox(height: AppTokens.gapMd),
          ListToolbar(
            // The hint names the code on purpose: the search is a
            // server-side prefix match on the code field, not on titles.
            search: ListSearchField(
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
            filters: [
              if (widget.chipOptions != null)
                FilterChipBar<String>(
                  options: widget.chipOptions!,
                  selected: viewModel.chipFilter,
                  onChanged: viewModel.setChipFilter,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(viewModel)),
          if (_chipActive(viewModel) &&
              !viewModel.isLoading &&
              viewModel.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "The filter applies to the ${viewModel.items.length} loaded. "
                "Load more to widen it.",
                key: const Key('paged_list_chip_note'),
                style: const TextStyle(fontSize: 12, color: AppTokens.inkFaint),
              ),
            ),
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

  /// The add button, after [PagedListScreen.extraHeaderAction] when given.
  Widget _headerActions(VM viewModel) {
    final Widget add = AddWidget(
      title: widget.addButtonLabel,
      addCall: () => _openAdd(viewModel),
    );
    final extra = widget.extraHeaderAction;
    if (extra == null) return add;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        extra(context, viewModel),
        const SizedBox(width: AppTokens.gapSm),
        add,
      ],
    );
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

    final List<T> loaded = viewModel.items;
    // A failed load or search: say so, with Retry, rather than "No X yet".
    final String? loadError = viewModel.loadError;
    if (loaded.isEmpty && loadError != null) {
      return ListErrorState(title: loadError, onRetry: viewModel.refresh);
    }

    final bool chipActive = _chipActive(viewModel);
    final List<T> items = chipActive
        ? loaded
            .where((item) => widget.chipMatches!(item, viewModel.chipFilter))
            .toList()
        : loaded;
    if (items.isEmpty) {
      return ListEmptyState(
        isFiltered: searchController.text.trim().isNotEmpty || chipActive,
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        filteredMessage: chipActive
            ? "Nothing loaded matches that filter."
            : widget.filteredMessage,
        addLabel: widget.emptyAddLabel,
        onAdd: () => _openAdd(viewModel),
      );
    }

    Widget cards(BuildContext context) => ListView.builder(
          padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              widget.itemBuilder(context, items[index], viewModel.refresh),
        );

    final List<AdminTableColumn>? columns = widget.tableColumns;
    if (columns == null) return cards(context);

    return WideOrNarrow(
      minWidth: widget.tableMinWidth,
      narrow: cards,
      wide: (context) => AdminTable(
        columns: columns,
        rowCount: items.length,
        rowKey: widget.rowId == null
            ? null
            : (i) => ValueKey(
                '${widget.rowKeyPrefix}_row_${widget.rowId!(items[i])}'),
        cellsBuilder: (context, i, hovered) =>
            widget.rowCells!(context, items[i], hovered, viewModel.refresh),
      ),
    );
  }

  /// Whether a chip other than "all" is narrowing the rows.
  bool _chipActive(VM viewModel) =>
      widget.chipMatches != null && viewModel.chipFilter != "all";
}
