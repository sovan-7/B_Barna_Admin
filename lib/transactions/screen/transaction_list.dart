import 'dart:convert';

import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/repo/transaction_repo.dart';
import 'package:bbarna/transactions/transaction_csv.dart';
import 'package:bbarna/transactions/transaction_pdf.dart';
import 'package:bbarna/transactions/viewModel/transaction_view_model.dart';
import 'package:bbarna/transactions/widgets/transaction_card.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/money.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// The transaction list (sidebar module, admins only): every purchase from
/// the student app, newest first. Read-only: it can be searched, filtered
/// and exported, never changed.
class TransactionList extends StatefulWidget {
  const TransactionList({super.key});

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  /// Text in the search box.
  final TextEditingController _searchController = TextEditingController();

  /// Below this the header's buttons no longer fit beside the title.
  static const double _wideHeaderWidth = 760;

  /// True while an export is being made.
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final TransactionViewModel viewModel =
        Provider.of<TransactionViewModel>(context, listen: false);
    // Put back what was being searched when this list was last left.
    _searchController.text = viewModel.searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) viewModel.getTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionViewModel>(builder: (context, viewModel, child) {
      return ListPageFrame(
        children: [
          // The top section scrolls away with the rows, so it never runs out
          // of room on a short or narrow window.
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _top(viewModel)),
                ..._body(viewModel),
              ],
            ),
          ),
          if (!viewModel.isLoading && viewModel.loadError == null)
            PagedListFooter(
              // While searching the footer counts matches, not rows loaded.
              shown: viewModel.searchText.trim().isNotEmpty
                  ? viewModel.countFor(TransactionFilter.all)
                  : viewModel.loadedCount,
              total: viewModel.totalCount ?? viewModel.loadedCount,
              isSearching: viewModel.searchText.trim().isNotEmpty,
              hasMore: viewModel.hasMore,
              isLoadingMore: viewModel.isLoadingMore,
              pageSize: TransactionRepo.pageSize,
              onLoadMore: viewModel.loadMore,
            ),
        ],
      );
    });
  }

  /// Title, totals, search and filters.
  Widget _top(TransactionViewModel viewModel) {
    return LayoutBuilder(builder: (context, constraints) {
      // Too narrow to share a row with the title: the buttons go under it.
      final bool narrow = constraints.maxWidth < _wideHeaderWidth;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListPageHeader(
            title: "Transactions",
            count: viewModel.shown.length,
            subtitle: "Every purchase from the app, newest first.",
            trailing: narrow ? null : _headerActions(viewModel),
          ),
          if (narrow) ...[
            const SizedBox(height: AppTokens.gapSm),
            _headerActions(viewModel),
          ],
          const SizedBox(height: AppTokens.gapMd),
          _summary(viewModel),
          const SizedBox(height: AppTokens.gapMd),
          ListSearchField(
            controller: _searchController,
            hintText: "Name, phone, course, receipt or payment ID",
            maxWidth: 460,
            onChanged: viewModel.setSearch,
            onCleared: () => viewModel.setSearch(""),
          ),
          const SizedBox(height: AppTokens.gapSm),
          _filters(viewModel),
          const SizedBox(height: AppTokens.gapMd),
        ],
      );
    });
  }

  /// CSV, PDF and refresh. Exporting covers exactly the rows on screen.
  Widget _headerActions(TransactionViewModel viewModel) {
    final bool canExport =
        !_exporting && !viewModel.isLoading && viewModel.shown.isNotEmpty;
    return Wrap(
      spacing: AppTokens.gapSm,
      runSpacing: AppTokens.gapSm,
      alignment: WrapAlignment.end,
      children: [
        _outlinedButton(
          key: const Key('transactions_export_csv'),
          icon: Icons.table_view_outlined,
          label: "Export CSV",
          onPressed: canExport ? () => _exportCsv(viewModel) : null,
        ),
        _outlinedButton(
          key: const Key('transactions_export_pdf'),
          icon: Icons.picture_as_pdf_outlined,
          label: "Export PDF",
          onPressed: canExport ? () => _exportPdf(viewModel) : null,
        ),
        _outlinedButton(
          key: const Key('transactions_refresh'),
          icon: Icons.refresh,
          label: "Refresh",
          onPressed: viewModel.isLoading ? null : viewModel.getTransactions,
        ),
      ],
    );
  }

  Widget _outlinedButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTokens.ink,
        side: const BorderSide(color: AppTokens.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  /// Four tiles for the rows on screen, and a note saying what they cover
  /// so a partial total is never mistaken for all-time revenue.
  Widget _summary(TransactionViewModel viewModel) {
    final int shown = viewModel.shown.length;
    final bool partial = viewModel.hasMore ||
        (viewModel.totalCount != null &&
            viewModel.totalCount! > viewModel.loadedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final int columns = constraints.maxWidth < 560 ? 2 : 4;
          final double width =
              (constraints.maxWidth - AppTokens.gapSm * (columns - 1)) /
                  columns;
          return Wrap(
            spacing: AppTokens.gapSm,
            runSpacing: AppTokens.gapSm,
            children: [
              _tile(width, "Collected", formatRupees(viewModel.totalCollected)),
              _tile(width, "Paid",
                  "${viewModel.shown.where((t) => !t.isFree).length}"),
              _tile(width, "Free",
                  "${viewModel.shown.where((t) => t.isFree).length}"),
              _tile(width, "Discounts", formatRupees(viewModel.totalDiscounts)),
            ],
          );
        }),
        const SizedBox(height: 6),
        Text(
          "Totals for the $shown shown"
          "${partial ? ". Older purchases aren't loaded yet." : "."}",
          key: const Key('transactions_totals_note'),
          style: const TextStyle(fontSize: 11.5, color: AppTokens.inkFaint),
        ),
      ],
    );
  }

  Widget _tile(double width, String label, String value) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTokens.inkMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.ink)),
          ),
        ],
      ),
    );
  }

  /// "All 12 · Paid 10 · Free 2".
  Widget _filters(TransactionViewModel viewModel) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip(viewModel, TransactionFilter.all, "All"),
        _filterChip(viewModel, TransactionFilter.paid, "Paid"),
        _filterChip(viewModel, TransactionFilter.free, "Free"),
      ],
    );
  }

  Widget _filterChip(
      TransactionViewModel viewModel, TransactionFilter option, String label) {
    final bool selected = viewModel.filter == option;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        key: Key('transaction_filter_${option.name}'),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: () => viewModel.setFilter(option),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTokens.ink.withValues(alpha: .08)
                : AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
                color: selected
                    ? AppTokens.ink.withValues(alpha: .40)
                    : AppTokens.hairline),
          ),
          child: Text(
            "$label  ${viewModel.countFor(option)}",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppTokens.ink : AppTokens.inkMuted),
          ),
        ),
      ),
    );
  }

  /// Skeleton while loading, an error or empty state, otherwise the rows.
  List<Widget> _body(TransactionViewModel viewModel) {
    if (viewModel.isLoading) {
      return [_state(const ListSkeleton(rowHeight: 84, rowCount: 4))];
    }

    final List<TransactionModel> rows = viewModel.shown;
    final String? loadError = viewModel.loadError;
    if (rows.isEmpty && loadError != null) {
      return [
        _state(ListErrorState(
            title: loadError, onRetry: viewModel.getTransactions))
      ];
    }
    if (rows.isEmpty) {
      return [
        _state(ListEmptyState(
          isFiltered: viewModel.searchText.trim().isNotEmpty ||
              viewModel.filter != TransactionFilter.all,
          icon: Icons.receipt_long_outlined,
          title: "No transactions yet",
          message: "When a student buys or enrols in the app, it appears here.",
          filteredMessage: "No purchases match this search or filter.",
          messageWidth: 320,
        ))
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) => TransactionCard(
            key: ValueKey(rows[index].docId),
            transaction: rows[index],
          ),
        ),
      ),
    ];
  }

  /// A loading, error or empty state under the top section.
  Widget _state(Widget child) =>
      SliverToBoxAdapter(child: SizedBox(height: 380, child: child));

  // ---- Export -------------------------------------------------------------

  String get _dateStamp => DateFormat('yyyyMMdd').format(DateTime.now());

  Future<void> _exportCsv(TransactionViewModel viewModel) {
    final String csv = transactionsCsv(viewModel.shown);
    return _save(
      "B_Barna_Transactions_$_dateStamp.csv",
      'csv',
      // With a byte-order mark Excel opens it as UTF-8, so ₹ and Bengali
      // text survive.
      () async => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
    );
  }

  Future<void> _exportPdf(TransactionViewModel viewModel) {
    final DateTime now = DateTime.now();
    final List<TransactionModel> rows = viewModel.shown;
    final double collected = viewModel.totalCollected;
    final double discounts = viewModel.totalDiscounts;
    return _save(
      "${TransactionPdf.statementFileName(now)}.pdf",
      'pdf',
      () => TransactionPdf.statement(rows,
          totalCollected: collected, totalDiscounts: discounts, now: now),
    );
  }

  Future<void> _save(String name, String extension,
      Future<Uint8List> Function() makeBytes) async {
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = await makeBytes();
      await FilePicker.platform.saveFile(
        dialogTitle: "Save $name",
        fileName: name,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );
    } catch (_) {
      Helper.showSnackBarMessage(
          msg: "Couldn't save the file", isSuccess: false);
    }
    if (mounted) setState(() => _exporting = false);
  }
}
