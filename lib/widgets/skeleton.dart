import 'package:flutter/material.dart';
import '../core/theme.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// Card skeleton
class SkeletonCard extends StatelessWidget {
  final AppC c;
  const SkeletonCard({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 40, height: 40, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 11),
          const SizedBox(height: 6),
          SkeletonBox(width: 180, height: 11),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 36, radius: 8)),
              const SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 36, radius: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

// Stat card skeleton
class SkeletonStat extends StatelessWidget {
  final AppC c;
  const SkeletonStat({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 36, height: 36, radius: 10),
          const SizedBox(height: 10),
          SkeletonBox(width: 50, height: 28),
          const SizedBox(height: 6),
          SkeletonBox(width: 70, height: 11),
          const SizedBox(height: 4),
          SkeletonBox(width: 50, height: 10),
        ],
      ),
    );
  }
}

// Router card skeleton
class SkeletonRouterCard extends StatelessWidget {
  const SkeletonRouterCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF003A4D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 48, height: 48, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 18),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 100, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 52, radius: 10)),
              const SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 52, radius: 10)),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 7, radius: 6),
          const SizedBox(height: 8),
          const SkeletonBox(height: 7, radius: 6),
        ],
      ),
    );
  }
}
