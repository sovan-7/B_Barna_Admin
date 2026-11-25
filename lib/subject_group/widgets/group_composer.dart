import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/subject_group/viewModel/subject_group_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The writing box under a group's messages: the message, an optional
/// picture, and Send. Ctrl+Enter (⌘+Enter on a Mac) sends too.
///
/// After a successful send the box empties; after a failure everything
/// stays, ready to try again.
class GroupComposer extends StatefulWidget {
  /// True while a message is being posted.
  final bool isSending;

  /// False while nothing may be posted (the whole chat is being deleted).
  final bool enabled;

  /// Posts the message; returns whether it worked.
  final Future<bool> Function(String text, Uint8List? image) onSend;

  /// Picks a picture; tests pass their own instead of the file picker.
  final Future<Uint8List?> Function()? pickImage;

  const GroupComposer({
    required this.isSending,
    this.enabled = true,
    required this.onSend,
    this.pickImage,
    super.key,
  });

  @override
  State<GroupComposer> createState() => _GroupComposerState();
}

class _GroupComposerState extends State<GroupComposer> {
  final TextEditingController _text = TextEditingController();
  Uint8List? _image;

  /// Nothing can be changed or sent while posting, or while disabled.
  bool get _locked => widget.isSending || !widget.enabled;

  bool get _canSend =>
      !_locked && (_text.text.trim().isNotEmpty || _image != null);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickFile() async {
    final FilePickerResult? picked = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    return picked?.files.first.bytes;
  }

  Future<void> _choosePicture() async {
    final Uint8List? bytes = await (widget.pickImage ?? _pickFile)();
    if (bytes == null || !mounted) return;
    setState(() => _image = bytes);
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final bool sent = await widget.onSend(_text.text, _image);
    if (!sent || !mounted) return;
    setState(() {
      _text.clear();
      _image = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 700;
    final Uint8List? image = _image;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (image != null) ...[
            _picturePreview(image),
            const SizedBox(height: 10),
          ],
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  _send,
              const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                  _send,
            },
            child: TextField(
              key: const Key('group_text_field'),
              controller: _text,
              enabled: !_locked,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                    SubjectGroupViewModel.maxTextLength),
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 14, height: 1.45, color: AppTokens.ink),
              decoration: InputDecoration(
                hintText: "Write a notice for the students of this subject…",
                hintStyle:
                    const TextStyle(fontSize: 14, color: AppTokens.inkFaint),
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                enabledBorder: _border(AppTokens.hairline, 1),
                disabledBorder: _border(AppTokens.hairline, 1),
                focusedBorder: _border(const Color(0xFF175CD3), 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Full width, so Send sits at the right edge (on narrow windows
          // it drops below "Add picture").
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('group_add_picture'),
                  onPressed: _locked ? null : _choosePicture,
                  icon:
                      const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(image == null ? "Add picture" : "Change picture"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTokens.ink,
                    side: const BorderSide(color: AppTokens.hairline),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusMd)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${_text.text.length}/${SubjectGroupViewModel.maxTextLength}",
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTokens.inkFaint),
                    ),
                    if (!narrow) ...[
                      const SizedBox(width: 14),
                      const Text("Ctrl + Enter to send",
                          style: TextStyle(
                              fontSize: 11.5, color: AppTokens.inkFaint)),
                    ],
                    const SizedBox(width: 14),
                    _sendButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _sendButton() {
    return ElevatedButton.icon(
      key: const Key('group_send'),
      onPressed: _canSend ? _send : null,
      icon: widget.isSending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: Colors.white),
            )
          : const Icon(Icons.send_rounded, size: 16),
      label: const Text("Send",
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.ink,
        disabledBackgroundColor: AppTokens.ink.withValues(alpha: .35),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(110, 42),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
      ),
    );
  }

  /// The chosen picture, with ✕ on its corner to drop it. The ✕ sits
  /// inside the stack's bounds: outside them it would not take clicks.
  Widget _picturePreview(Uint8List image) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            // A fixed size, so the ✕ has its place even before the
            // picture has decoded.
            child: Image.memory(image,
                width: 128,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                      width: 128,
                      height: 96,
                      color: AppTokens.surfaceMuted,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined,
                          color: AppTokens.inkFaint),
                    )),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Material(
            color: AppTokens.ink,
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('group_remove_picture'),
              customBorder: const CircleBorder(),
              onTap: _locked ? null : () => setState(() => _image = null),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
