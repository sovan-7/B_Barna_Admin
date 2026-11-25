import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:flutter/material.dart';

/// Pill showing whether a class is Upcoming / Live / Past.
///
/// Upcoming and Past are quiet — a tinted pill with the accent as text —
/// because they are just filing. Live is the only state an admin may need
/// to act on right now, so it alone gets a solid fill and a pulsing dot;
/// the movement is what makes it findable in a long list.
class LiveClassStatusBadge extends StatelessWidget {
  /// The status to show.
  final LiveClassStatus status;

  /// Drops the label and renders just the dot — for tight rows where the
  /// status is already implied by the surrounding tab.
  final bool dense;

  const LiveClassStatusBadge(
      {required this.status, this.dense = false, super.key});

  /// Kept as the module's single source of status colour.
  static Color colorFor(LiveClassStatus status) =>
      LiveClassTheme.accentFor(status);

  @override
  Widget build(BuildContext context) {
    final Color accent = LiveClassTheme.accentFor(status);
    final bool isLive = status == LiveClassStatus.live;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 4 : 5),
      decoration: BoxDecoration(
        color: isLive ? accent : LiveClassTheme.tintFor(status),
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
        border: isLive
            ? null
            : Border.all(color: LiveClassTheme.borderFor(status), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive)
            const _PulsingDot(color: Colors.white)
          else
            Container(
              height: 6,
              width: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          if (!dense) ...[
            const SizedBox(width: 6),
            Text(
              status.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isLive ? Colors.white : accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A slow 1.4s breathe. Deliberately opacity-only (no scale) so the badge
/// never changes size and reflows the row it sits in.
class _PulsingDot extends StatefulWidget {
  /// Dot colour.
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  /// Drives the fade in and out, forever.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  /// The fade, built once rather than on every build.
  late final Animation<double> _opacity = Tween<double>(begin: 1, end: .35)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: 6,
        width: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
