import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One row of the notification history: picture (if any), title, text,
/// when it was sent and whether it went out.
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
          IconButton(
            tooltip: "Remove from history",
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                size: 19, color: AppTokens.inkMuted),
          ),
        ],
      ),
    );
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

  /// Title, text, then the status chip and time.
  Widget _texts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTokens.ink),
        ),
        if (notification.body.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            notification.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5, height: 1.35, color: AppTokens.inkMuted),
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
          color: Color(0xFF079455),
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

  /// "12 Oct 2026, 4:05 PM" — when it was sent, else when it was queued.
  String _when() {
    final DateTime? at = notification.sentAt ?? notification.createdAt;
    if (at == null) return "Just now";
    return DateFormat("d MMM yyyy, h:mm a").format(at.toLocal());
  }
}
