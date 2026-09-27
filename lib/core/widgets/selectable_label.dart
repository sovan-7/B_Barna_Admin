import 'package:flutter/material.dart';

/// A list label an admin can select and copy.
///
/// Names, titles and codes are the values that get pasted somewhere else —
/// into a search box, a spreadsheet, another module's form, a message to a
/// teacher — so across every module list they are [SelectableText] rather
/// than [Text]. Drag to select, then Ctrl/Cmd-C, or right-click for Copy.
///
/// [SelectableText] takes no `overflow` argument of its own, so the clamp
/// that plain [Text] got from `overflow:` comes from `maxLines` plus
/// `TextStyle.overflow` here. That keeps the row height and the ellipsis
/// identical to the [Text] each call site replaced.
class SelectableLabel extends StatelessWidget {
  /// The text.
  final String data;

  /// Text style.
  final TextStyle? style;

  /// Lines before it is cut off.
  final int maxLines;

  /// Horizontal alignment.
  final TextAlign? textAlign;

  const SelectableLabel(
    this.data, {
    this.style,
    this.maxLines = 1,
    this.textAlign,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      data,
      maxLines: maxLines,
      textAlign: textAlign,
      style: (style ?? const TextStyle())
          .copyWith(overflow: TextOverflow.ellipsis),
    );
  }
}
