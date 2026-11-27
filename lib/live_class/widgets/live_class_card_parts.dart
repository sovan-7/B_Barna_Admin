import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/screen/edit_live_class.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:bbarna/utils/session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Pieces of a class shared by the narrow card (`LiveClassCard`) and the
// wide agenda row (`LiveClassAgendaRow`). Widget keys are what the tests
// find, so they stay the same wherever a piece is shown.

/// Colour of the PDF icon and the Replace PDF action.
const Color _pdfRed = AppTokens.accentInk;

/// Colour of the Upload PDF pill and the Replace action.
const Color _uploadBlue = AppTokens.accentInk;

/// The class's subject names, blanks dropped (a code stands in for a
/// missing name).
List<String> liveClassSubjectLabels(LiveClassModel data) => [
      for (int i = 0; i < data.subjectNames.length; i++)
        if (data.subjectNames[i].trim().isNotEmpty)
          data.subjectNames[i].trim()
        else if (i < data.subjectCodes.length &&
            data.subjectCodes[i].trim().isNotEmpty)
          data.subjectCodes[i].trim(),
    ];

/// Whether [data] has a description worth showing.
bool liveClassHasDescription(LiveClassModel data) =>
    data.description.trim().isNotEmpty && data.description != stringDefault;

/// Whether [data] has a stream link worth showing.
bool liveClassHasLink(LiveClassModel data) =>
    data.youtubeLink.trim().isNotEmpty && data.youtubeLink != stringDefault;

/// True when the Delete chat button shows: a Past class, an admin, and a
/// chat not already deleted or being deleted.
bool canDeleteLiveClassChat(LiveClassModel data) =>
    Session.isAdmin &&
    data.status == LiveClassStatus.past &&
    data.chatState == LiveClassChatState.none;

/// True when the Upload PDF pill shows: a Past class, an admin, and no PDF
/// yet (once there is one, the PDF row's Replace takes over).
bool canUploadLiveClassPdf(LiveClassModel data) =>
    Session.isAdmin && data.status == LiveClassStatus.past && !data.hasPdf;

/// Free / Paid, in the same colours as the quiz FREE / PAID chip.
class LiveClassTypeChip extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  const LiveClassTypeChip({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      key: Key('live_class_type_chip_${data.docId}'),
      icon: data.isFree ? Icons.lock_open_outlined : Icons.paid_outlined,
      label: data.classType,
      color: data.isFree ? AppTokens.accentInk : AppTokens.accentInk,
      filled: true,
    );
  }
}

/// A small grey detail pill (subject, teacher, …).
class LiveClassDetailChip extends StatelessWidget {
  /// The leading icon.
  final IconData icon;

  /// The text.
  final String label;

