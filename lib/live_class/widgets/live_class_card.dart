import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_card_parts.dart';
import 'package:bbarna/live_class/widgets/live_class_status_badge.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One class as a card: how the agenda shows a class on narrow screens
/// (wide screens use `LiveClassAgendaRow`).
///
/// Reading order is deliberate: status and "starts in 2 days" first (do I
/// care about this row at all?), then the title, then the schedule, then
/// the details. Actions stay hidden until the pointer is over the card so
/// a screen of twenty classes isn't a screen of forty icons — on touch,
/// where there is no hover, they are always shown.
class LiveClassCard extends StatefulWidget {
  /// The item shown in this row.
  final LiveClassModel liveClassData;

  /// Called after the card's Edit page pops, so the list can refresh.
  final Function onChanged;

  const LiveClassCard(
      {required this.liveClassData, required this.onChanged, super.key});

  @override
  State<LiveClassCard> createState() => _LiveClassCardState();
}

class _LiveClassCardState extends State<LiveClassCard> {
  /// True while the pointer is over it.
  bool _hovered = false;

  /// Shortcut for the item shown.
  LiveClassModel get _data => widget.liveClassData;

  /// Runs the list's refresh.
  void _changed() => widget.onChanged();

  @override
  Widget build(BuildContext context) {
    final LiveClassStatus status = _data.status;
    final Color accent = LiveClassTheme.accentFor(status);
    final bool isLive = status == LiveClassStatus.live;
    final bool isPast = status == LiveClassStatus.past;
    final bool canHover = MediaQuery.sizeOf(context).width > 900;
    final bool showActions = _hovered || !canHover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: LiveClassTheme.surface,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
          border: Border.all(
            color: isLive
                ? accent.withValues(alpha: .35)
                : _hovered
                    ? LiveClassTheme.inkFaint.withValues(alpha: .5)
                    : LiveClassTheme.hairline,
          ),
          boxShadow: _hovered
              ? LiveClassTheme.raisedShadow
              : LiveClassTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
            onTap: () => openEditLiveClass(context, _data, _changed),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status stripe — lets you scan a column of cards by
                    // colour alone, without reading a single badge.
                    Container(width: 4, color: accent),
                    Expanded(
                      child: Opacity(
                        // Past classes recede rather than disappear.
                        opacity: isPast ? .72 : 1,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: _content(status, accent, showActions),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card's body: status line, title, schedule and details.
  Widget _content(LiveClassStatus status, Color accent, bool showActions) {
    final bool hasDescription = liveClassHasDescription(_data);
    final bool hasLink = liveClassHasLink(_data);
    final bool hasPdf = _data.hasPdf;
    final bool uploadingPdf = context.select<LiveClassViewModel, bool>(
        (vm) => vm.isUploadingPdf(_data.docId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LiveClassStatusBadge(status: status),
            const SizedBox(width: LiveClassTheme.gapSm),
            Expanded(
              child: Text(
                LiveClassFormat.relative(_data),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: status == LiveClassStatus.live
                      ? accent
                      : LiveClassTheme.inkFaint,
                ),
              ),
            ),
            LiveClassRowActions(
                data: _data, visible: showActions, onChanged: _changed),
          ],
        ),
        const SizedBox(height: LiveClassTheme.gapSm),
        SelectableLabel(
          _data.title,
          maxLines: 2,
          style: LiveClassTheme.cardTitle,
        ),
        const SizedBox(height: 10),
        _scheduleRow(),
        const SizedBox(height: LiveClassTheme.gapSm),
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
            LiveClassDetailChip(
                icon: Icons.timelapse_outlined,
                label: LiveClassFormat.duration(
                    _data.startDateTime, _data.endDateTime)),
            if (_data.chatState != LiveClassChatState.none)
              LiveClassChatStateChip(data: _data),
            if (canDeleteLiveClassChat(_data))
              LiveClassDeleteChatButton(data: _data),
            if (canUploadLiveClassPdf(_data))
              LiveClassUploadPdfButton(data: _data, uploading: uploadingPdf),
          ],
        ),
        if (hasDescription) ...[
          const SizedBox(height: 10),
          Text(
            _data.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LiveClassTheme.body,
          ),
        ],
        if (hasLink || hasPdf) ...[
          // Takes up whatever height this card was stretched to beyond its
          // own content, so the link / PDF rows sit at the bottom.
          const Spacer(),
          const SizedBox(height: 12),
          if (hasLink) LiveClassLinkRow(data: _data),
          if (hasLink && hasPdf) const SizedBox(height: LiveClassTheme.gapSm),
          if (hasPdf) LiveClassPdfRow(data: _data, uploading: uploadingPdf),
        ],
      ],
    );
  }

  /// Date and start–end time of the class.
  Widget _scheduleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.calendar_today_outlined,
              size: 13, color: LiveClassTheme.inkFaint),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            LiveClassFormat.schedule(_data),
            style: LiveClassTheme.metaStrong,
          ),
        ),
      ],
    );
  }
}
