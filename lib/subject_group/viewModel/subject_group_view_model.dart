import 'dart:async';

import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/core/repo/storage_upload.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject_group/model/group_message.dart';
import 'package:bbarna/subject_group/repo/subject_group_repo.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/foundation.dart';

/// State and actions for one subject's group page: its messages (kept up
/// to date while the page is open), older ones on request, posting a
/// message with an optional picture, and deleting one.
///
/// One per page (the page creates and disposes it), so two groups never
/// show each other's messages.
class SubjectGroupViewModel extends ChangeNotifier with SafeNotifier {
  /// How many messages the window grows by.
  static const int pageSize = 30;

  /// Longest message the composer accepts.
  static const int maxTextLength = 2000;

  /// Shown, and saved, when a teacher's name can't be found.
  static const String fallbackName = "Admin";

  final SubjectGroupRepo _repo;

  /// The subject's code as stored; the group is keyed by it.
  final String subjectCode;

  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  SubjectGroupViewModel({required this.subjectCode, SubjectGroupRepo? repo})
      : _repo = repo ?? SubjectGroupRepo();

  String get groupId => groupIdFor(subjectCode);

  /// Newest first.
  List<GroupMessage> messages = [];

  /// True until the first messages arrive (drives the skeleton).
  bool isLoading = true;

  /// Why the messages could not be loaded, or null.
  String? loadError;

  /// True while a wider window of older messages is on its way.
  bool isLoadingOlder = false;

  /// True while a message is being posted.
  bool isSending = false;

  /// Messages being deleted right now (their bin shows a spinner).
  final Set<String> _deleting = {};

  /// True while the whole chat is being deleted (posting waits).
  bool isDeletingAll = false;

  int _limit = pageSize;
  StreamSubscription<List<GroupMessage>>? _subscription;
  String? _ownName;

  /// A full window came back, so there may be older messages.
  bool get hasOlder => messages.length >= _limit;

  bool isDeleting(String docId) => _deleting.contains(docId);

  /// Starts watching the newest messages.
  void start() {
    isLoading = messages.isEmpty;
    loadError = null;
    notifyListeners();
    _listen();
  }

  void retry() => start();

  /// Widens the window by [pageSize] older messages.
  void loadOlder() {
    if (isLoadingOlder || isLoading || !hasOlder) return;
    isLoadingOlder = true;
    _limit += pageSize;
    notifyListeners();
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _repo.watch(groupId, limit: _limit).listen(
      (List<GroupMessage> latest) {
        messages = latest;
        isLoading = false;
        isLoadingOlder = false;
        loadError = null;
        notifyListeners();
      },
      onError: (Object error) {
        isLoading = false;
        isLoadingOlder = false;
        // Messages already shown stay; an empty page offers Retry.
        if (messages.isEmpty) loadError = "Couldn't load this group";
        Helper.showSnackBarMessage(
            msg: "Error while loading the group", isSuccess: false);
        notifyListeners();
      },
    );
  }

  /// Posts [text] and/or [image] to the group.
  ///
  /// The picture is uploaded first; if that fails nothing is posted.
  /// Returns `false` (and shows a toast) on failure, or when there is
  /// nothing to post.
  Future<bool> send({required String text, Uint8List? image}) async {
    final String message = text.trim();
    if (isSending || (message.isEmpty && image == null)) return false;

    isSending = true;
    notifyListeners();
    try {
      UploadedImage? picture;
      if (image != null) {
        picture = await _repo.uploadImage(subjectCode, image);
      }
      await _repo.send(
        groupId,
        GroupMessage(
          text: message,
          imageUrl: picture?.url ?? "",
          imageWidth: picture?.width ?? 0,
          imageHeight: picture?.height ?? 0,
          senderId: Session.adminId ?? "",
          senderName: await _senderName(),
          senderRole: Session.isAdmin ? roleAdmin : roleSubadmin,
          subjectCode: subjectCode,
        ),
      );
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while sending the message", isSuccess: false);
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  /// The signed-in teacher's name, looked up once per page.
  Future<String> _senderName() async {
    final String? known = _ownName;
    if (known != null) return known;

    String name = fallbackName;
    final String? adminId = Session.adminId;
    if (adminId != null && adminId.isNotEmpty) {
      try {
        name = await _repo.teacherName(adminId) ?? fallbackName;
      } catch (_) {
        // Not worth failing the post over: it shows as "Admin".
      }
    }
    _ownName = name;
    return name;
  }

  /// Deletes [message] (students stop seeing it at once). Returns `false`
  /// (and shows a toast) on failure.
  Future<bool> delete(GroupMessage message) async {
    if (_deleting.contains(message.docId)) return false;
    _deleting.add(message.docId);
    notifyListeners();
    try {
      await _repo.delete(groupId, message);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the message", isSuccess: false);
      return false;
    } finally {
      _deleting.remove(message.docId);
      notifyListeners();
    }
  }

  /// Deletes the whole chat: every message, with its pictures. Students
  /// stop seeing them at once. Returns `false` (and shows a toast) on
  /// failure; whatever was deleted before it failed stays deleted.
  Future<bool> deleteAll() async {
    if (isDeletingAll) return false;
    isDeletingAll = true;
    notifyListeners();
    try {
      await _repo.deleteAll(groupId);
      return true;
    } catch (e) {
      Helper.showSnackBarMessage(
          msg: "Error while deleting the chat", isSuccess: false);
      return false;
    } finally {
      isDeletingAll = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
