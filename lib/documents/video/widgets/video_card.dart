import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/screen/edit_video.dart';
import 'package:bbarna/documents/video/viewModel/video_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the video list: play icon, title, code, description and the
/// video link; FREE/PAID chip; edit / delete buttons.
class VideoCard extends StatefulWidget {
  /// The item shown in this row.
  final VideoModel videoData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const VideoCard(
      {required this.videoData, required this.onChanged, super.key});

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  /// Shortcut for the item shown.
  VideoModel get _data => widget.videoData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) {
        final bool isCompact = layout.isCompact;
        final bool showActions = layout.showActions;
        return isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identity(),
                  const SizedBox(height: 10),
                  Row(children: [
                    _typeChip(),
                    const Spacer(),
                    _actions(showActions),
                  ]),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _identity()),
                  const SizedBox(width: AppTokens.gapMd),
                  _typeChip(),
                  const SizedBox(width: AppTokens.gapSm),
                  _actions(showActions),
                ],
              );
      },
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    final bool hasDescription = _data.description.trim().isNotEmpty &&
        _data.description != stringDefault;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A play glyph rather than a thumbnail: these are links, and there
        // is no stored image to show.
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.play_circle_outline,
              size: 20, color: Color(0xFFE0393E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SelectableLabel(
                      _data.title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodeChip(_data.code),
                ],
              ),
              if (hasDescription) ...[
                const SizedBox(height: 4),
                Text(_data.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.body),
              ],
              const SizedBox(height: 6),
              _linkRow(),
            ],
          ),
        ),
      ],
    );
  }

  /// The video link without its `https://www.` prefix, with a button that
  /// opens it.
  Widget _linkRow() {
    final String link = _data.link.trim();
    if (link.isEmpty || link == stringDefault) {
      return const Text("No link set",
          style: TextStyle(fontSize: 11.5, color: AppTokens.danger));
    }

    return Row(
      children: [
        const Icon(Icons.link, size: 13, color: AppTokens.inkFaint),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            link
                .replaceFirst(RegExp(r'^https?://'), '')
                .replaceFirst(RegExp(r'^www\.'), ''),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppTokens.inkMuted),
          ),
        ),
        const SizedBox(width: 6),
        Tooltip(
          message: "Open the video",
          child: InkWell(
            key: Key('video_open_${_data.docId}'),
            onTap: () => openExternalUrl(link,
                failureMessage: "Could not open that link"),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child:
                  Icon(Icons.open_in_new, size: 13, color: AppTokens.inkFaint),
            ),
          ),
        ),
      ],
    );
  }

  /// Green FREE / amber PAID chip.
  Widget _typeChip() {
    final bool isFree = _data.videoType.toUpperCase() == "FREE";
    final Color color =
        isFree ? const Color(0xFF108460) : const Color(0xFFB54708);
    final String label =
        _data.videoType.isEmpty || _data.videoType == stringDefault
            ? "No type"
            : _data.videoType.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFree ? Icons.lock_open_outlined : Icons.paid_outlined,
              size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: color)),
        ],
      ),
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('video_edit_${_data.docId}'),
          tooltip: "Edit video",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('video_delete_${_data.docId}'),
          tooltip: "Delete video",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the edit screen; the list reloads when it closes.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditVideo(videoData: _data)),
    ).whenComplete(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final VideoViewModel videoViewModel =
        Provider.of<VideoViewModel>(context, listen: false);
    final String docId = _data.docId;

    confirmDelete(
      title: _data.title,
      delete: () => videoViewModel.deleteVideo(docId),
      successMessage: "Video deleted successfully",
      onDeleted: widget.onChanged,
    );
  }
}
