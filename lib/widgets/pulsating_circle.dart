import 'package:flutter/material.dart';

class PulsatingCircle extends StatefulWidget {
  final double size;
  const PulsatingCircle({super.key, this.size = 120});

  @override
  State<PulsatingCircle> createState() => _PulsatingCircleState();
}

class _PulsatingCircleState extends State<PulsatingCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _ring3;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Main controller for all animations. Repeats continuously.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Staggered ring animations using Interval. Values go from 0.0 -> 1.0
    _ring1 = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.9, curve: Curves.easeOut));
    _ring2 = CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 1.0, curve: Curves.easeOut));
    _ring3 = CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));

    // Faster small pulse for the center dot. SawTooth(2) produces two pulses per controller cycle.
    _pulseAnim = Tween(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _ctrl, curve: const SawTooth(2)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  const Color ringColor = Colors.blue;
    final double base = widget.size;

    return SizedBox(
      width: base,
      height: base,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Three staggered rings implemented by a small reusable widget.
          _Ring(animation: _ring1, maxSize: base, color: ringColor, thickness: 3.0),
          _Ring(animation: _ring2, maxSize: base, color: ringColor, thickness: 3.0),
          _Ring(animation: _ring3, maxSize: base, color: ringColor, thickness: 3.0),

          // Center dot uses a ScaleTransition driven by the pulse animation.
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: base * 0.18,
              height: base * 0.18,
              decoration: BoxDecoration(
                color: ringColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withAlpha((0.35 * 255).round()),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single ring that animates its size and opacity based on [animation].
///
/// The ring grows from a small base (20) up to [maxSize], while fading out.
class _Ring extends StatelessWidget {
  final Animation<double> animation;
  final double maxSize;
  final Color color;
  final double thickness;

  const _Ring({required this.animation, required this.maxSize, required this.color, required this.thickness, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double progress = animation.value; // 0.0 -> 1.0
        final double currentSize = 20 + (maxSize - 20) * progress;
        final double opacity = (1.0 - progress).clamp(0.0, 1.0);

        return SizedBox(
          width: currentSize,
          height: currentSize,
          child: DecoratedBox(
              decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha((opacity * 255).round()), width: thickness),
            ),
          ),
        );
      },
    );
  }
}