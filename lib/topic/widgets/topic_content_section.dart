import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:flutter/material.dart';

/// One kind of content attached to a topic (videos, audio, PDFs or
/// quizzes): an editable list of codes, each showing what it resolves to
/// (or a warning when nothing has that code), plus "Add a code" and Save.
class TopicContentSection extends StatefulWidget {
  /// Which kind of content this section manages.
  final ContentKind kind;

  /// The codes currently stored on the topic.
  final List<String> initialCodes;

  /// `code -> title` for the codes that exist. Anything absent from this
  /// map points at nothing. Null while it is still being fetched.
  final Map<String, String>? titles;

  /// True when looking the codes up failed; rows then say so neutrally
  /// instead of "Checking…" or a red "no item with this code".
  final bool checkFailed;

  /// Looks the given codes up again (the Retry on a failed check).
  final void Function(List<String> codes)? onRecheck;

  /// Saves the given codes. Returns true when the write went through.
  final Future<bool> Function(List<String> codes) onSave;

  const TopicContentSection({
    required this.kind,
    required this.initialCodes,
    required this.titles,
    required this.onSave,
    this.checkFailed = false,
    this.onRecheck,
    super.key,
  });

  @override
  State<TopicContentSection> createState() => _TopicContentSectionState();
}

class _TopicContentSectionState extends State<TopicContentSection> {
  /// One controller per code row.
  final List<TextEditingController> _controllers = [];

  /// True while the save is in flight.
  bool _isSaving = false;

  /// True when the rows differ from what is saved.
  bool _dirty = false;

  /// Icon for each kind of content.
  static const Map<ContentKind, IconData> _icons = {
    ContentKind.video: Icons.play_circle_outline,
    ContentKind.audio: Icons.graphic_eq,
    ContentKind.pdf: Icons.picture_as_pdf_outlined,
    ContentKind.quiz: Icons.quiz_outlined,
  };

  @override
  void initState() {
    super.initState();
    for (final String code in widget.initialCodes) {
      _controllers.add(TextEditingController(text: code));
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Non-empty codes, in order, de-duplicated (so a code can never be
  /// attached or counted twice).
  List<String> _codes() {
    final List<String> codes = [];
    for (final TextEditingController controller in _controllers) {
      final String value = controller.text.trim();
      if (value.isNotEmpty && !codes.contains(value)) codes.add(value);
    }
    return codes;
  }

  /// Saves the current codes; clears [_dirty] only if the write succeeded.
  Future<void> _save() async {
    setState(() => _isSaving = true);
    final bool ok = await widget.onSave(_codes());
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      // Only a write that actually landed clears the pending state.
      if (ok) _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = MediaQuery.sizeOf(context).width < 560;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTokens.gapMd),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          if (_controllers.isEmpty)
            _empty()
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 12, 4),
              child: Column(
                children: [
                  for (int i = 0; i < _controllers.length; i++) _row(i),
                ],
              ),
            ),
          _footer(isNarrow),
        ],
      ),
    );
  }

  /// Kind icon, title and how many codes are attached.
  Widget _header() {
    final int count = _codes().length;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          Icon(_icons[widget.kind], size: 17, color: AppTokens.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              widget.kind.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink),
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: Text("$count",
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.inkMuted)),
          ),
        ],
      ),
    );
  }

  /// Shown when no codes are attached.
  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      child: Text(
        "No ${widget.kind.inlineLabel} attached to this topic.",
        style: const TextStyle(fontSize: 12.5, color: AppTokens.inkFaint),
      ),
    );
  }

  /// One code box with what it points at and a remove button.
  Widget _row(int index) {
    final String code = _controllers[index].text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: AppTokens.hairline),
                  ),
                  child: TextField(
                    key: Key('topic_${widget.kind.name}_code_$index'),
                    controller: _controllers[index],
                    // Codes are written uppercase everywhere they are
                    // created, so typing one in lower case here would
                    // attach nothing. Existing values are left untouched.
                    inputFormatters: [UpperCaseTextFormatter()],
                    style:
                        const TextStyle(fontSize: 13.5, color: AppTokens.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "${widget.kind.label} code",
                      hintStyle: const TextStyle(
                          fontSize: 13, color: AppTokens.inkFaint),
                      contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                ),
                const SizedBox(height: 5),
                _resolution(code),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          IconButton(
            key: Key('topic_${widget.kind.name}_remove_$index'),
            tooltip: "Remove this code",
            onPressed: _isSaving
                ? null
                : () => setState(() {
                      _controllers[index].dispose();
                      _controllers.removeAt(index);
                      _dirty = true;
                    }),
            icon: const Icon(Icons.close, size: 18),
            color: AppTokens.inkMuted,
          ),
        ],
      ),
    );
  }

  /// What the code points at: the item's title when it exists, or a warning
  /// when no item has that code (so a typo is visible).
  Widget _resolution(String code) {
    if (code.isEmpty) {
      return const Text("Empty rows are dropped when you save.",
          style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint));
    }

    if (widget.checkFailed) {
      return Row(
        children: [
          const Icon(Icons.help_outline, size: 12, color: AppTokens.inkFaint),
          const SizedBox(width: 5),
          const Flexible(
            child: Text("Couldn't check this code",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
          ),
          if (widget.onRecheck != null) ...[
            const SizedBox(width: 6),
            InkWell(
              key: Key('topic_${widget.kind.name}_recheck'),
              onTap: () => widget.onRecheck!(_codes()),
              child: const Text("Retry",
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.inkMuted,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ],
      );
    }

    final Map<String, String>? titles = widget.titles;
    if (titles == null) {
      return const Text("Checking…",
          style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint));
    }

    final String? title = titles[code];
    if (title == null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, size: 12, color: AppTokens.danger),
          const SizedBox(width: 5),
          Flexible(
            child: Text("No ${widget.kind.inlineLabel} with this code",
                overflow: TextOverflow.ellipsis, style: AppTokens.errorText),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.check_circle_outline,
            size: 12, color: Color(0xFF108460)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(title.isEmpty ? "Untitled" : title,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTokens.inkMuted)),
        ),
      ],
    );
  }

  /// "Add a code" and Save buttons.
  Widget _footer(bool isNarrow) {
    final Widget add = TextButton.icon(
      key: Key('topic_${widget.kind.name}_add'),
      onPressed: _isSaving
          ? null
          : () => setState(() {
                _controllers.add(TextEditingController());
                _dirty = true;
              }),
      icon: const Icon(Icons.add, size: 16),
      label: Text("Add a ${widget.kind.inlineLabel} code",
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5)),
      style: TextButton.styleFrom(
        foregroundColor: AppTokens.inkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );

    final Widget save = ElevatedButton(
      key: Key('topic_${widget.kind.name}_save'),
      // Disabled until something changed, so the button says whether there is
      // anything to save.
      onPressed: (_isSaving || !_dirty) ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.ink,
        disabledBackgroundColor: AppTokens.surfaceMuted,
        foregroundColor: Colors.white,
        disabledForegroundColor: AppTokens.inkFaint,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTokens.inkMuted),
            )
          : Text(_dirty ? "Save changes" : "Saved",
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 14),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: add),
                const SizedBox(height: AppTokens.gapSm),
                save,
              ],
            )
          : Row(
              children: [
                Flexible(child: add),
                const Spacer(),
                save,
              ],
            ),
    );
  }
}
