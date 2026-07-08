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
      builder: (_, _) => Container(
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

class SkeletonStat extends StatelessWidget {
  final AppC c;
  const SkeletonStat({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.sub.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SkeletonBox(width: 15, height: 15, radius: 5),
          const SizedBox(width: 7),
          Expanded(child: SkeletonBox(height: 9, radius: 4)),
          const SizedBox(width: 7),
          SkeletonBox(width: 20, height: 18, radius: 5),
        ],
      ),
    );
  }
}

class SkeletonRouterCard extends StatelessWidget {
  final AppC c;
  const SkeletonRouterCard({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.sub.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 35, height: 35, radius: 9),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 5),
                    SkeletonBox(width: 150, height: 9),
                    const SizedBox(height: 5),
                    SkeletonBox(width: 90, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: c.sub.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 39, radius: 9)),
              const SizedBox(width: 6),
              Expanded(child: SkeletonBox(height: 39, radius: 9)),
              const SizedBox(width: 6),
              Expanded(child: SkeletonBox(height: 39, radius: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonInterfaceCard extends StatelessWidget {
  final AppC c;
  const SkeletonInterfaceCard({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.sub.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 125, height: 32, radius: 9),
              const Spacer(),
              SkeletonBox(width: 38, height: 38, radius: 9),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 31, radius: 9)),
              const SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 31, radius: 9)),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 68, radius: 4),
        ],
      ),
    );
  }
}
