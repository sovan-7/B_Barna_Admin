import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// Grey placeholder rows shown while a list is loading, sized like the
/// real cards so the page does not jump when the data arrives.
class ListSkeleton extends StatelessWidget {
  /// Height of one placeholder row (match the list's card height).
  final double rowHeight;

  /// How many placeholder rows to draw.
  final int rowCount;

  const ListSkeleton({required this.rowHeight, this.rowCount = 6, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: rowCount,
      itemBuilder: (context, index) => Container(
        height: rowHeight,
        margin: const EdgeInsets.only(bottom: AppTokens.gapSm),
        decoration: BoxDecoration(
          color: AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.hairline),
        ),
      ),
    );
  }
}
