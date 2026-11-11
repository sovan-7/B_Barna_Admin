import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// What a list shows when loading it failed and there is nothing to show:
/// an error icon, [title] (e.g. "Couldn't load PDFs"), a hint to check the
/// connection, and a Retry button.
///
/// Used instead of the empty state so a failed load is never mistaken for
/// "there is nothing here yet".
class ListErrorState extends StatelessWidget {
  /// Headline, e.g. "Couldn't load PDFs" or "Search failed".
  final String title;

  /// Tries the load again.
  final VoidCallback onRetry;

  /// Width the explanation text wraps at.
  final double messageWidth;

  const ListErrorState({
    required this.title,
    required this.onRetry,
    this.messageWidth = 340,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                  color: AppTokens.danger.withValues(alpha: .08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 28, color: AppTokens.danger),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            const SizedBox(height: 5),
            SizedBox(
              width: messageWidth,
              child: const Text(
                "Check your connection and try again.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            const SizedBox(height: AppTokens.gapLg),
            OutlinedButton.icon(
              key: const Key('list_retry_button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Retry"),
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
        ),
      ),
    );
  }
}
