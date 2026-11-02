import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Empty box standing in for content that has not arrived. It pulses while loading and stays still after a failure.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.color = AppColors.border,
    this.animate = true,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;
  final bool animate;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(SkeletonBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulse,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}
