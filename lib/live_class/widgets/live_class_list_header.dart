import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/widgets/live_class_agenda.dart';
import 'package:bbarna/live_class/widgets/live_class_card_parts.dart';
import 'package:bbarna/live_class/widgets/live_class_status_badge.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:flutter/material.dart';

/// Strip at the top of the class list while a class is running: the first
/// running class's title, time, teacher and "Ends in …", how many more are
/// running, and an Open stream button. Tapping it shows the Live tab.
class LiveClassLiveBanner extends StatelessWidget {
  /// The running classes, soonest-ending first (never empty).
  final List<LiveClassModel> liveClasses;

  /// Switches the list to the Live tab.
  final VoidCallback onShowLive;

  const LiveClassLiveBanner(
      {required this.liveClasses, required this.onShowLive, super.key});

  @override
  Widget build(BuildContext context) {
    final LiveClassModel first = liveClasses.first;
    final Color accent = LiveClassTheme.accentFor(LiveClassStatus.live);
    final int more = liveClasses.length - 1;
    final List<String> subjects = liveClassSubjectLabels(first);
    final String meta = [
      "${LiveClassFormat.time.format(first.startDateTime)} – "
          "${LiveClassFormat.time.format(first.endDateTime)}",
      if (first.teacherName.trim().isNotEmpty) first.teacherName.trim(),
      if (subjects.isNotEmpty) subjects.first,
      LiveClassFormat.relative(first),
    ].join(" · ");
    final BorderRadius radius = BorderRadius.circular(LiveClassTheme.radiusMd);

    return Material(
      key: const Key('live_class_live_banner'),
      color: accent.withValues(alpha: .05),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: accent.withValues(alpha: .35)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onShowLive,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              const LiveClassStatusBadge(status: LiveClassStatus.live),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(first.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: LiveClassTheme.ink)),
                    const SizedBox(height: 2),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: LiveClassTheme.inkMuted)),
                  ],
                ),
              ),
              if (more > 0) ...[
                const SizedBox(width: LiveClassTheme.gapSm),
                Text("+$more more",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent)),
              ],
              if (liveClassHasLink(first)) ...[
                const SizedBox(width: LiveClassTheme.gapSm),
                OutlinedButton.icon(
                  key: Key('live_class_open_stream_${first.docId}'),
                  onPressed: () => openExternalUrl(first.youtubeLink,
                      failureMessage: "Couldn't open the stream"),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text("Open stream"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LiveClassTheme.ink,
                    backgroundColor: LiveClassTheme.surface,
                    side: const BorderSide(color: LiveClassTheme.hairline),
                    textStyle: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(LiveClassTheme.radiusSm)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiles above the class list: classes today, in the next 7 days, finished
/// without notes, and (admins only) finished with the chat still there.
class LiveClassStatsStrip extends StatelessWidget {
  /// The counts.
  final LiveClassStats stats;

  /// Whether to show the "Chats to clear" tile (admins only).
  final bool showChats;

  const LiveClassStatsStrip(
      {required this.stats, required this.showChats, super.key});

  /// Narrowest width with every tile on one line.
  static const double _oneLineMinWidth = 600;

  /// Amber, for counts that need doing.
  static const Color _attention = Color(0xFFB54708);

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = [
      _tile(const Key('live_class_stat_today'), "Today", stats.today, null),
      _tile(const Key('live_class_stat_next_week'), "Next 7 days",
          stats.nextWeek, null),
      _tile(const Key('live_class_stat_missing_notes'), "Missing notes",
          stats.missingNotes, stats.missingNotes > 0 ? _attention : null),
      if (showChats)
        _tile(const Key('live_class_stat_chats'), "Chats to clear",
            stats.chatsToClear, null),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= _oneLineMinWidth) {
        return Row(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: LiveClassTheme.gapSm),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      }
      final double half = (constraints.maxWidth - LiveClassTheme.gapSm) / 2;
      return Wrap(
        spacing: LiveClassTheme.gapSm,
        runSpacing: LiveClassTheme.gapSm,
        children: [
          for (final Widget tile in tiles) SizedBox(width: half, child: tile)
        ],
      );
    });
  }

  /// One tile: a small label over a large number.
  Widget _tile(Key key, String label, int value, Color? color) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LiveClassTheme.surface,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: LiveClassTheme.inkMuted)),
          const SizedBox(height: 2),
          Text("$value",
              style: TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: color ?? LiveClassTheme.ink)),
        ],
      ),
    );
  }
}
