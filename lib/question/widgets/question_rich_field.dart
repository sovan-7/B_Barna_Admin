import 'dart:collection';

import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';

/// A labelled rich-text field.
///
/// The old editor shipped a big coloured button under every one of these —
/// "Upload/ View Question", "Upload/ View Solution", and six more. Every
/// one was wired to `onUpload: () {}`. They are gone; what is left is the
/// label, the editor, and an error line.
class QuestionRichField extends StatelessWidget {
  final String label;
  final HtmlEditorController controller;

  /// The HTML the editor opens with.
  ///
  /// This is the *only* hook that prefills one of these: the package
  /// applies it inside the iframe's `onLoad`, once the editor exists.
  /// Calling `controller.setText` from `initState` or a post-frame callback
  /// runs long before that and is dropped — which is why opening a question
  /// for editing showed eight empty boxes.
  final String? initialText;

  /// Shown under the label — what this field is for, when that is not
  /// obvious from two words.
  final String? hint;
  final String? error;
  final double height;

  /// Marks the field as the correct answer. Only the option fields use it.
  final Widget? trailing;

  const QuestionRichField({
    required this.label,
    required this.controller,
    this.initialText,
    this.hint,
    this.error,
    this.height = 180,
    this.trailing,
    super.key,
  });

  /// Name of the script below, and the message that runs it.
  static const String _dropScriptName = 'singleInsertOnDrop';

  /// Replaces Summernote's drop handler with one that inserts once.
  ///
  /// Dropping text from another application put it in twice. Summernote's
  /// dropzone `preventDefault`s the browser's own drop and then walks every
  /// flavour the drag is carrying, pasting each one whose MIME type
  /// contains "text":
  ///
  /// ```js
  /// each(dataTransfer.types, function (_, type) {
  ///   var data = dataTransfer.getData(type);
  ///   type.toLowerCase().indexOf('text') > -1
  ///     ? context.invoke('editor.pasteHTML', data)
  ///     : $(data).each(...)
  /// })
  /// ```
  ///
  /// A drag out of WordPad carries the same content as both `text/html` and
  /// `text/plain`. Both match, so both are pasted — the styled copy, then
  /// the bare one.
  ///
  /// This unbinds *every* drop handler on the dropzone before binding one,
  /// so it also covers the other way the duplication could arise: a second
  /// handler stacking on the first, which is what "the first drop is fine,
  /// the rest double up" would look like.
  ///
  /// Files are still handed to Summernote's image path, so dragging in a
  /// picture keeps working. Text takes `text/html` when the source offers
  /// it and falls back to `text/plain`, so formatting survives.
  ///
  /// Guarded throughout: if the editor is not ready or its internals have
  /// moved, it retries once and then leaves Summernote's own handler in
  /// place rather than breaking dropping altogether.
  static final WebScript _singleInsertOnDrop = WebScript(
    name: _dropScriptName,
    script: """
      (function attach(attempt) {
        var note = \$('#summernote-2');
        var context = note.data('summernote');
        var dropzone = \$('.note-dropzone');
        if (!context || !dropzone.length) {
          if (attempt < 5) setTimeout(function () { attach(attempt + 1); }, 200);
          return;
        }
        dropzone.off('drop');
        dropzone.on('drop', function (event) {
          var transfer = event.originalEvent.dataTransfer;
          event.preventDefault();
          if (!transfer) return;
          if (transfer.files && transfer.files.length) {
            context.invoke('editor.insertImagesOrCallback', transfer.files);
            return;
          }
          var html = transfer.getData('text/html');
          var plain = transfer.getData('text/plain');
          var payload = (html && html.trim().length) ? html : plain;
          if (payload && payload.length) {
            context.invoke('editor.pasteHTML', payload);
          }
        });
      })(0);
    """,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF344054))),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint!,
                        style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: AppTokens.inkFaint)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTokens.gapSm),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd - 1),
            child: HtmlEditor(
              controller: controller,
              // Registering the script above only makes it available; this
              // is what runs it, once the editor exists.
              callbacks: Callbacks(onInit: () {
                if (!kIsWeb) return;
                controller.evaluateJavascriptWeb(_dropScriptName);
              }),
              htmlToolbarOptions: const HtmlToolbarOptions(
                dropdownMenuMaxHeight: 200,
                dropdownMenuDirection: DropdownMenuDirection.down,
                // Must not go under kMinInteractiveDimension (48):
                // DropdownButton asserts on it, and the toolbar's font and
                // style pickers are DropdownButtons.
                dropdownItemHeight: kMinInteractiveDimension,
                toolbarType: ToolbarType.nativeScrollable,
                textStyle: TextStyle(
                    color: Colors.black, backgroundColor: Colors.transparent),
                defaultToolbarButtons: [
                  StyleButtons(),
                  FontButtons(clearAll: false),
                  ColorButtons(),
                  ListButtons(listStyles: false),
                  ParagraphButtons(
                      textDirection: false, lineHeight: false, caseConverter: false),
                  InsertButtons(video: false, audio: false, table: false, hr: false),
                ],
              ),
              htmlEditorOptions: HtmlEditorOptions(
                hint: "Type here…",
                autoAdjustHeight: false,
                spellCheck: true,
                adjustHeightForKeyboard: false,
                androidUseHybridComposition: false,
                // Was hard-coded to "". The package applies this on load,
                // *after* anything an earlier setText managed to write, so
                // an empty string here blanked the editor either way.
                initialText: initialText,
                webInitialScripts:
                    UnmodifiableListView<WebScript>([_singleInsertOnDrop]),
              ),
              otherOptions:
                  OtherOptions(height: height, decoration: const BoxDecoration()),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error!, style: AppTokens.errorText),
        ],
      ],
    );
  }
}
