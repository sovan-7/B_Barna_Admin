import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// The notification history on wide screens: picture and text, what went
/// with it (picture, link), status (with the failure reason), when, and
/// open link / copy / remove.
class NotificationTable extends StatelessWidget {
  /// The notifications shown, already filtered.
  final List<NotificationModel> notifications;

  /// Removes one from the history (asks first).
  final ValueChanged<NotificationModel> onDelete;

  const NotificationTable(
      {required this.notifications, required this.onDelete, super.key});

  /// Narrowest list width the table is used at (cards below it).
  static const double minWidth = 820;

  static const List<AdminTableColumn> _columns = [
    AdminTableColumn("Notification", flex: 5),
    AdminTableColumn("Extras", width: 56),
    AdminTableColumn("Status", width: 190),
    AdminTableColumn("Sent", width: 150),
    AdminTableColumn("", width: 128, alignment: Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminTable(
      columns: _columns,
      rowCount: notifications.length,
      rowKey: (i) => ValueKey('notification_row_${notifications[i].docId}'),
      cellsBuilder: (context, i, hovered) {
        final NotificationModel n = notifications[i];
        return [
          _identity(n),
          Row(
            children: [
              if (n.hasImage)
                const Tooltip(
                    message: "Has a picture",
                    child: Icon(Icons.image_outlined,
                        size: 16, color: AppTokens.inkMuted)),
              if (n.hasImage && n.hasLink) const SizedBox(width: 6),
              if (n.hasLink)
                const Tooltip(
                    message: "Has a link",
                    child:
                        Icon(Icons.link, size: 16, color: AppTokens.inkMuted)),
              if (!n.hasImage && !n.hasLink) const TableText(null),
            ],
          ),
          notificationStatusCell(n),
          TableText(notificationWhen(n)),
          _actions(n),
        ];
      },
    );
  }

  /// Picture (or a megaphone), title and the first line of the text.
  Widget _identity(NotificationModel n) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm - 2),
          child: Container(
            width: 56,
            height: 34,
            color: AppTokens.surfaceMuted,
            child: n.hasImage
                ? Image.network(n.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => const Icon(
                        Icons.broken_image_outlined,
                        size: 16,
                        color: AppTokens.inkFaint))
                : const Icon(Icons.campaign_outlined,
                    size: 18, color: AppTokens.inkFaint),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableLabel(n.title,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink)),
              if (TableIdentity.hasText(n.body))
                Text(n.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTokens.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }

  /// Open link (when there is one), Copy and Remove.
  Widget _actions(NotificationModel n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (n.hasLink)
          IconButton(
            tooltip: "Open link",
            visualDensity: VisualDensity.compact,
            onPressed: () => openExternalUrl(n.url!.trim(),
                failureMessage: "Couldn't open the link"),
            icon: const Icon(Icons.open_in_new,
                size: 17, color: AppTokens.inkMuted),
          ),
        IconButton(
          key: Key('notification_copy_${n.docId}'),
          tooltip:
              n.hasLink ? "Copy title, text and link" : "Copy title and text",
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: n.copyText));
            Helper.showSnackBarMessage(
                msg: "Copied to clipboard", isSuccess: true);
          },
          icon: const Icon(Icons.content_copy_outlined,
              size: 17, color: AppTokens.inkMuted),
        ),
        IconButton(
          key: Key('notification_delete_${n.docId}'),
          tooltip: "Remove from history",
          visualDensity: VisualDensity.compact,
          onPressed: () => onDelete(n),
          icon: const Icon(Icons.delete_outline,
              size: 18, color: AppTokens.inkMuted),
        ),
      ],
    );
  }
}

/// Sent / Sending / Failed, with the failure reason written under it.
Widget notificationStatusCell(NotificationModel n) {
  switch (n.status) {
    case NotificationStatus.sent:
      return const StatusPill("Sent",
          tone: StatusTone.success, icon: Icons.check_rounded);
    case NotificationStatus.pending:
      return const StatusPill("Sending",
          tone: StatusTone.warning, icon: Icons.schedule);
    case NotificationStatus.failed:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const StatusPill("Failed",
              tone: StatusTone.danger, icon: Icons.error_outline),
          const SizedBox(height: 3),
          Text(n.error ?? "Unknown error",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTokens.dangerText)),
        ],
      );
  }
}

/// "12 Oct 2026, 4:05 PM" — when it was sent, else when it was queued.
String notificationWhen(NotificationModel n) {
  final DateTime? at = n.sentAt ?? n.createdAt;
  if (at == null) return "Just now";
  return DateFormat("d MMM yyyy, h:mm a").format(at.toLocal());
}
