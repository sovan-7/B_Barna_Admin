import 'dart:async';

import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Asks "Are you sure want to delete ?" about [title], and if confirmed:
///
/// 1. closes the dialog (before deleting, so no second route is in flight),
/// 2. runs [delete] — a view-model call that returns `true` on success and
///    shows its own error toast on failure,
/// 3. on success shows [successMessage] and then runs [onDeleted] (usually
///    a list refresh).
void confirmDelete({
  required String title,
  required Future<bool> Function() delete,
  required String successMessage,
  FutureOr<void> Function()? onDeleted,
}) {
  RemoveAlert.showRemoveAlert(
    title: title,
    description: "Are you sure want to delete ?",
    onPressYes: () async {
      Navigator.pop(navigatorKey.currentContext!);
      final bool success = await delete();
      if (success) {
        Helper.showInfoMessage(msg: successMessage);
        await onDeleted?.call();
      }
    },
  );
}

/// Opens [url] in the browser / system handler. Shows [failureMessage] as an
/// error toast if the URL is invalid or cannot be opened.
Future<void> openExternalUrl(String url,
    {required String failureMessage}) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri)) {
    Helper.showSnackBarMessage(msg: failureMessage, isSuccess: false);
  }
}
