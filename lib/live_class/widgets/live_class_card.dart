import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/screen/edit_live_class.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_status_badge.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One class in the list.
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
  bool _hovered = false;

  LiveClassModel get _data => widget.liveClassData;

  @override
  Widget build(BuildContext context) {
    final LiveClassStatus status = _data.status;
    final Color accent = LiveClassTheme.accentFor(status);
    final bool isLive = status == LiveClassStatus.live;
    final bool isPast = status == LiveClassStatus.past;
    final bool canHover = MediaQuery.of(context).size.width > 900;
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
            onTap: _openEdit,
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
    final bool hasDescription = _data.description.trim().isNotEmpty &&
        _data.description != stringDefault;
    final bool hasLink = _data.youtubeLink.trim().isNotEmpty &&
        _data.youtubeLink != stringDefault;

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
            _actions(showActions),
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
            _chip(Icons.person_outline, _data.teacherName),
            _chip(
                Icons.timelapse_outlined,
                LiveClassFormat.duration(
                    _data.startDateTime, _data.endDateTime)),
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
        if (hasLink) ...[
          // Takes up whatever height this card was stretched to beyond its
          // own content, so the link row lands on the same line in every
          // card of the row instead of floating directly under a shorter
          // block of text.
          const Spacer(),
          const SizedBox(height: 12),
          _linkRow(),
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

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LiveClassTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: LiveClassTheme.inkFaint),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: LiveClassTheme.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// The link is selectable rather than a plain label — copying the URL out
  /// to check a stream is the single most common thing an admin does here.
  Widget _linkRow() {
    return Container(
      key: Key('live_class_link_${_data.docId}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LiveClassTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline,
              size: 15, color: Color(0xFFE0393E)),
          const SizedBox(width: 7),
          Expanded(
            child: SelectableText(
              LiveClassFormat.shortLink(_data.youtubeLink),
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: LiveClassTheme.inkMuted,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton(
              key: Key('live_class_edit_${_data.docId}'),
              icon: Icons.edit_outlined,
              tooltip: "Edit class",
              color: LiveClassTheme.inkMuted,
              onTap: _openEdit,
            ),
            const SizedBox(width: 2),
            _iconButton(
              key: Key('live_class_delete_${_data.docId}'),
              icon: Icons.delete_outline,
              tooltip: "Delete class",
              color: LiveClassTheme.danger,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  /// A small tappable icon with a tooltip.
  Widget _iconButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  /// Opens the edit screen; the list reloads when it closes.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditLiveClass(liveClassData: _data),
      ),
    ).whenComplete(() => widget.onChanged());
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete(BuildContext context) {
    final LiveClassViewModel liveClassViewModel =
        Provider.of<LiveClassViewModel>(context, listen: false);
    RemoveAlert.showRemoveAlert(
      title: _data.title,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        // RemoveAlert never closes itself — and it is dismissed *before* the
        // delete so there is no second route in flight for the refresh
        // below to race with. The list's own inline spinner covers the wait.
        Navigator.pop(navigatorKey.currentContext!);
        final bool success =
            await liveClassViewModel.deleteLiveClass(_data.docId);
        if (success) {
          Helper.showInfoMessage(msg: "Class deleted successfully");
          await liveClassViewModel.getLiveClassList();
        }
      },
    );
  }
}
