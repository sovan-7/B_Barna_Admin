import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/screen/edit_live_class.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_status_badge.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:bbarna/utils/session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One class in the list.
///
/// Reading order is deliberate: status and "starts in 2 days" first (do I
/// care about this row at all?), then the title, then the schedule, then
/// the details. Actions stay hidden until the pointer is over the card so
/// a screen of twenty classes isn't a screen of forty icons — on touch,
/// where there is no hover, they are always shown.
class LiveClassCard extends StatefulWidget {
  /// The item shown in this row.
  final LiveClassModel liveClassData;

  /// Called after the card's Edit page pops, so the list can refresh.
  final Function onChanged;

  const LiveClassCard(
      {required this.liveClassData, required this.onChanged, super.key});

  @override
  State<LiveClassCard> createState() => _LiveClassCardState();
}

class _LiveClassCardState extends State<LiveClassCard> {
  /// Colour of the PDF icon and the Upload / Replace PDF actions.
  static const Color _pdfRed = Color(0xFFD92D20);

  /// Colour of the Upload PDF pill.
  static const Color _uploadBlue = Color(0xFF2563EB);

  /// True while the pointer is over it.
  bool _hovered = false;

  /// Shortcut for the item shown.
  LiveClassModel get _data => widget.liveClassData;

  /// The class's subject names, blanks dropped (a code stands in for a
  /// missing name).
  List<String> get _subjectNames => [
        for (int i = 0; i < _data.subjectNames.length; i++)
          if (_data.subjectNames[i].trim().isNotEmpty)
            _data.subjectNames[i].trim()
          else if (_data.subjectCodes[i].trim().isNotEmpty)
            _data.subjectCodes[i].trim(),
      ];

