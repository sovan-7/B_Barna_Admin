import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One count above a list: a small label over a large number, with an
/// optional caption under it ("↑ 12% vs October", "this month").
class StatTile extends StatelessWidget {
  /// What is counted ("Total", "Visible", …).
  final String label;

  /// The number, already formatted ("12", "₹1,84,350").
  final String value;

  /// Colour of [value]; ink when null. Use a status colour for counts that
  /// need doing (e.g. failed, missing notes).
  final Color? valueColor;

  /// A line under the number, or nothing.
  final String? caption;

  /// Colour of [caption]; faint ink when null.
  final Color? captionColor;

  const StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.caption,
    this.captionColor,
    super.key,
  });

  /// A tile for a whole-number count, grouped the Indian way ("2,318",
  /// "1,20,500"). A null [count] (still loading, or it failed) shows a
  /// dash.
  factory StatTile.count({
    required String label,
    required int? count,
    Color? valueColor,
    String? caption,
    Color? captionColor,
    Key? key,
  }) =>
      StatTile(
        label: label,
        value: count == null
            ? "—"
            : NumberFormat.decimalPattern('en_IN').format(count),
        valueColor: valueColor,
        caption: caption,
        captionColor: captionColor,
        key: key,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTokens.inkMuted)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTokens.ink)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5, color: captionColor ?? AppTokens.inkFaint)),
          ],
        ],
      ),
    );
  }
}

/// A row of [StatTile]s above a list. When the row gets too narrow for all
/// of them on one line they wrap two to a line.
class StatsStrip extends StatelessWidget {
  /// The tiles, left to right.
  final List<Widget> tiles;

  /// Narrowest width with every tile on one line.
  final double oneLineMinWidth;

  const StatsStrip({
    required this.tiles,
    this.oneLineMinWidth = 600,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= oneLineMinWidth) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: AppTokens.gapSm),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
      }
      final double half = (constraints.maxWidth - AppTokens.gapSm) / 2;
      return Wrap(
        spacing: AppTokens.gapSm,
        runSpacing: AppTokens.gapSm,
        children: [
          for (final Widget tile in tiles) SizedBox(width: half, child: tile)
        ],
      );
    });
  }
}