  const LiveClassDetailChip(
      {required this.icon, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LiveClassTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: LiveClassTheme.inkFaint),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: LiveClassTheme.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The first subject, "+N" for the rest, and every subject in a tooltip.
/// Nothing when the class has no subject.
class LiveClassSubjectsChip extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  const LiveClassSubjectsChip({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> names = liveClassSubjectLabels(data);
    if (names.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      key: Key('live_class_subjects_${data.docId}'),
      message: names.join("\n"),
      child: LiveClassDetailChip(
        icon: Icons.library_books_outlined,
        label: names.length == 1
            ? names.first
            : "${names.first} +${names.length - 1}",
      ),
    );
  }
}

/// "Deleting chat…" or "Chat deleted"; nothing while the chat is intact.
class LiveClassChatStateChip extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  const LiveClassChatStateChip({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    switch (data.chatState) {
      case LiveClassChatState.deleting:
        return StatusChip(
          key: Key('live_class_chat_deleting_${data.docId}'),
          icon: Icons.hourglass_top_rounded,
          label: "Deleting chat…",
          color: LiveClassTheme.inkMuted,
        );
      case LiveClassChatState.deleted:
        return StatusChip(
          key: Key('live_class_chat_deleted_${data.docId}'),
          icon: Icons.speaker_notes_off_outlined,
          label: "Chat deleted",
          color: LiveClassTheme.inkMuted,
        );
      case LiveClassChatState.none:
        return const SizedBox.shrink();
    }
  }
}

/// A labelled pill with its own [InkWell], so a tap never opens Edit too.
class _ActionPill extends StatelessWidget {
  final Key pillKey;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.pillKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(LiveClassTheme.radiusPill);
    return Material(
      color: color.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: color.withValues(alpha: .35)),
      ),
      child: InkWell(
        key: pillKey,
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The red "Delete chat" pill on a Past class. Always shown (not behind
/// hover like the row icons) so an admin can find it on every finished
/// class.
class LiveClassDeleteChatButton extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  const LiveClassDeleteChatButton({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return _ActionPill(
      pillKey: Key('live_class_delete_chat_${data.docId}'),
      icon: Icons.speaker_notes_off_outlined,
      label: "Delete chat",
      color: LiveClassTheme.danger,
      onTap: () => confirmDeleteLiveClassChat(context, data),
    );
  }
}

/// The blue "Upload PDF" pill on a Past class with no notes yet, or an
/// "Uploading PDF…" chip while the upload runs.
class LiveClassUploadPdfButton extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  /// True while this class's PDF is uploading.
  final bool uploading;

  const LiveClassUploadPdfButton(
      {required this.data, required this.uploading, super.key});

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return StatusChip(
        key: Key('live_class_pdf_uploading_${data.docId}'),
        icon: Icons.hourglass_top_rounded,
        label: "Uploading PDF…",
        color: LiveClassTheme.inkMuted,
      );
    }
    return _ActionPill(
      pillKey: Key('live_class_upload_pdf_${data.docId}'),
      icon: Icons.upload_file_outlined,
      label: "Upload PDF",
      color: _uploadBlue,
      onTap: () => pickAndUploadLiveClassPdf(context, data),
    );
  }
}

/// The stream link. Selectable rather than a plain label: copying the URL
/// out to check a stream is the single most common thing an admin does
/// here.
class LiveClassLinkRow extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  const LiveClassLinkRow({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('live_class_link_${data.docId}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LiveClassTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline,
              size: 15, color: AppTokens.accentInk),
          const SizedBox(width: 7),
          Expanded(
            child: SelectableText(
              LiveClassFormat.shortLink(data.youtubeLink),
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: LiveClassTheme.inkMuted,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

/// The class's notes PDF: tap the name to open it in a new tab. Admins
/// also get Replace (a class keeps exactly one PDF; it is removed only with
/// the class). Each part has its own [InkWell], so a tap never opens Edit
/// as well.
class LiveClassPdfRow extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  /// True while this class's PDF is uploading.
  final bool uploading;

  const LiveClassPdfRow(
      {required this.data, required this.uploading, super.key});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(LiveClassTheme.radiusSm);
    final String name =
        data.pdfName.trim().isEmpty ? "Class notes.pdf" : data.pdfName.trim();
    return Material(
      key: Key('live_class_pdf_${data.docId}'),
      color: LiveClassTheme.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: LiveClassTheme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: "Open PDF",
              child: InkWell(
                key: Key('live_class_pdf_open_${data.docId}'),
                onTap: () => openExternalUrl(data.pdfLink,
                    failureMessage: "Couldn't open the PDF"),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined,
                          size: 15, color: _pdfRed),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: LiveClassTheme.inkMuted),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new,
                          size: 13, color: LiveClassTheme.inkFaint),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (Session.isAdmin) ...[
            Container(width: 1, height: 18, color: LiveClassTheme.hairline),
            if (uploading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.8),
                ),
              )
            else
              Tooltip(
                message: "Upload a different PDF in its place",
                child: InkWell(
                  key: Key('live_class_pdf_replace_${data.docId}'),
                  onTap: () => pickAndUploadLiveClassPdf(context, data),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text(
                      "Replace",
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _uploadBlue),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Edit and delete icons; faded in when [visible] (hover / compact
/// screens) and ignoring taps while hidden.
class LiveClassRowActions extends StatelessWidget {
  /// The class shown.
  final LiveClassModel data;

  /// Whether the buttons are shown and tappable.
  final bool visible;

  /// Called after the Edit page saves or deletes something.
  final VoidCallback onChanged;

  const LiveClassRowActions({
    required this.data,
    required this.visible,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton(
              key: Key('live_class_edit_${data.docId}'),
              icon: Icons.edit_outlined,
              tooltip: "Edit class",
              color: LiveClassTheme.inkMuted,
              onTap: () => openEditLiveClass(context, data, onChanged),
            ),
            const SizedBox(width: 2),
            _iconButton(
              key: Key('live_class_delete_${data.docId}'),
              icon: Icons.delete_outline,
              tooltip: "Delete class",
              color: LiveClassTheme.danger,
              onTap: () => confirmDeleteLiveClass(context, data),
            ),
          ],
        ),
      ),
    );
  }

  /// A small tappable icon with a tooltip.
  Widget _iconButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

/// Opens Edit Class for [data]; [onChanged] runs if it saved or deleted
/// something.
void openEditLiveClass(
    BuildContext context, LiveClassModel data, VoidCallback onChanged) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => EditLiveClass(liveClassData: data)),
  ).ifSaved(onChanged);
}

/// Lets the admin pick a PDF, then uploads it as [data]'s notes, replacing
/// any earlier one.
Future<void> pickAndUploadLiveClassPdf(
    BuildContext context, LiveClassModel data) async {
  final LiveClassViewModel liveClassViewModel =
      Provider.of<LiveClassViewModel>(context, listen: false);
  final bool replacing = data.hasPdf;
  final FilePickerResult? picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );
  final PlatformFile? file = picked?.files.firstOrNull;
  if (file == null || file.bytes == null) return;
  final bool success =
      await liveClassViewModel.uploadClassPdf(data, file.bytes!, file.name);
  if (success) {
    Helper.showInfoMessage(msg: replacing ? "PDF replaced" : "PDF uploaded");
  }
}

/// Asks for confirmation, then asks for [data]'s chat to be deleted.
void confirmDeleteLiveClassChat(BuildContext context, LiveClassModel data) {
  final LiveClassViewModel liveClassViewModel =
      Provider.of<LiveClassViewModel>(context, listen: false);
  RemoveAlert.showRemoveAlert(
    title: "Delete chat of ${data.title}",
    description: "Every chat message of this class will be deleted for "
        "everyone. This can't be undone.",
    confirmLabel: "Delete chat",
    onPressYes: () async {
      Navigator.pop(navigatorKey.currentContext!);
      final bool success = await liveClassViewModel.deleteChat(data);
      if (success) {
        Helper.showInfoMessage(msg: "Chat is being deleted");
      }
    },
  );
}

/// Asks for confirmation, then deletes [data].
void confirmDeleteLiveClass(BuildContext context, LiveClassModel data) {
  final LiveClassViewModel liveClassViewModel =
      Provider.of<LiveClassViewModel>(context, listen: false);
  RemoveAlert.showRemoveAlert(
    title: data.title,
    description: "Are you sure want to delete ?",
    onPressYes: () async {
      // RemoveAlert never closes itself, so close it before deleting.
      // The view model removes the class from the list on success.
      Navigator.pop(navigatorKey.currentContext!);
      final bool success = await liveClassViewModel.deleteLiveClass(data.docId);
      if (success) {
        Helper.showInfoMessage(msg: "Class deleted successfully");
      }
    },
  );
}
