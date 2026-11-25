import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The outer frame every list screen sits in: the grey canvas background
/// and the standard page padding, with [children] stacked in a column
/// (usually header → search → list → footer).
class ListPageFrame extends StatelessWidget {
  /// The page sections, top to bottom.
  final List<Widget> children;

  const ListPageFrame({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTokens.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
