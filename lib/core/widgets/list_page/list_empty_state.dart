import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// What a list shows when it has no rows.
///
/// Two flavours, picked by [isFiltered]:
/// * **Empty** (nothing exists yet): [icon], [title], [message] and, when
///   [onAdd] is given, an outlined "Add …" button.
/// * **Filtered** (a search matched nothing): a search-off icon,
///   "No matches" and [filteredMessage]; no button.
class ListEmptyState extends StatelessWidget {
  /// True when a search is active and found nothing.
  final bool isFiltered;

  /// Icon for the "nothing yet" case.
  final IconData icon;

  /// Heading for the "nothing yet" case, e.g. "No PDFs yet".
  final String title;

  /// Explanation for the "nothing yet" case.
  final String message;

  /// Explanation for the "search found nothing" case. Should say which
  /// field is searched, e.g. "Search matches the code, not the title."
  final String filteredMessage;

  /// Width the explanation text wraps at.
  final double messageWidth;

  /// Label of the add button, e.g. "Add a PDF".
  final String? addLabel;

  /// Icon of the add button.
  final IconData addIcon;

  /// Opens the Add screen. No button is shown when null.
  final VoidCallback? onAdd;

  const ListEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.isFiltered = false,
    this.filteredMessage = "",
    this.messageWidth = 340,
    this.addLabel,
    this.addIcon = Icons.add,
    this.onAdd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onAdd = this.onAdd;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Round icon badge.
            Container(
              height: 64,
              width: 64,
              decoration: const BoxDecoration(
                  color: AppTokens.surfaceMuted, shape: BoxShape.circle),
              child: Icon(isFiltered ? Icons.search_off : icon,
                  size: 28, color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            const SizedBox(height: 5),
            SizedBox(
              width: messageWidth,
              child: Text(
                isFiltered ? filteredMessage : message,
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            // Add button — only for a genuinely empty list.
            if (!isFiltered && onAdd != null) ...[
              const SizedBox(height: AppTokens.gapLg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: Icon(addIcon, size: 16),
                label: Text(addLabel ?? ""),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.ink,
                  side: const BorderSide(color: AppTokens.hairline),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
