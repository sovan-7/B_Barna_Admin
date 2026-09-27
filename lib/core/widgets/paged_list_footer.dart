import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// "Showing 50 of 320" with a Load more button beside it.
///
/// The paged collections (units, videos, PDFs) all fetch in pages that
/// *accumulate* — the old "Next" appended to one growing list rather than
/// turning a page, so its "Previous" counterpart could only chop rows back
/// off the end. This states what is actually happening, and every paged
/// list now says it the same way.
class PagedListFooter extends StatelessWidget {
  /// How many rows are on screen.
  final int shown;

  /// How many the collection holds in total.
  final int total;

  /// True while a search is showing: paging does not apply to a result set
  /// that came from a separate query, so the wording changes.
  final bool isSearching;

  /// Whether a "Load more" button should be shown.
  final bool hasMore;

  /// Shows a spinner in the button while the next page loads.
  final bool isLoadingMore;

  /// How many the next fetch will add, for the button's label.
  final int pageSize;

  /// Loads the next page.
  final VoidCallback onLoadMore;

  const PagedListFooter({
    required this.shown,
    required this.total,
    required this.hasMore,
    required this.isLoadingMore,
    required this.pageSize,
    required this.onLoadMore,
    this.isSearching = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              isSearching
                  ? "$shown match${shown == 1 ? '' : 'es'}"
                  : "Showing $shown of $total",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppTokens.inkMuted),
            ),
          ),
          const Spacer(),
          if (hasMore)
            OutlinedButton.icon(
              key: const Key('paged_list_load_more'),
              onPressed: isLoadingMore ? null : onLoadMore,
              icon: isLoadingMore
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTokens.inkMuted),
                    )
                  : const Icon(Icons.expand_more, size: 17),
              label: Text(isLoadingMore ? "Loading…" : "Load $pageSize more"),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTokens.ink,
                side: const BorderSide(color: AppTokens.hairline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
              ),
            ),
        ],
      ),
    );
  }
}
