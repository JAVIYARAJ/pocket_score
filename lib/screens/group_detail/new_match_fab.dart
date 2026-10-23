part of '../group_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Animated "New Match" FAB
// Two independent controllers keep entrance and glow from interfering:
//   _entranceCtrl — one-shot slide-up + fade-in
//   _glowCtrl     — endless shadow-opacity pulse
// ─────────────────────────────────────────────────────────────────────────────
class _NewMatchFab extends StatefulWidget {
  final VoidCallback onTap;
  const _NewMatchFab({required this.onTap});

  @override
  State<_NewMatchFab> createState() => _NewMatchFabState();
}

class _NewMatchFabState extends State<_NewMatchFab>
    with TickerProviderStateMixin {
  // Entrance (runs once)
  late final AnimationController _entranceCtrl;
  late final Animation<Offset> _slide;
  late final Animation<double>  _fade;

  // Glow pulse (repeats forever)
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glow;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 2.5), end: Offset.zero)
        .animate(CurvedAnimation(
          parent: _entranceCtrl, curve: Curves.elasticOut));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entranceCtrl,
          curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.22, end: 0.52).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Small delay so the FAB doesn't pop in while the screen is still settling.
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceCtrl, _glowCtrl]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _glow.value),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.38),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(32),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_cricket_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'New Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
