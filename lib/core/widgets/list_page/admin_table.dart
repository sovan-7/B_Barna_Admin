import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// One column of an [AdminTable].
class AdminTableColumn {
  /// Column title (shown upper-case, like the Teachers roster). Empty for a
  /// column with no title, such as the actions.
  final String label;

  /// Share of the flexible width; ignored when [width] is set.
  final int flex;

  /// A fixed width, for content with a set size (pills, switches, actions).
  final double? width;

  /// How the cell sits in its column.
  final Alignment alignment;

  const AdminTableColumn(
    this.label, {
    this.flex = 1,
    this.width,
    this.alignment = Alignment.centerLeft,
  });
}

/// Builds the cells of row [index], one per column. [hovered] is true while
/// the pointer is over the row (always true on compact screens, which have
/// no hover) — use it to fade in row actions.
typedef AdminTableCellsBuilder = List<Widget> Function(
    BuildContext context, int index, bool hovered);

/// The list on wide screens: a white box with a header row and one compact
/// row per item, every row laid out through the same columns so they line
/// up. The box is only as tall as its rows and scrolls once they no longer
/// fit; [footer] (e.g. "Load more") sits under the last row.
///
/// Built on the pattern of the Teachers roster table.
class AdminTable extends StatelessWidget {
  /// The columns, left to right.
  final List<AdminTableColumn> columns;

  /// Number of rows.
  final int rowCount;

  /// The cells of each row.
  final AdminTableCellsBuilder cellsBuilder;

  /// A stable key per row (e.g. the document id), so rows keep their state
  /// when the list changes.
  final Key Function(int index)? rowKey;

  /// Opens a row; rows are not tappable when null.
  final ValueChanged<int>? onRowTap;

  /// Shown under the last row.
  final Widget? footer;

  const AdminTable({
    required this.columns,
    required this.rowCount,
    required this.cellsBuilder,
    this.rowKey,
    this.onRowTap,
    this.footer,
    super.key,
  });

  /// Left/right padding inside the table.
  static const double sidePadding = 16;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.hairline),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              const Divider(height: 1, thickness: 1, color: AppTokens.hairline),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rowCount + (footer == null ? 0 : 1),
                  separatorBuilder: (context, index) => const Divider(
                      height: 1, thickness: 1, color: AppTokens.hairline),
                  itemBuilder: (context, index) {
                    if (index == rowCount) return footer!;
                    return _AdminTableRow(
                      key: rowKey?.call(index),
                      columns: columns,
                      onTap: onRowTap == null ? null : () => onRowTap!(index),
                      cells: (hovered) => cellsBuilder(context, index, hovered),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The column titles.
  Widget _header() {
    return Container(
      color: AppTokens.surfaceMuted.withValues(alpha: .6),
      padding:
          const EdgeInsets.symmetric(horizontal: sidePadding, vertical: 10),
      child: layoutColumns(columns, [
        for (final AdminTableColumn column in columns)
          Text(column.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: AppTokens.inkFaint)),
      ]),
    );
  }

  /// Lays [cells] out in [columns]: flexible ones share the free width,
  /// fixed ones keep theirs. The header and every row go through here.
  static Widget layoutColumns(
      List<AdminTableColumn> columns, List<Widget> cells) {
    assert(cells.length == columns.length,
        'AdminTable: ${cells.length} cells for ${columns.length} columns');
    final List<Widget> children = [];
    for (int i = 0; i < columns.length; i++) {
      final AdminTableColumn column = columns[i];
      if (i > 0) children.add(const SizedBox(width: AppTokens.gapMd));
      final Widget cell = Align(alignment: column.alignment, child: cells[i]);
      children.add(column.width != null
          ? SizedBox(width: column.width, child: cell)
          : Expanded(flex: column.flex, child: cell));
    }
    return Row(children: children);
  }
}

/// One row of an [AdminTable]: owns its hover state.
class _AdminTableRow extends StatefulWidget {
  final List<AdminTableColumn> columns;
  final List<Widget> Function(bool hovered) cells;
  final VoidCallback? onTap;

  const _AdminTableRow({
    required this.columns,
    required this.cells,
    this.onTap,
    super.key,
  });

  @override
  State<_AdminTableRow> createState() => _AdminTableRowState();
}

class _AdminTableRowState extends State<_AdminTableRow> {
  /// True while the mouse pointer is over the row.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool showHover = _hovered ||
        MediaQuery.sizeOf(context).width < AppTokens.compactBreakpoint;

    final Widget row = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      color: _hovered
          ? AppTokens.surfaceMuted.withValues(alpha: .7)
          : AppTokens.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AdminTable.sidePadding, vertical: 10),
      child: AdminTable.layoutColumns(widget.columns, widget.cells(showHover)),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: widget.onTap == null
          ? row
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: row),
    );
  }
}
