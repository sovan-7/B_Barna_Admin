import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// Layout facts a card needs when it builds its content.
class CardLayoutInfo {
  /// True below 900px wide: the card stacks its sections vertically.
  final bool isCompact;

  /// Whether the edit/delete buttons should be visible — on hover on wide
  /// screens, always on compact ones (there is no hover on touch).
  final bool showActions;

  const CardLayoutInfo({required this.isCompact, required this.showActions});
}

/// The white rounded box every list row sits in, with a darker border while
/// the mouse is over it.
///
/// The shell owns the hover state and works out [CardLayoutInfo]; the card
/// only decides what goes inside via [builder]. For the usual
/// identity / chips / actions arrangement use [CardRowLayout] inside it.
class AdminCardShell extends StatefulWidget {
  /// Builds the card content for the current layout.
  final Widget Function(BuildContext context, CardLayoutInfo layout) builder;

  const AdminCardShell({required this.builder, super.key});

  @override
  State<AdminCardShell> createState() => _AdminCardShellState();
}

class _AdminCardShellState extends State<AdminCardShell> {
  /// True while the mouse pointer is over the card.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 900;
    final CardLayoutInfo layout = CardLayoutInfo(
      isCompact: isCompact,
      showActions: _hovered || isCompact,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: AppTokens.gapSm),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
              color: _hovered
                  ? AppTokens.inkFaint.withValues(alpha: .5)
                  : AppTokens.hairline),
          boxShadow: AppTokens.cardShadow,
        ),
        child: widget.builder(context, layout),
      ),
    );
  }
}

/// The standard card arrangement.
///
/// Wide:    `[ identity (flex 5) | chips (flex [chipsFlex]) | actions ]`
///
/// Compact: identity, then chips, then the actions right-aligned below.
class CardRowLayout extends StatelessWidget {
  /// Current layout, from [AdminCardShell].
  final CardLayoutInfo layout;

  /// Icon/thumbnail, title, code and description.
  final Widget identity;

  /// Status / toggle chips.
  final Widget chips;

  /// The edit/delete buttons (usually a [CardActions]).
  final Widget actions;

  /// Share of the width the chips get on wide screens (identity gets 5).
  final int chipsFlex;

  const CardRowLayout({
    required this.layout,
    required this.identity,
    required this.chips,
    required this.actions,
    this.chipsFlex = 4,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (layout.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          identity,
          const SizedBox(height: 10),
          chips,
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 5, child: identity),
        const SizedBox(width: AppTokens.gapMd),
        // Flexible, not bare: an unbounded Wrap here would take its whole
        // intrinsic width and starve the title column.
        Flexible(flex: chipsFlex, child: chips),
        const SizedBox(width: AppTokens.gapSm),
        actions,
      ],
    );
  }
}
