import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ─── ENTRANCE ANIMATIONS ───

class FadeInEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset offset;

  const FadeInEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 20),
  });

  @override
  State<FadeInEntrance> createState() => _FadeInEntranceState();
}

class _FadeInEntranceState extends State<FadeInEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    Future.delayed(widget.delay, () { if (mounted) _controller.forward(); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: Transform.translate(offset: _slide.value, child: child)),
      child: widget.child,
    );
  }
}

class ScaleEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double startScale;

  const ScaleEntrance({super.key, required this.child, this.delay = Duration.zero, this.startScale = 0.8});

  @override
  State<ScaleEntrance> createState() => _ScaleEntranceState();
}

class _ScaleEntranceState extends State<ScaleEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = Tween<double>(begin: widget.startScale, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    Future.delayed(widget.delay, () { if (mounted) _controller.forward(); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

class BlurInEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const BlurInEntrance({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<BlurInEntrance> createState() => _BlurInEntranceState();
}

class _BlurInEntranceState extends State<BlurInEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _blur;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _blur = Tween<double>(begin: 10.0, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    Future.delayed(widget.delay, () { if (mounted) _controller.forward(); });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) => const LinearGradient(colors: [Colors.white, Colors.white]).createShader(rect),
          child: ImageFiltered(
            imageFilter: ColorFilter.mode(Colors.white.withValues(alpha: 1 - (_blur.value / 10).clamp(0, 1)), BlendMode.dstIn),
            child: Transform.scale(scale: 1.0 + (_blur.value / 50), child: widget.child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// ─── INTERACTION ANIMATIONS ───

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.7, end: 1.0).animate(animation),
              child: child,
            ),
          ),
        );
      },
      child: Text('$value', key: ValueKey<int>(value), style: style),
    );
  }
}

class TapBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const TapBounce({super.key, required this.child, required this.onTap});

  @override
  State<TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<TapBounce> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), lowerBound: 0.0, upperBound: 0.05);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(scale: 1 - _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

class SelectionPulse extends StatefulWidget {
  final Widget child;
  final bool isSelected;

  const SelectionPulse({super.key, required this.child, required this.isSelected});

  @override
  State<SelectionPulse> createState() => _SelectionPulseState();
}

class _SelectionPulseState extends State<SelectionPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(SelectionPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}

/// ─── CELEBRATION ANIMATIONS ───

class ScoreCelebration extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onFinish;

  const ScoreCelebration({
    super.key,
    required this.text,
    required this.color,
    required this.onFinish,
  });

  @override
  State<ScoreCelebration> createState() => _ScoreCelebrationState();
}

class _ScoreCelebrationState extends State<ScoreCelebration> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _confettiController;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _shimmer;
  
  final List<_ConfettiPiece> _confetti = List.generate(40, (i) => _ConfettiPiece());

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.elasticOut)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.0).chain(CurveTween(curve: Curves.bounceIn)), weight: 30),
    ]).animate(CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 1.0)));

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_mainController);

    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.2, 0.8, curve: Curves.linear)),
    );

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onFinish();
    });

    _mainController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.35),
      child: Stack(
        children: [
          // Confetti
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) => CustomPaint(
              painter: _ConfettiPainter(_confetti, _confettiController.value),
              size: Size.infinite,
            ),
          ),
          
          // Main Text
          Center(
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color,
                            widget.color.withValues(alpha: 0.8),
                            widget.color,
                          ],
                          begin: Alignment(_shimmer.value - 1, 0),
                          end: Alignment(_shimmer.value + 1, 0),
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10),
                          BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -2), spreadRadius: 1),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              shadows: [Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 8)],
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            height: 3, width: 60,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPiece {
  final double x = math.Random().nextDouble();
  final double y = -0.1 - math.Random().nextDouble();
  final double size = 4.0 + math.Random().nextDouble() * 8.0;
  final Color color = [
    Colors.amber, Colors.blue, Colors.pink, Colors.green, Colors.orange, Colors.white
  ][math.Random().nextInt(6)];
  final double speed = 0.5 + math.Random().nextDouble() * 1.5;
  final double drift = (math.Random().nextDouble() - 0.5) * 0.3;
  final double rotation = math.Random().nextDouble() * math.pi * 2;
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter(this.pieces, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in pieces) {
      final Paint paint = Paint()..color = p.color..style = PaintingStyle.fill;
      final double x = (p.x + p.drift * progress) * size.width;
      final double y = (p.y + p.speed * progress * 1.5) * size.height;
      
      if (y > size.height) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * 5);
      canvas.drawRect(Rect.fromLTWH(-p.size / 2, -p.size / 2, p.size, p.size), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PulseAnimation extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;

  const PulseAnimation({
    super.key,
    required this.child,
    this.scale = 1.2,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}