  @override
  Widget build(BuildContext context) {
    final LiveClassStatus status = _data.status;
    final Color accent = LiveClassTheme.accentFor(status);
    final bool isLive = status == LiveClassStatus.live;
    final bool isPast = status == LiveClassStatus.past;
    final bool canHover = MediaQuery.sizeOf(context).width > 900;
    final bool showActions = _hovered || !canHover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: LiveClassTheme.surface,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
          border: Border.all(
            color: isLive
                ? accent.withValues(alpha: .35)
                : _hovered
                    ? LiveClassTheme.inkFaint.withValues(alpha: .5)
                    : LiveClassTheme.hairline,
          ),
          boxShadow: _hovered
              ? LiveClassTheme.raisedShadow
              : LiveClassTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
            onTap: _openEdit,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status stripe — lets you scan a column of cards by
                    // colour alone, without reading a single badge.
                    Container(width: 4, color: accent),
                    Expanded(
                      child: Opacity(
                        // Past classes recede rather than disappear.
                        opacity: isPast ? .72 : 1,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: _content(status, accent, showActions),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card's body: status line, title, schedule and details.
  Widget _content(LiveClassStatus status, Color accent, bool showActions) {
    final bool hasDescription = _data.description.trim().isNotEmpty &&
        _data.description != stringDefault;
    final bool hasLink = _data.youtubeLink.trim().isNotEmpty &&
        _data.youtubeLink != stringDefault;
    final bool hasPdf = _data.hasPdf;
    final bool uploadingPdf = context.select<LiveClassViewModel, bool>(
        (vm) => vm.isUploadingPdf(_data.docId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LiveClassStatusBadge(status: status),
            const SizedBox(width: LiveClassTheme.gapSm),
            Expanded(
              child: Text(
                LiveClassFormat.relative(_data),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: status == LiveClassStatus.live
                      ? accent
                      : LiveClassTheme.inkFaint,
                ),
              ),
            ),
            _actions(showActions),
          ],
        ),
        const SizedBox(height: LiveClassTheme.gapSm),
        SelectableLabel(
          _data.title,
          maxLines: 2,
          style: LiveClassTheme.cardTitle,
        ),
        const SizedBox(height: 10),
        _scheduleRow(),
        const SizedBox(height: LiveClassTheme.gapSm),
        Wrap(
          spacing: LiveClassTheme.gapSm,
          runSpacing: LiveClassTheme.gapXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Same colours as the quiz FREE / PAID chip.
            StatusChip(
              key: Key('live_class_type_chip_${_data.docId}'),
              icon: _data.isFree
                  ? Icons.lock_open_outlined
                  : Icons.paid_outlined,
              label: _data.classType,
              color: _data.isFree
                  ? const Color(0xFF108460)
                  : const Color(0xFFB54708),
              filled: true,
            ),
            if (_subjectNames.isNotEmpty)
              Tooltip(
                key: Key('live_class_subjects_${_data.docId}'),
                message: _subjectNames.join("\n"),
                child: _chip(
                    Icons.library_books_outlined,
                    _subjectNames.length == 1
                        ? _subjectNames.first
                        : "${_subjectNames.first} +${_subjectNames.length - 1}"),
              ),
            _chip(Icons.person_outline, _data.teacherName),
            _chip(
                Icons.timelapse_outlined,
                LiveClassFormat.duration(
                    _data.startDateTime, _data.endDateTime)),
            if (_data.chatState == LiveClassChatState.deleting)
              StatusChip(
                key: Key('live_class_chat_deleting_${_data.docId}'),
                icon: Icons.hourglass_top_rounded,
                label: "Deleting chat…",
                color: LiveClassTheme.inkMuted,
              ),
            if (_data.chatState == LiveClassChatState.deleted)
              StatusChip(
                key: Key('live_class_chat_deleted_${_data.docId}'),
                icon: Icons.speaker_notes_off_outlined,
                label: "Chat deleted",
                color: LiveClassTheme.inkMuted,
              ),
            // Always shown (not behind hover like the row icons) so an admin
            // can find it on every finished class.
            if (_canDeleteChat) _deleteChatButton(),
            // Same: a finished class without notes yet.
            if (_canUploadPdf)
              uploadingPdf ? _uploadingChip() : _uploadPdfButton(),
          ],
        ),
        if (hasDescription) ...[
          const SizedBox(height: 10),
          Text(
            _data.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LiveClassTheme.body,
          ),
        ],
        if (hasLink || hasPdf) ...[
          // Takes up whatever height this card was stretched to beyond its
          // own content, so the link / PDF rows land on the same line in
          // every card of the row instead of floating directly under a
          // shorter block of text.
          const Spacer(),
          const SizedBox(height: 12),
          if (hasLink) _linkRow(),
          if (hasLink && hasPdf) const SizedBox(height: LiveClassTheme.gapSm),
          if (hasPdf) _pdfRow(uploadingPdf),
        ],
      ],
    );
  }

  /// Date and start–end time of the class.
  Widget _scheduleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.calendar_today_outlined,
              size: 13, color: LiveClassTheme.inkFaint),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            LiveClassFormat.schedule(_data),
            style: LiveClassTheme.metaStrong,
          ),
        ),
      ],
    );
  }

  /// A small grey detail pill (subject, teacher, …).
  Widget _chip(IconData icon, String label) {
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

  /// The link is selectable rather than a plain label — copying the URL out
  /// to check a stream is the single most common thing an admin does here.
  Widget _linkRow() {
    return Container(
      key: Key('live_class_link_${_data.docId}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LiveClassTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline,
              size: 15, color: Color(0xFFE0393E)),
          const SizedBox(width: 7),
          Expanded(
            child: SelectableText(
              LiveClassFormat.shortLink(_data.youtubeLink),
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

  /// The class's notes PDF, under the link: tap the name to open it in a
  /// new tab. Admins also get Replace (a class keeps exactly one PDF; it is
  /// removed only with the class). Each part has its own [InkWell], so a
  /// tap never opens Edit as well.
  Widget _pdfRow(bool uploading) {
    final BorderRadius radius = BorderRadius.circular(LiveClassTheme.radiusSm);
    final String name =
        _data.pdfName.trim().isEmpty ? "Class notes.pdf" : _data.pdfName.trim();
    return Material(
      key: Key('live_class_pdf_${_data.docId}'),
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
                key: Key('live_class_pdf_open_${_data.docId}'),
                onTap: () => openExternalUrl(_data.pdfLink,
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
                  key: Key('live_class_pdf_replace_${_data.docId}'),
                  onTap: _pickAndUploadPdf,
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

  /// The labelled "Upload PDF" pill on a Past class's card with no notes
  /// yet. Its own [InkWell] takes the tap, so it never opens Edit as well.
  Widget _uploadPdfButton() {
    final BorderRadius radius =
        BorderRadius.circular(LiveClassTheme.radiusPill);
    return Material(
      color: _uploadBlue.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: _uploadBlue.withValues(alpha: .35)),
      ),
      child: InkWell(
        key: Key('live_class_upload_pdf_${_data.docId}'),
        borderRadius: radius,
        onTap: _pickAndUploadPdf,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_outlined, size: 13, color: _uploadBlue),
              SizedBox(width: 5),
              Text(
                "Upload PDF",
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _uploadBlue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stands in for the Upload PDF pill while the file uploads.
  Widget _uploadingChip() {
    return StatusChip(
      key: Key('live_class_pdf_uploading_${_data.docId}'),
      icon: Icons.hourglass_top_rounded,
      label: "Uploading PDF…",
      color: LiveClassTheme.inkMuted,
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton(
              key: Key('live_class_edit_${_data.docId}'),
              icon: Icons.edit_outlined,
              tooltip: "Edit class",
              color: LiveClassTheme.inkMuted,
              onTap: _openEdit,
            ),
            const SizedBox(width: 2),
            _iconButton(
              key: Key('live_class_delete_${_data.docId}'),
              icon: Icons.delete_outline,
              tooltip: "Delete class",
              color: LiveClassTheme.danger,
              onTap: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  /// The labelled red "Delete chat" pill on a Past class's card. Its own
  /// [InkWell] takes the tap, so it never opens Edit as well.
  Widget _deleteChatButton() {
    final BorderRadius radius =
        BorderRadius.circular(LiveClassTheme.radiusPill);
    return Material(
      color: LiveClassTheme.danger.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: LiveClassTheme.danger.withValues(alpha: .35)),
      ),
      child: InkWell(
        key: Key('live_class_delete_chat_${_data.docId}'),
        borderRadius: radius,
        onTap: () => _confirmDeleteChat(context),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speaker_notes_off_outlined,
                  size: 13, color: LiveClassTheme.danger),
              SizedBox(width: 5),
              Text(
                "Delete chat",
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: LiveClassTheme.danger),
              ),
            ],
          ),
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

  /// Opens the edit screen; the list reloads if it saved or deleted
  /// something.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditLiveClass(liveClassData: _data),
      ),
    ).ifSaved(() => widget.onChanged());
  }

  /// True when the Delete chat button shows: a Past class, an admin, and a
  /// chat not already deleted or being deleted.
  bool get _canDeleteChat =>
      Session.isAdmin &&
      _data.status == LiveClassStatus.past &&
      _data.chatState == LiveClassChatState.none;

  /// True when the Upload PDF pill shows: a Past class, an admin, and no
  /// PDF yet (once there is one, the PDF row's Replace takes over).
  bool get _canUploadPdf =>
      Session.isAdmin &&
      _data.status == LiveClassStatus.past &&
      !_data.hasPdf;

  /// Lets the admin pick a PDF, then uploads it as this class's notes,
  /// replacing any earlier one.
  Future<void> _pickAndUploadPdf() async {
    final LiveClassViewModel liveClassViewModel =
        Provider.of<LiveClassViewModel>(context, listen: false);
    final bool replacing = _data.hasPdf;
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final PlatformFile? file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final bool success = await liveClassViewModel.uploadClassPdf(
        _data, file.bytes!, file.name);
    if (success) {
      Helper.showInfoMessage(msg: replacing ? "PDF replaced" : "PDF uploaded");
    }
  }

  /// Asks for confirmation, then asks for this class's chat to be deleted.
  void _confirmDeleteChat(BuildContext context) {
    final LiveClassViewModel liveClassViewModel =
        Provider.of<LiveClassViewModel>(context, listen: false);
    RemoveAlert.showRemoveAlert(
      title: "Delete chat of ${_data.title}",
      description: "Every chat message of this class will be deleted for "
          "everyone. This can't be undone.",
      confirmLabel: "Delete chat",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        final bool success = await liveClassViewModel.deleteChat(_data);
        if (success) {
          Helper.showInfoMessage(msg: "Chat is being deleted");
        }
      },
    );
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete(BuildContext context) {
    final LiveClassViewModel liveClassViewModel =
        Provider.of<LiveClassViewModel>(context, listen: false);
    RemoveAlert.showRemoveAlert(
      title: _data.title,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        // RemoveAlert never closes itself, so close it before deleting.
        // The view model removes the class from the list on success.
        Navigator.pop(navigatorKey.currentContext!);
        final bool success =
            await liveClassViewModel.deleteLiveClass(_data.docId);
        if (success) {
          Helper.showInfoMessage(msg: "Class deleted successfully");
        }
      },
    );
  }
}
