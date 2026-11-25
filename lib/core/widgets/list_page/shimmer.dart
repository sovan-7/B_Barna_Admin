import 'package:flutter/material.dart';

/// Sweeps a soft light band across [child], left to right, on a loop —
/// the "still loading" cue for skeleton placeholders.
///
/// The band is painted only over the child's own pixels (grey bars and
/// cards), and lightens them rather than replacing their colour, so the
/// skeleton keeps its shape. When the platform asks for reduced motion
/// the child is shown as-is.
class Shimmer extends StatefulWidget {
  /// The skeleton to animate.
  final Widget child;

  const Shimmer({required this.child, super.key});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Centre of the band, in Alignment units (-1 = left edge, 1 =
        // right). It runs from just off the left to just off the right, so
        // the band enters and leaves cleanly.
        final double centre = -1.5 + _controller.value * 3;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(centre - 1, 0),
            end: Alignment(centre + 1, 0),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.7),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
