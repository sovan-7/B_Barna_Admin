import 'dart:math' as math;

import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/subject_group/group_links.dart';
import 'package:bbarna/subject_group/model/group_message.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The student app's look for a group message (its default colour), so the
/// panel shows each message as students see it.
class GroupLook {
  const GroupLook._();

  /// The app's default colour: sender names and links.
  static const Color appColour = Color(0xFF042B6E);

  /// One message's card.
  static const Color card = Color(0xFFF1F2F6);

  /// The tick after a sender's name.
  static const Color verified = Color(0xFF1D9BF0);

  /// Role, time and date labels.
  static const Color muted = Color(0xFF8E8E93);

  /// Message text.
  static const Color text = Color(0xFF1C1C1E);
}

/// One message in a group's history:
///
/// ```
/// Riya Sen · Admin ✓                             [bin]
/// [picture]
/// Text, with links
///                                              9:05AM
/// ```
///
/// The bin shows on hover, and always on narrow windows (no hover on touch).
class GroupMessageTile extends StatefulWidget {
  final GroupMessage message;

  /// True while this message is being deleted (the bin spins).
  final bool deleting;

  /// Asks to delete this message (the page confirms first).
  final VoidCallback onDelete;

  const GroupMessageTile({
    required this.message,
    required this.deleting,
    required this.onDelete,
    super.key,
  });

  @override
  State<GroupMessageTile> createState() => _GroupMessageTileState();
}

class _GroupMessageTileState extends State<GroupMessageTile> {
  bool _hovered = false;

  GroupMessage get _message => widget.message;

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 900;
    final bool showDelete = _hovered || narrow || widget.deleting;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        decoration: BoxDecoration(
          color: GroupLook.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _hovered
                  ? AppTokens.inkFaint.withValues(alpha: .6)
                  : Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sender()),
                CardActions(
                  visible: showDelete,
                  buttons: [
                    if (widget.deleting)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTokens.danger),
                        ),
                      )
                    else
                      CardDeleteButton(
                        buttonKey: Key('group_delete_${_message.docId}'),
                        tooltip: "Delete message",
                        onTap: widget.onDelete,
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_message.hasImage) ...[
                    _picture(),
                    SizedBox(height: _message.hasText ? 8 : 2),
                  ],
                  if (_message.hasText) _MessageText(text: _message.text),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      DateFormat('h:mma')
                          .format(_message.createdAt ?? DateTime.now()),
                      style: const TextStyle(
                          fontSize: 11.5, color: GroupLook.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Riya Sen · Admin ✓" (just "Admin ✓" when no name was saved).
  Widget _sender() {
    final String role = _message.senderRole == "subadmin" ? "Teacher" : "Admin";
    final String name = _message.senderName;
    return Row(
      children: [
        Flexible(
          child: Text(
            name.isEmpty ? role : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GroupLook.appColour),
          ),
        ),
        if (name.isNotEmpty)
          Text("  ·  $role",
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: GroupLook.muted)),
        const SizedBox(width: 4),
        const Icon(Icons.verified, size: 15, color: GroupLook.verified),
      ],
    );
  }

  /// The picture at most 380 wide, in its own shape when known; click to
  /// open it full size in a new tab.
  Widget _picture() {
    final double? ratio = _message.imageAspectRatio;
    final Widget image = Image.network(
      _message.imageUrl,
      fit: ratio == null ? BoxFit.fitWidth : BoxFit.cover,
      alignment: Alignment.topCenter,
      width: double.infinity,
      errorBuilder: (context, error, stack) => Container(
        height: 120,
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child:
            const Icon(Icons.broken_image_outlined, color: AppTokens.inkFaint),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => openExternalUrl(_message.imageUrl,
              failureMessage: "Couldn't open the picture"),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ratio == null
                ? image
                : AspectRatio(aspectRatio: math.max(ratio, 0.75), child: image),
          ),
        ),
      ),
    );
  }
}

/// The message's text with its links clickable, as in the app.
class _MessageText extends StatefulWidget {
  final String text;

  const _MessageText({required this.text});

  @override
  State<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<_MessageText> {
  /// One per link; disposed with the text.
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final List<InlineSpan> spans = [];
    for (final TextPiece piece in splitLinks(widget.text)) {
      final Uri? link = piece.link;
      if (link == null) {
        spans.add(TextSpan(text: piece.text));
        continue;
      }
      final TapGestureRecognizer recognizer = TapGestureRecognizer()
        ..onTap = () => openExternalUrl(link.toString(),
            failureMessage: "Couldn't open the link");
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: piece.text,
        recognizer: recognizer,
        mouseCursor: SystemMouseCursors.click,
        style: const TextStyle(
            color: GroupLook.appColour,
            decoration: TextDecoration.underline,
            decorationColor: GroupLook.appColour),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      style:
          const TextStyle(fontSize: 14.5, height: 1.45, color: GroupLook.text),
    );
  }
}
