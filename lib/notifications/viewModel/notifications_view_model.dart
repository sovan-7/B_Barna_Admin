import 'dart:typed_data';

import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/notifications/model/notification_model.dart';
import 'package:bbarna/notifications/repo/notifications_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/material.dart';

/// State and actions for the Notifications module: the history of sent
/// notifications, sending a new one (with an optional picture) and removing
/// one from the history.
class NotificationsViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final NotificationsRepo _repo;
  NotificationsViewModel({NotificationsRepo? notificationsRepo})
      : _repo = notificationsRepo ?? NotificationsRepo();

  /// Past notifications, newest first.
  List<NotificationModel> notificationList = [];

  /// True while the history is loading (drives the skeleton rows). Starts
  /// true so the first frame shows placeholders rather than "nothing sent
  /// yet".
  bool isLoading = true;

  /// Why the history could not be loaded, or null.
  String? loadError;

  /// Loads the history into [notificationList].
  Future<void> getNotificationList() async {
    // Skeleton only when nothing is on screen yet; otherwise keep the
    // current rows visible while refreshing.
    isLoading = notificationList.isEmpty;
    loadError = null;
    notifyListeners();
    try {
      notificationList = await _repo.getNotifications();
    } catch (e) {
      loadError = "Couldn't load notifications";
      Helper.showSnackBarMessage(
          msg: "Error while fetching notifications", isSuccess: false);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a notification to every app user.
  ///
  /// The picture is either [newImage] (uploaded first) or
  /// [existingImageUrl] (e.g. a banner that is already uploaded); neither
  /// means a text-only notification. If the upload fails nothing is sent.
  /// Returns `false` (and shows a toast) on failure.
  Future<bool> sendNotification({
    required String title,
    required String body,
    Uint8List? newImage,
    String? existingImageUrl,
  }) async {
    try {
      String? imageUrl = existingImageUrl;
      if (newImage != null) {
        imageUrl = await _repo.uploadImage(newImage);
      }
      await _repo.send(NotificationModel(
        title: title.trim(),
        body: body.trim(),
        imageUrl: imageUrl,
        createdBy: Session.adminId,
      ));
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while sending the notification", isSuccess: false);
      return false;
    }
  }

  /// Removes [docId] from the history. Returns `false` (and shows a toast)
  /// on failure.
  Future<bool> deleteNotification(String docId) async {
    try {
      await _repo.delete(docId);
      // Drop it locally instead of refetching the history.
      notificationList =
          notificationList.where((n) => n.docId != docId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the notification", isSuccess: false);
      return false;
    }
  }
}
