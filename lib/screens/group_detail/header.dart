part of '../group_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Header — gradient + invite code chip + TabBar
// ─────────────────────────────────────────────────────────────────────────────
class _GroupDetailHeader extends StatelessWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  const _GroupDetailHeader({
    required this.group,
    required this.isAdmin,
    required this.onLeave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumHeader(
      title: group.name,
      bottomRadius: 0,
      subtitleWidget: TapBounce(
        onTap: () {
          Clipboard.setData(ClipboardData(text: group.inviteCode));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invite code "${group.inviteCode}" copied!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('INVITE: ',
                style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: Colors.white60,
                    fontWeight: FontWeight.w800)),
            Text(group.inviteCode,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5)),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR code button
          TapBounce(
            onTap: () => _showQrSheet(context, group),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          // Overflow menu
          TapBounce(
            onTap: () => _showOptionsMenu(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      // Stack lets the TabBar fill the full width while the icons are
      // overlaid at the edges — tab labels are never clipped.
      bottomChild: SizedBox(
        height: 56,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            const h = 56.0;
            const topY    = h * 0.15;
            const bottomY = h * 0.95;

            // Mirror the same trapezoid used by RealisticPitchPainter.
            final pitchTopLeft     = w * 0.05;
            final pitchTopRight    = w * 0.95;
            final pitchBottomLeft  = -w * 0.05;
            final pitchBottomRight = w * 1.05;

            double getX(double pct, double y) => y == topY
                ? pitchTopLeft  + (pitchTopRight  - pitchTopLeft)  * pct
                : pitchBottomLeft + (pitchBottomRight - pitchBottomLeft) * pct;

            // Bowling crease percentages MUST match RealisticPitchPainter exactly (0.08 and 0.92).
            const leftPct  = 0.08;
            const rightPct = 0.92;

            // Calculate exact midpoint Y of the perspective pitch
            const midY = (topY + bottomY) / 2;

            // Calculate exact X at the midpoint Y
            final leftCreaseX  = (getX(leftPct,  topY) + getX(leftPct,  bottomY)) / 2;
            final rightCreaseX = (getX(rightPct, topY) + getX(rightPct, bottomY)) / 2;

            // Half-widths of each icon
            const leftIconHalfW  = 9.0;
            const rightIconHalfW = 10.0;

            // To make the base of the shadow sit EXACTLY on the midY line:
            // total height = image height + padding (2px)
            const leftIconTop = midY - 40.0;  // 38px image + 2px padding
            const rightIconTop = midY - 36.0; // 34px image + 2px padding

            // Calculate ball position (rolling away from the knocked wicket)
            final ballX = leftCreaseX + 36.0;
            const ballY = midY + 4.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Cricket pitch background ─────────────────────────────
                Positioned.fill(
                  child: CustomPaint(painter: RealisticPitchPainter()),
                ),

                // ── Cricket Ball ──────────────────────────────────────────
                Positioned(
                  left: ballX - 7,
                  top: ballY - 14,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Small shadow on the pitch
                      Positioned(
                        bottom: -1,
                        child: Container(
                          width: 10, height: 3,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.all(Radius.elliptical(5, 1.5)),
                          ),
                        ),
                      ),
                      // The ball
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Image.asset(
                          'assets/icons/ic_cricket_ball_icon.png',
                          height: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Left: knocked/fallen wicket ──────────────────────────
                Positioned(
                  left: leftCreaseX - leftIconHalfW,
                  top: leftIconTop,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 18, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.all(
                                Radius.elliptical(9, 2)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Image.asset(
                          'assets/icons/wicket_out_icon.png',
                          height: 38,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Right: standing wickets (three upright stumps) ────────
                Positioned(
                  left: rightCreaseX - rightIconHalfW,
                  top: rightIconTop,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 20, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.all(
                                Radius.elliptical(10, 2)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Image.asset(
                          'assets/icons/wickets.png',
                          height: 34,
                          color: Colors.white,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showQrSheet(BuildContext context, Group group) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _QrInviteSheet(group: group),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Group Options',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                if (isAdmin) ...[
                  // ── Admin: Rename Group ──────────────────────────────
                  TapBounce(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showRenameSheet(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded,
                                color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rename Group',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                SizedBox(height: 2),
                                Text('Change the group name',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Admin: Delete Group ──────────────────────────────
                  TapBounce(
                    onTap: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.delete_forever_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Delete Group',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger)),
                                SizedBox(height: 2),
                                Text('Permanently removes the group',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.danger),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Member: Leave Group ──────────────────────────────
                  TapBounce(
                    onTap: () {
                      Navigator.pop(ctx);
                      onLeave();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.exit_to_app_rounded,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Leave Group',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger)),
                                SizedBox(height: 2),
                                Text('You can rejoin with the invite code',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.danger),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameSheet(BuildContext context) {
    showModalBottomSheet(
      context       : context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RenameGroupSheet(group: group),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Horizontal Pitch Painter — A creative background for the TabBar
// ─────────────────────────────────────────────────────────────────────────────
class RealisticPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle grass surrounding the pitch
    final grassRect = Rect.fromLTWH(0, 0, w, h);
    final grassPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF235326).withValues(alpha: 0.0), // Fade to header green
          const Color(0xFF235326).withValues(alpha: 0.6), // Rich grass
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(grassRect);
    canvas.drawRect(grassRect, grassPaint);

    // 2. The Horizontal Pitch Trapezoid
    final topY = h * 0.15;
    final bottomY = h * 0.95;
    
    // We want the left bowling crease to be exactly at screen x = ~26.
    final pitchTopLeft = w * 0.05;
    final pitchTopRight = w * 0.95;
    final pitchBottomLeft = -w * 0.05;
    final pitchBottomRight = w * 1.05;

    final pitchPath = Path()
      ..moveTo(pitchTopLeft, topY)
      ..lineTo(pitchTopRight, topY)
      ..lineTo(pitchBottomRight, bottomY)
      ..lineTo(pitchBottomLeft, bottomY)
      ..close();

    // Realistic clay/dirt texture
    final pitchPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFB19B74), // deep dirt
          Color(0xFFDCC39A), // standard dry pitch clay
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    
    // Add subtle shadow for the pitch edges
    canvas.drawShadow(pitchPath, Colors.black.withValues(alpha: 0.3), 3.0, false);
    canvas.drawPath(pitchPath, pitchPaint);

    // 3. Crease Lines with 3D projection
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.square;

    double getX(double percent, double y) {
      if (y == topY) {
        return pitchTopLeft + (pitchTopRight - pitchTopLeft) * percent;
      } else {
        return pitchBottomLeft + (pitchBottomRight - pitchBottomLeft) * percent;
      }
    }

    // Positions for creases
    const leftBowlingPct = 0.08;
    const leftPoppingPct = 0.24;
    
    const rightBowlingPct = 0.92;
    const rightPoppingPct = 0.76;

    // Left Bowling
    canvas.drawLine(Offset(getX(leftBowlingPct, topY), topY), Offset(getX(leftBowlingPct, bottomY), bottomY), creasePaint);
    // Left Popping
    canvas.drawLine(Offset(getX(leftPoppingPct, topY), topY), Offset(getX(leftPoppingPct, bottomY), bottomY), creasePaint);

    // Right Bowling
    canvas.drawLine(Offset(getX(rightBowlingPct, topY), topY), Offset(getX(rightBowlingPct, bottomY), bottomY), creasePaint);
    // Right Popping
    canvas.drawLine(Offset(getX(rightPoppingPct, topY), topY), Offset(getX(rightPoppingPct, bottomY), bottomY), creasePaint);
    
    // Return Creases (horizontal lines)
    canvas.drawLine(Offset(getX(0.0, topY), topY), Offset(getX(leftPoppingPct, topY), topY), creasePaint);
    canvas.drawLine(Offset(getX(0.0, bottomY), bottomY), Offset(getX(leftPoppingPct, bottomY), bottomY), creasePaint);

    canvas.drawLine(Offset(getX(rightPoppingPct, topY), topY), Offset(getX(1.0, topY), topY), creasePaint);
    canvas.drawLine(Offset(getX(rightPoppingPct, bottomY), bottomY), Offset(getX(1.0, bottomY), bottomY), creasePaint);

    // Subtle middle pitch line (faded)
    final midPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(getX(0.5, topY), topY), Offset(getX(0.5, bottomY), bottomY), midPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
