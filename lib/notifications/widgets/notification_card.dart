import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// One row of the notification history: picture (if any), title, text,
/// link (if any), when it was sent and whether it went out. The title, text
/// and link can be selected, the copy button copies all of them in full,
/// and the link button opens the link in a new tab.
class NotificationCard extends StatelessWidget {
  /// The notification shown.
  final NotificationModel notification;

  /// Removes it from the history (asks first).
  final VoidCallback onDelete;

  const NotificationCard({
    required this.notification,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.gapMd),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbnail(),
          const SizedBox(width: AppTokens.gapMd),
          Expanded(child: _texts()),
          _actions(context),
        ],
      ),
    );
  }

  /// Open link (when there is one), Copy and Remove: side by side, or
  /// stacked on a phone, where side by side leaves the text too narrow for
  /// the status chip.
  Widget _actions(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 600;
    final VisualDensity density =
        narrow ? VisualDensity.compact : VisualDensity.standard;
    final List<Widget> buttons = [
      if (notification.hasLink)
        IconButton(
          key: const Key('notification_open_link'),
          tooltip: "Open link",
          visualDensity: density,
          onPressed: () => openExternalUrl(notification.url!.trim(),
              failureMessage: "Couldn't open the link"),
          icon: const Icon(Icons.open_in_new,
              size: 18, color: AppTokens.inkMuted),
        ),
      IconButton(
        key: const Key('notification_copy'),
        tooltip: notification.hasLink
            ? "Copy title, text and link"
            : "Copy title and text",
        visualDensity: density,
        onPressed: _copy,
        icon: const Icon(Icons.content_copy_outlined,
            size: 18, color: AppTokens.inkMuted),
      ),
      IconButton(
        tooltip: "Remove from history",
        visualDensity: density,
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline,
            size: 19, color: AppTokens.inkMuted),
      ),
    ];
    return narrow
        ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
        : Row(mainAxisSize: MainAxisSize.min, children: buttons);
  }

  /// Puts the title, the whole text (links typed into it included) and the
  /// link on the clipboard.
  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: notification.copyText));
    Helper.showSnackBarMessage(msg: "Copied to clipboard", isSuccess: true);
  }

  /// The picture, or a megaphone for a text-only notification.
  Widget _thumbnail() {
    final String? url = notification.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Container(
        width: 96,
        height: 54,
        color: AppTokens.surfaceMuted,
        child: notification.hasImage
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(
                    Icons.broken_image_outlined,
                    size: 20,
                    color: AppTokens.inkFaint),
              )
            : const Icon(Icons.campaign_outlined,
                size: 22, color: AppTokens.inkFaint),
      ),
    );
  }

  /// Title, text, link, then the status chip and time.
  Widget _texts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableLabel(
          notification.title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTokens.ink),
        ),
        if (notification.body.isNotEmpty) ...[
          const SizedBox(height: 3),
          SelectableLabel(
            notification.body,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 12.5, height: 1.35, color: AppTokens.inkMuted),
          ),
        ],
        if (notification.hasLink) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.link, size: 14, color: AppTokens.inkFaint),
              const SizedBox(width: 4),
              Expanded(
                child: SelectableLabel(
                  _shortLink(notification.url!),
                  key: const Key('notification_link'),
                  style:
                      const TextStyle(fontSize: 12, color: AppTokens.inkMuted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppTokens.gapSm),
        Wrap(
          spacing: AppTokens.gapSm,
          runSpacing: AppTokens.gapXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusChip(),
            Text(_when(),
                style:
                    const TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
          ],
        ),
      ],
    );
  }

  /// Sending / Sent / Failed (the failure reason on hover).
  Widget _statusChip() {
    switch (notification.status) {
      case NotificationStatus.sent:
        return const StatusChip(
          icon: Icons.check_circle_outline,
          label: "Sent",
          color: AppTokens.accentInk,
          filled: true,
        );
      case NotificationStatus.failed:
        return Tooltip(
          message: notification.error ?? "Unknown error",
          child: const StatusChip(
            icon: Icons.error_outline,
            label: "Failed",
            color: AppTokens.danger,
            filled: true,
          ),
        );
      case NotificationStatus.pending:
        return const StatusChip(
          icon: Icons.schedule,
          label: "Sending",
          color: AppTokens.inkMuted,
        );
    }
  }

  /// The link without `https://` or `www.`, which only take up room.
  static String _shortLink(String url) => url
      .trim()
      .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');

  /// "12 Oct 2026, 4:05 PM" — when it was sent, else when it was queued.
  String _when() {
    final DateTime? at = notification.sentAt ?? notification.createdAt;
    if (at == null) return "Just now";
    return DateFormat("d MMM yyyy, h:mm a").format(at.toLocal());
  }
}
