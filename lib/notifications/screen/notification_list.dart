import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/notifications/screen/send_notification.dart';
import 'package:bbarna/notifications/viewModel/notifications_view_model.dart';
import 'package:bbarna/notifications/widgets/notification_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The notification history (sidebar module), newest first, with a button
/// to send a new one to every app user.
class NotificationList extends StatefulWidget {
  const NotificationList({super.key});

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<NotificationsViewModel>(context, listen: false)
          .getNotificationList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsViewModel>(builder: (context, vm, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Notifications",
            count: vm.notificationList.length,
            subtitle: "Sent to every app user's phone.",
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('notifications_refresh'),
                  tooltip: "Refresh",
                  onPressed: vm.isLoading ? null : vm.getNotificationList,
                  icon: const Icon(Icons.refresh,
                      size: 20, color: AppTokens.inkMuted),
                ),
                const SizedBox(width: AppTokens.gapXs),
                AddWidget(
                  // The full label crowds the title out on a phone.
                  title: MediaQuery.sizeOf(context).width < 600
                      ? "NEW"
                      : "NEW NOTIFICATION",
                  addCall: () => _openSend(vm),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.gapLg),
          Expanded(child: _body(vm)),
        ],
      );
    });
  }

  /// Skeleton rows while loading, the empty state when nothing was sent,
  /// otherwise the history.
  Widget _body(NotificationsViewModel vm) {
    if (vm.isLoading) {
      return const ListSkeleton(rowHeight: 92);
    }
    final String? loadError = vm.loadError;
    if (vm.notificationList.isEmpty && loadError != null) {
      return ListErrorState(title: loadError, onRetry: vm.getNotificationList);
    }
    if (vm.notificationList.isEmpty) {
      return ListEmptyState(
        icon: Icons.campaign_outlined,
        title: "No notifications sent yet",
        message: "Send a message or a banner to every app user's phone.",
        messageWidth: 320,
        addLabel: "Send a notification",
        addIcon: Icons.send_outlined,
        onAdd: () => _openSend(vm),
      );
    }

    final List<NotificationModel> list = vm.notificationList;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTokens.gapSm),
      itemBuilder: (context, index) => NotificationCard(
        key: ValueKey(list[index].docId),
        notification: list[index],
        onDelete: () => _confirmDelete(vm, list[index]),
      ),
    );
  }

  /// Opens the send page and, once something was sent, reloads the
  /// history: right away (it shows as "Sending") and again a few seconds
  /// later, by when the Cloud Function has usually marked it "Sent".
  void _openSend(NotificationsViewModel vm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SendNotification()),
    ).ifSaved(() async {
      await vm.getNotificationList();
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) await vm.getNotificationList();
    });
  }

  /// Asks before removing [notification] from the history.
  void _confirmDelete(
      NotificationsViewModel vm, NotificationModel notification) {
    RemoveAlert.showRemoveAlert(
      title: notification.title,
      description: "Remove it from the history? "
          "Phones that already received it keep it.",
      confirmLabel: "Remove",
      onPressYes: () async {
        // RemoveAlert never closes itself. It stays open, its confirm button
        // spinning, until the delete is done.
        final bool success = await vm.deleteNotification(notification.docId);
        Navigator.pop(navigatorKey.currentContext!);
        if (success) {
          Helper.showInfoMessage(msg: "Notification removed");
        }
      },
    );
  }
}
