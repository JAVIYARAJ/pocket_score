import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/score_bloc.dart';
import '../services/match_repository.dart';
import '../theme/app_theme.dart';
import '../theme/animations.dart';
import '../widgets/premium_header.dart';

/// Spectator screen — subscribes to a live match via Supabase Realtime.
/// Anyone who has the match ID can open this screen to watch the score update
/// in real-time without being the scorer.
class LiveScoreScreen extends StatefulWidget {
  final String matchId;
  final String teamAName;
  final String teamBName;

  const LiveScoreScreen({
    super.key,
    required this.matchId,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  late final MatchRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = MatchRepository(Supabase.instance.client);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>?>(
                stream: _repo.watchLiveScore(widget.matchId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _LoadingView();
                  }
                  if (snap.hasError) {
                    return _ErrorView(message: snap.error.toString());
                  }
                  if (snap.data == null) {
                    return const _EndedView();
                  }
                  try {
                    final score = ScoreState.fromJson(snap.data!);
                    return _LiveBody(score: score);
                  } catch (_) {
                    return const _ErrorView(message: 'Could not parse score data.');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return PremiumHeader(
      title: '${widget.teamAName}  vs  ${widget.teamBName}',
      titleWidget: Text(
        '${widget.teamAName}  vs  ${widget.teamBName}',
        style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: -0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitleWidget: Row(
        children: [
          PulseAnimation(
            child: Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'LIVE SPECTATOR',
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: Color(0xFF4ADE80), letterSpacing: 1.5,
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Live body ─────────────────────────────────────────────────
class _LiveBody extends StatelessWidget {
  final ScoreState score;
  const _LiveBody({required this.score});

  @override
  Widget build(BuildContext context) {
    final innings = score.currentInnings;
    if (innings == null) return const _LoadingView();

    final displayBalls = innings.balls.length > 12
        ? innings.balls.sublist(innings.balls.length - 12)
        : innings.balls;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          // ── Scoreboard card ────────────────────────────
          FadeInEntrance(
            offset: const Offset(0, 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: AppColors.scoreGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    innings.battingTeamName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${innings.totalRuns}/${innings.totalWickets}',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '(${innings.overDisplay} overs)',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (innings.target > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Target ${innings.target}  •  Need ${innings.target - innings.totalRuns} runs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Run rates ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  'RUN RATE',
                  innings.runRate.toStringAsFixed(2),
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: innings.target > 0
                    ? _StatCard(
                        'TARGET',
                        '${innings.target}',
                        AppColors.warning,
                      )
                    : _StatCard(
                        'Wickets',
                        '${innings.totalWickets}/10',
                        AppColors.danger,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Recent balls ───────────────────────────────
          if (displayBalls.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECENT BALLS',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: AppColors.textMuted, letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: displayBalls
                          .map((b) => _BallChip(ball: b))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Ball chip ─────────────────────────────────────────────────
class _BallChip extends StatelessWidget {
  final dynamic ball;
  const _BallChip({required this.ball});

  @override
  Widget build(BuildContext context) {
    final isWicket = (ball.isWicket as bool?) ?? false;
    final runs     = (ball.runs as int?) ?? 0;
    final typeStr  = (ball.type?.toString() ?? '').toLowerCase();
    final isWide   = typeStr.contains('wide');
    final isNoBall = typeStr.contains('noball') || typeStr.contains('no_ball');

    Color bg; Color fg; String label;
    if (isWicket) {
      bg = AppColors.danger;     fg = Colors.white;       label = 'W';
    } else if (runs == 6) {
      bg = AppColors.success;    fg = Colors.white;       label = '6';
    } else if (runs == 4) {
      bg = AppColors.info;       fg = Colors.white;       label = '4';
    } else if (isWide) {
      bg = AppColors.warning.withValues(alpha: 0.15);
      fg = AppColors.warning;    label = 'Wd';
    } else if (isNoBall) {
      bg = AppColors.accent.withValues(alpha: 0.15);
      fg = AppColors.accent;     label = 'Nb';
    } else {
      bg = AppColors.surfaceLight;
      fg = AppColors.textSecondary;
      label = '$runs';
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.7), letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

// ── State views ───────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        SizedBox(height: 16),
        Text(
          'Connecting to live score…',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ],
    ),
  );
}

class _EndedView extends StatelessWidget {
  const _EndedView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sports_cricket_outlined, size: 52, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        const Text(
          'Match has ended',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'The live score is no longer available.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Go Back'),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text(
            'Connection error',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    ),
  );
}
