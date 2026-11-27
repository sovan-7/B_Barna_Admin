import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Pieces the Videos, PDFs and Audio tables share, so the three read the
/// same.

/// Whether a stored access type means free.
bool isFreeType(String type) => type.trim().toUpperCase() == "FREE";

/// Green Free / amber Paid pill (grey when the type was never set).
Widget accessPill(String type) {
  final String upper = type.trim().toUpperCase();
  if (upper.isEmpty || type == stringDefault) {
    return const StatusPill("No type");
  }
  return upper == "FREE"
      ? const StatusPill("Free",
          tone: StatusTone.success, icon: Icons.lock_open_outlined)
      : const StatusPill("Paid",
          tone: StatusTone.warning, icon: Icons.paid_outlined);
}

/// All / Free / Paid chips, keyed `<prefix>_filter_<value>`.
List<FilterOption<String>> accessChipOptions(String prefix) => [
      FilterOption("all", "All", key: Key('${prefix}_filter_all')),
      FilterOption("free", "Free", key: Key('${prefix}_filter_free')),
      FilterOption("paid", "Paid", key: Key('${prefix}_filter_paid')),
    ];

/// Whether an item with access [type] shows under chip [filter].
bool accessChipMatches(String type, String filter) =>
    filter == "free" ? isFreeType(type) : !isFreeType(type);

/// Total / Free / Paid / Added this month tiles from a media view model's
/// [total] and `stats` (see `mediaStats`).
List<Widget> mediaStatTiles(String prefix, int total, Map<String, int> stats) {
  return [
    StatTile.count(
        key: Key('${prefix}_stat_total'), label: "Total", count: total),
    StatTile.count(
        key: Key('${prefix}_stat_free'),
        label: "Free",
        count: stats["free"],
        valueColor: AppTokens.successText),
    StatTile.count(
        key: Key('${prefix}_stat_paid'),
        label: "Paid",
        count: stats["paid"],
        valueColor: AppTokens.warningText),
    StatTile.count(
        key: Key('${prefix}_stat_month'),
        label: "Added this month",
        count: stats["month"]),
  ];
}

/// "26 Nov 2026" from epoch milliseconds, or a dash when unset.
Widget addedCell(int timeStamp) {
  if (timeStamp <= 0) return const TableText(null);
  return TableText(DateFormat('d MMM y')
      .format(DateTime.fromMillisecondsSinceEpoch(timeStamp)));
}

/// A small "open the link" button (same key as the card's), or a red note
/// when the item has no link.
Widget openLinkCell(String link, Key key, String tooltip) {
  final String trimmed = link.trim();
  if (trimmed.isEmpty || trimmed == stringDefault) {
    return const Text("No link",
        style: TextStyle(fontSize: 11.5, color: AppTokens.danger));
  }
  return Tooltip(
    message: tooltip,
    child: InkWell(
      key: key,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      onTap: () =>
          openExternalUrl(trimmed, failureMessage: "Could not open that link"),
      child: const Padding(
        padding: EdgeInsets.all(5),
        child: Icon(Icons.open_in_new, size: 16, color: AppTokens.inkMuted),
      ),
    ),
  );
}

/// The media name cell: a coloured icon tile, title and description.
Widget mediaIdentity(
    {required String title,
    required String description,
    required IconData icon,
    required Color color}) {
  return TableIdentity(
      title: title, subtitle: description, icon: icon, iconColor: color);
}

/// Columns every media table starts with; [extra] go before the actions.
List<AdminTableColumn> mediaColumns(String itemLabel,
        {List<AdminTableColumn> extra = const []}) =>
    [
      AdminTableColumn(itemLabel, flex: 5),
      const AdminTableColumn("Code", width: 130),
      const AdminTableColumn("Access", width: 84),
      ...extra,
      const AdminTableColumn("Added", width: 96),
      const AdminTableColumn("Link", width: 44, alignment: Alignment.center),
      const AdminTableColumn("", width: 76, alignment: Alignment.centerRight),
    ];
