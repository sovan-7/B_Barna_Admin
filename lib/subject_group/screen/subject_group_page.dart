import 'dart:typed_data';

import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject_group/model/group_message.dart';
import 'package:bbarna/subject_group/repo/subject_group_repo.dart';
import 'package:bbarna/subject_group/viewModel/subject_group_view_model.dart';
import 'package:bbarna/subject_group/widgets/group_composer.dart';
import 'package:bbarna/subject_group/widgets/group_message_tile.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// A subject's group: the messages its students see in the app's Group tab
/// (newest at the bottom, as in the app), and the box to post a new one.
/// Opened from the Group button on a row of the Subjects list.
///
/// Groups are kept per subject code, so a subject listed under two courses
/// with the same code shares one group.
class SubjectGroupPage extends StatelessWidget {
  final SubjectModel subject;

  /// Data source; tests pass a mock.
  final SubjectGroupRepo? repo;

  /// Picks a picture; tests pass their own instead of the file picker.
  final Future<Uint8List?> Function()? pickImage;

  const SubjectGroupPage(
      {required this.subject, this.repo, this.pickImage, super.key});

  /// Position of Subjects in the sidebar.
  static const int sidebarIndex = 2;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SubjectGroupViewModel>(
      create: (_) =>
          SubjectGroupViewModel(subjectCode: subject.code, repo: repo)..start(),
      child: AdminFormScaffold(
        headerTitle: "Subjects",
        sidebarIndex: sidebarIndex,
        body: (context, width) =>
            _GroupBody(subject: subject, width: width, pickImage: pickImage),
      ),
    );
  }
}

class _GroupBody extends StatelessWidget {
  final SubjectModel subject;
  final double width;
  final Future<Uint8List?> Function()? pickImage;

  const _GroupBody(
      {required this.subject, required this.width, required this.pickImage});

