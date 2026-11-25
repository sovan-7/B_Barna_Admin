import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// Top row of a list screen:
///
/// ```
/// Title (count)                              [trailing]
/// subtitle
/// ```
///
/// [trailing] is usually an `AddWidget` ("NEW PDF"), but can be any
/// control (the Students list puts its sort toggle there).
class ListPageHeader extends StatelessWidget {
  /// Page title, e.g. "PDFs".
  final String title;

  /// Number shown in the pill next to the title.
  final int count;

  /// One-line description under the title.
  final String subtitle;

  /// Widget pinned to the right of the header; nothing when null.
  final Widget? trailing;

  const ListPageHeader({
    required this.title,
    required this.count,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.pageTitle),
                  ),
                  const SizedBox(width: 10),
                  ListCountPill(count: count),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTokens.gapMd),
          trailing!,
        ],
      ],
    );
  }
}

/// The small rounded "(42)" badge beside a list title.
class ListCountPill extends StatelessWidget {
  /// The number to show.
  final int count;

  const ListCountPill({required this.count, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Text("$count",
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTokens.inkMuted)),
    );
  }
}
