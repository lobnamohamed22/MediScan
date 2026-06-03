import 'package:flutter/material.dart';

class StaggeredAnimation extends StatefulWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration delayBetween;
  final Curve curve;
  final AxisDirection direction;

  const StaggeredAnimation({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
    this.delayBetween = const Duration(milliseconds: 100),
    this.curve = Curves.easeIn,
    this.direction = AxisDirection.down,
  });

  @override
  State<StaggeredAnimation> createState() => _StaggeredAnimationState();
}

class _StaggeredAnimationState extends State<StaggeredAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration:
          widget.duration + (widget.delayBetween * widget.children.length),
      vsync: this,
    );

    _animations = List.generate(
      widget.children.length,
      (index) {
        return Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              index *
                  widget.delayBetween.inMilliseconds /
                  _controller.duration!.inMilliseconds,
              (index * widget.delayBetween.inMilliseconds +
                      widget.duration.inMilliseconds) /
                  _controller.duration!.inMilliseconds,
              curve: widget.curve,
            ),
          ),
        );
      },
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        widget.children.length,
        (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Opacity(
                opacity: _animations[index].value,
                child: Transform.translate(
                  offset: _getOffset(_animations[index].value),
                  child: child,
                ),
              );
            },
            child: widget.children[index],
          );
        },
      ),
    );
  }

  Offset _getOffset(double value) {
    switch (widget.direction) {
      case AxisDirection.up:
        return Offset(0, 20 * (1 - value));
      case AxisDirection.down:
        return Offset(0, -20 * (1 - value));
      case AxisDirection.left:
        return Offset(20 * (1 - value), 0);
      case AxisDirection.right:
        return Offset(-20 * (1 - value), 0);
    }
  }
}