  @override
  Widget build(BuildContext context) {
    final double side = formPagePadding(width);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 24, side, 18),
          child: Consumer<SubjectGroupViewModel>(
            builder: (context, vm, child) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, vm),
                const SizedBox(height: AppTokens.gapLg),
                Expanded(child: _history(context, vm)),
                const SizedBox(height: AppTokens.gapMd),
                GroupComposer(
                  isSending: vm.isSending,
                  // A post sent mid-way would be deleted with the rest.
                  enabled: !vm.isDeletingAll,
                  pickImage: pickImage,
                  onSend: (text, image) => vm.send(text: text, image: image),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, SubjectGroupViewModel vm) {
    final String name =
        subject.name == stringDefault ? "this subject" : subject.name;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormBackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text("Group · $name",
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.pageTitle),
                  ),
                  const SizedBox(width: 10),
                  CodeChip(subject.code),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                  "Students who bought this subject see these messages in "
                  "the app, in its Group tab.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        // Only when there is something to delete.
        if (vm.messages.isNotEmpty) ...[
          const SizedBox(width: AppTokens.gapMd),
          _deleteAllButton(vm, name),
        ],
      ],
    );
  }

  /// "Delete all messages" in red; just the icon on narrow windows.
  Widget _deleteAllButton(SubjectGroupViewModel vm, String name) {
    final VoidCallback? onTap =
        vm.isDeletingAll ? null : () => _confirmDeleteAll(vm, name);
    final Widget icon = vm.isDeletingAll
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTokens.danger),
          )
        : const Icon(Icons.delete_sweep_outlined, size: 19);

    if (width < 700) {
      return IconButton(
        key: const Key('group_delete_all'),
        tooltip: "Delete all messages",
        onPressed: onTap,
        color: AppTokens.danger,
        icon: icon,
      );
    }
    return OutlinedButton.icon(
      key: const Key('group_delete_all'),
      onPressed: onTap,
      icon: icon,
      label: const Text("Delete all messages"),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTokens.danger,
        disabledForegroundColor: AppTokens.danger.withValues(alpha: .6),
        side: BorderSide(color: AppTokens.danger.withValues(alpha: .35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
    );
  }

  void _confirmDeleteAll(SubjectGroupViewModel vm, String name) {
    RemoveAlert.showRemoveAlert(
      title: "Delete all messages in this group?",
      description: "Every message in the $name group, with its pictures, "
          "is deleted. Students stop seeing them in the app straight away. "
          "This can't be undone.",
      confirmLabel: "Delete all",
      onPressYes: () async {
        final bool deleted = await vm.deleteAll();
        Navigator.pop(navigatorKey.currentContext!);
        if (deleted) Helper.showInfoMessage(msg: "Chat deleted");
      },
    );
  }

  /// The white panel with the messages, newest at the bottom.
  Widget _history(BuildContext context, SubjectGroupViewModel vm) {
    Widget content;
    if (vm.messages.isEmpty && vm.isLoading) {
      content = const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    } else if (vm.messages.isEmpty && vm.loadError != null) {
      content = ListErrorState(title: vm.loadError!, onRetry: vm.retry);
    } else if (vm.messages.isEmpty) {
      content = const _EmptyGroup();
    } else {
      content = _messageList(context, vm);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: content,
      ),
    );
  }

  Widget _messageList(BuildContext context, SubjectGroupViewModel vm) {
    // Newest first, as the list is upside down: each day's messages, then
    // its date, which therefore shows above them.
    final List<Widget> rows = [];
    final DateTime now = DateTime.now();
    final List<GroupMessage> messages = vm.messages;
    for (int i = 0; i < messages.length; i++) {
      final GroupMessage message = messages[i];
      rows.add(GroupMessageTile(
        key: ValueKey(message.docId),
        message: message,
        deleting: vm.isDeleting(message.docId),
        onDelete: () => _confirmDelete(vm, message),
      ));
      final DateTime day = message.createdAt ?? now;
      final bool oldestOfDay = i == messages.length - 1 ||
          !_sameDay(messages[i + 1].createdAt ?? now, day);
      if (oldestOfDay) rows.add(_DayLabel(_dayLabel(day, now)));
    }
    rows.add(_top(vm));

    // Upside down, so a long group opens at its newest message. A few
    // messages start at the top of the panel instead of its bottom, as in
    // the app.
    return Align(
      alignment: Alignment.topCenter,
      child: ListView(
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        children: rows,
      ),
    );
  }

  /// Above the oldest message: "Load older messages", or a spinner.
  Widget _top(SubjectGroupViewModel vm) {
    if (vm.isLoadingOlder) {
      return const Padding(
        padding: EdgeInsets.only(top: 18),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      );
    }
    if (!vm.hasOlder) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: TextButton.icon(
          key: const Key('group_load_older'),
          onPressed: vm.loadOlder,
          icon: const Icon(Icons.history, size: 16),
          label: const Text("Load older messages"),
          style: TextButton.styleFrom(foregroundColor: AppTokens.inkMuted),
        ),
      ),
    );
  }

  void _confirmDelete(SubjectGroupViewModel vm, GroupMessage message) {
    RemoveAlert.showRemoveAlert(
      title: "Delete this message?",
      description: "Students stop seeing it in the app straight away. "
          "This can't be undone.",
      onPressYes: () async {
        final bool deleted = await vm.delete(message);
        Navigator.pop(navigatorKey.currentContext!);
        if (deleted) Helper.showInfoMessage(msg: "Message deleted");
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Today", "Yesterday", "3 Nov", or "3 Nov 2025" for another year.
  static String _dayLabel(DateTime date, DateTime now) {
    final int daysAway = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    if (daysAway == 0) return "Today";
    if (daysAway == -1) return "Yesterday";
    return DateFormat(date.year == now.year ? 'd MMM' : 'd MMM yyyy')
        .format(date);
  }
}

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 2),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: GroupLook.muted)),
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 32, color: AppTokens.inkFaint),
            SizedBox(height: 10),
            Text("No messages yet",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.ink)),
            SizedBox(height: 4),
            Text(
              "Write the first notice below. Students who bought this "
              "subject will see it in the app.",
              textAlign: TextAlign.center,
              style: AppTokens.pageSubtitle,
            ),
          ],
        ),
      ),
    );
  }
}
