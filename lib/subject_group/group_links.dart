/// Finds links in a group message the way the student app does
/// (`b_barna_app/lib/subjectGroup/link_text.dart`), so the panel shows the
/// same parts as tappable links that students will see.
library;

/// One piece of a message: plain text, or a link and the address it opens.
class TextPiece {
  final String text;

  /// The address to open; null for plain text.
  final Uri? link;

  const TextPiece(this.text, [this.link]);

  bool get isLink => link != null;
}

final RegExp _linkPattern =
    RegExp(r'(?:https?://|www\.)[^\s<>"]+', caseSensitive: false);

/// Sentence punctuation left out when it ends a link ("।" is the Bengali
/// full stop).
const String _trailing = '.,;:!?\'"’”»…।)]}';

/// Splits [text] into plain pieces and links, in order.
List<TextPiece> splitLinks(String text) {
  final List<TextPiece> pieces = [];
  int plainFrom = 0;

  for (final RegExpMatch match in _linkPattern.allMatches(text)) {
    final String address = _trimEnd(match[0]!);
    final Uri? link = _toUri(address);
    if (link == null) continue;

    if (match.start > plainFrom) {
      pieces.add(TextPiece(text.substring(plainFrom, match.start)));
    }
    pieces.add(TextPiece(address, link));
    plainFrom = match.start + address.length;
  }

  if (plainFrom < text.length) pieces.add(TextPiece(text.substring(plainFrom)));
  return pieces;
}

/// Drops trailing punctuation; a ")" stays when the address opened one.
String _trimEnd(String address) {
  String result = address;
  while (result.isNotEmpty) {
    final String last = result[result.length - 1];
    if (!_trailing.contains(last)) break;
    if (last == ')' &&
        '('.allMatches(result).length >= ')'.allMatches(result).length) {
      break;
    }
    result = result.substring(0, result.length - 1);
  }
  return result;
}

Uri? _toUri(String address) {
  final String full =
      address.toLowerCase().startsWith('www.') ? 'https://$address' : address;
  final Uri? uri = Uri.tryParse(full);
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;
  return uri;
}
