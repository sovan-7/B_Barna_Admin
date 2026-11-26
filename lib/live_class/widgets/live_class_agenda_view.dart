import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_agenda.dart';
import 'package:bbarna/live_class/widgets/live_class_card.dart';
import 'package:bbarna/live_class/widgets/live_class_card_parts.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Narrowest width that gets agenda rows rather than cards.
const double liveClassAgendaRowMinWidth = 720;

/// Key on a day's heading: `live_class_day_2026-11-26`.
Key liveClassDayKey(DateTime day) =>
    Key('live_class_day_${DateFormat('yyyy-MM-dd').format(day)}');

/// The classes of one tab as an agenda: grouped under a heading per day
/// ("Today · Wed 26 Nov"), in the order given.
///
/// With room for it, each day is a white box of compact rows
/// ([LiveClassAgendaRow]); narrower, each class is a [LiveClassCard] under
/// the day's heading.
class LiveClassAgenda extends StatelessWidget {
  /// The classes shown, already sorted for the tab.
  final List<LiveClassModel> classes;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const LiveClassAgenda(
      {required this.classes, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    final List<LiveClassDay> days = groupByDay(classes);
    return LayoutBuilder(builder: (context, constraints) {
      final bool asRows = constraints.maxWidth >= liveClassAgendaRowMinWidth;
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: LiveClassTheme.gapMd),
        itemCount: days.length,
        // Each day repaints on its own (e.g. a live badge's pulse).
        itemBuilder: (context, index) => RepaintBoundary(
          child: asRows ? _dayBox(days[index]) : _dayCards(days[index]),
        ),
      );
    });
  }

  /// "3 classes" / "1 class".
  static String _countLabel(int count) =>
      count == 1 ? "1 class" : "$count classes";

  /// One day as a white box: heading, then a row per class.
  Widget _dayBox(LiveClassDay day) {
    return Container(
      margin: const EdgeInsets.only(bottom: LiveClassTheme.gapMd),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LiveClassTheme.surface,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        border: Border.all(color: LiveClassTheme.hairline),
        boxShadow: LiveClassTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: liveClassDayKey(day.day),
            color: LiveClassTheme.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    LiveClassFormat.dayHeading(day.day),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LiveClassTheme.ink),
                  ),
                ),
                Text(_countLabel(day.classes.length),
                    style: const TextStyle(
                        fontSize: 12, color: LiveClassTheme.inkFaint)),
              ],
            ),
          ),
          // Each row sits in its own unkeyed Column, so two classes that
          // share an id never become keyed siblings.
          for (final LiveClassModel liveClass in day.classes)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(
                    height: 1, thickness: 1, color: LiveClassTheme.hairline),
                LiveClassAgendaRow(
                  key: ValueKey(liveClass.docId),
                  liveClassData: liveClass,
                  onChanged: onChanged,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// One day on a narrow screen: heading, then a card per class.
  Widget _dayCards(LiveClassDay day) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: liveClassDayKey(day.day),
          padding: const EdgeInsets.only(top: 2, bottom: LiveClassTheme.gapSm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  LiveClassFormat.dayHeading(day.day),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LiveClassTheme.ink),
                ),
              ),
              Text(_countLabel(day.classes.length),
                  style: const TextStyle(
                      fontSize: 12, color: LiveClassTheme.inkFaint)),
            ],
          ),
        ),
        for (final LiveClassModel liveClass in day.classes)
          Padding(
            padding: const EdgeInsets.only(bottom: LiveClassTheme.gapMd),
            child: LiveClassCard(
              key: ValueKey(liveClass.docId),
              liveClassData: liveClass,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

/// One class in the agenda on wide screens: its time, a status stripe, the
/// title and details, then "Starts in 4h" and the edit/delete icons.
/// Tapping the row opens Edit.
class LiveClassAgendaRow extends StatefulWidget {
  /// The class shown.
  final LiveClassModel liveClassData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const LiveClassAgendaRow(
      {required this.liveClassData, required this.onChanged, super.key});

  @override
  State<LiveClassAgendaRow> createState() => _LiveClassAgendaRowState();
}

class _LiveClassAgendaRowState extends State<LiveClassAgendaRow> {
  /// Width of the time column.
  static const double _timeWidth = 104;

  /// Widest the link / PDF rows get.
  static const double _attachmentMaxWidth = 420;

  /// True while the pointer is over the row.
  bool _hovered = false;

  /// Shortcut for the class shown.
  LiveClassModel get _data => widget.liveClassData;

  @override
  Widget build(BuildContext context) {
    final LiveClassStatus status = _data.status;
    final Color accent = LiveClassTheme.accentFor(status);
    final bool isPast = status == LiveClassStatus.past;
    // Touch screens have no hover, so there the icons always show (the
    // same rule as the card).
    final bool showActions =
        _hovered || MediaQuery.sizeOf(context).width <= 900;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? LiveClassTheme.surfaceMuted
            : status == LiveClassStatus.live
                ? LiveClassTheme.tintFor(status).withValues(alpha: .05)
                : LiveClassTheme.surface,
        child: InkWell(
          onTap: () => openEditLiveClass(context, _data, widget.onChanged),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: isPast ? .72 : 1,
                    child: SizedBox(width: _timeWidth, child: _timeColumn()),
                  ),
                  const SizedBox(width: 12),
                  // Status stripe: scan a day by colour alone.
                  Container(width: 3, color: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Opacity(
                      // Past classes recede rather than disappear.
                      opacity: isPast ? .72 : 1,
                      child: _details(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _trailing(status, accent, showActions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Start time, end time and length. A class that runs past midnight
  /// names the end date too.
  Widget _timeColumn() {
    final DateTime start = _data.startDateTime;
    final DateTime end = _data.endDateTime;
    final bool sameDay = dayOf(start) == dayOf(end);
    final String endLabel = sameDay
        ? LiveClassFormat.time.format(end)
        : "${LiveClassFormat.dateShort.format(end)}, "
            "${LiveClassFormat.time.format(end)}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LiveClassFormat.time.format(start),
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: LiveClassTheme.ink)),
        const SizedBox(height: 2),
        Text("to $endLabel",
            style:
                const TextStyle(fontSize: 12, color: LiveClassTheme.inkMuted)),
        const SizedBox(height: 2),
        Text(LiveClassFormat.duration(start, end),
            style: const TextStyle(
                fontSize: 11.5, color: LiveClassTheme.inkFaint)),
      ],
    );
  }

  /// Title, chips, description and the link / PDF rows.
  Widget _details() {
    final bool hasLink = liveClassHasLink(_data);
    final bool hasPdf = _data.hasPdf;
    final bool uploadingPdf = context.select<LiveClassViewModel, bool>(
        (vm) => vm.isUploadingPdf(_data.docId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableLabel(
          _data.title,
          maxLines: 2,
          style: LiveClassTheme.cardTitle.copyWith(fontSize: 14.5),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: LiveClassTheme.gapSm,
          runSpacing: LiveClassTheme.gapXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LiveClassTypeChip(data: _data),
            if (liveClassSubjectLabels(_data).isNotEmpty)
              LiveClassSubjectsChip(data: _data),
            LiveClassDetailChip(
                icon: Icons.person_outline, label: _data.teacherName),
            if (_data.chatState != LiveClassChatState.none)
              LiveClassChatStateChip(data: _data),
            if (canDeleteLiveClassChat(_data))
              LiveClassDeleteChatButton(data: _data),
            if (canUploadLiveClassPdf(_data))
              LiveClassUploadPdfButton(data: _data, uploading: uploadingPdf),
          ],
        ),
        if (liveClassHasDescription(_data)) ...[
          const SizedBox(height: 6),
          Text(
            _data.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LiveClassTheme.body,
          ),
        ],
        if (hasLink || hasPdf) ...[
          const SizedBox(height: LiveClassTheme.gapSm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _attachmentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasLink) LiveClassLinkRow(data: _data),
                if (hasLink && hasPdf) const SizedBox(height: 6),
                if (hasPdf)
                  LiveClassPdfRow(data: _data, uploading: uploadingPdf),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// "Starts in 4h" (red while running) above the edit/delete icons.
  Widget _trailing(LiveClassStatus status, Color accent, bool showActions) {
    final bool isLive = status == LiveClassStatus.live;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              LiveClassFormat.relative(_data),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isLive ? accent : LiveClassTheme.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LiveClassRowActions(
            data: _data, visible: showActions, onChanged: widget.onChanged),
      ],
    );
  }
}
