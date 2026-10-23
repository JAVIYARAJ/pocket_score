part of '../scoring_screen.dart';

// New-batter picker shown after a wicket or retirement.

/// Recap shown on the LED board above the batter picker.
class _BatterBoard {
  final String eyebrow;  // e.g. "WICKET" / "NEW BATTER"
  final String headline; // e.g. the out batter's name / "Striker"
  final String detail;   // e.g. "14 (9) · caught"
  final String score;    // team score, e.g. "86/3"
  const _BatterBoard(this.eyebrow, this.headline, this.detail, this.score);
}

/// Choose the next batter: an LED recap, then the waiting batters as swipeable
/// cards and a "Send in …" button — the batting twin of the bowler picker.
/// [compact] drops the board and title (used inside the run-out step).
class _BatterPicker extends StatefulWidget {
  final ScoreState state;
  final List<Player> players;
  final _BatterBoard? board;
  final String? subtitle;
  final bool compact;
  final ValueChanged<String> onPick;

  const _BatterPicker({
    required this.state,
    required this.players,
    required this.onPick,
    this.board,
    this.subtitle,
    this.compact = false,
  });

  @override
  State<_BatterPicker> createState() => _BatterPickerState();
}

class _BatterPickerState extends State<_BatterPicker> {
  late final PageController _pages = PageController(viewportFraction: 0.64);
  int _index = 0;

  static const _amber = Color(0xFFFCD34D);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    if (players.isEmpty) return const SizedBox.shrink();
    final index = _index.clamp(0, players.length - 1);
    final chosen = players[index];
    final board = widget.board;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!widget.compact && board != null) ...[
        // ── LED recap ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B), width: 3),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(board.eyebrow,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                      color: board.eyebrow == 'WICKET' ? const Color(0xFFFCA5A5) : _amber,
                      shadows: const [Shadow(color: Color(0x66FCD34D), blurRadius: 8)],
                    )),
                const SizedBox(height: 4),
                Text(board.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text(board.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(board.score,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _amber,
                    fontFeatures: [FontFeature.tabularFigures()],
                    shadows: [Shadow(color: Color(0x99FCD34D), blurRadius: 12)],
                  )),
              const SizedBox(height: 3),
              Text('SCORE',
                  style: TextStyle(fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.45))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('WHO WALKS IN?',
            style: TextStyle(fontSize: 10.5, letterSpacing: 1.8, fontWeight: FontWeight.w800, color: AppColors.scoreBlueLight)),
        const Text('Send in the next batter',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        if (widget.subtitle != null)
          Text(widget.subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 12),
      ],
      // ── Waiting batters ────────────────────────────────────────
      SizedBox(
        height: widget.compact ? 172 : 196,
        child: PageView.builder(
          controller: _pages,
          itemCount: players.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => AnimatedBuilder(
            animation: _pages,
            builder: (context, child) {
              final page = _pages.hasClients && _pages.position.haveDimensions
                  ? (_pages.page ?? index.toDouble())
                  : index.toDouble();
              final focus = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Transform.scale(
                scale: 0.86 + 0.14 * focus,
                child: Opacity(opacity: 0.55 + 0.45 * focus, child: child),
              );
            },
            child: GestureDetector(
              onTap: () => _pages.animateToPage(i,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
              child: _BatterCard(player: players[i], state: widget.state),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < players.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: i == index ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == index ? AppColors.scoreBlueLight : AppColors.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      // ── Send in … ──────────────────────────────────────────────
      TapBounce(
        onTap: () => widget.onPick(chosen.id),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.scoreBlueLight, AppColors.scoreBlue]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.scoreBlue.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Send in ${chosen.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Trading-card style batter: tag, avatar, role, and the innings so far for
/// a retired batter coming back.
class _BatterCard extends StatelessWidget {
  final Player player;
  final ScoreState state;
  const _BatterCard({required this.player, required this.state});

  static String _role(PlayerRole r) => switch (r) {
        PlayerRole.batsman      => 'BATTER',
        PlayerRole.bowler       => 'BOWLER',
        PlayerRole.allRounder   => 'ALL-ROUNDER',
        PlayerRole.wicketKeeper => 'KEEPER',
      };

  @override
  Widget build(BuildContext context) {
    final retired = state.retiredHurtIds.contains(player.id);
    final st = state.currentInnings?.batsmanStats[player.id];
    final tag = retired ? 'RE-ENTRY' : 'FRESH';
    final tagColor = retired ? const Color(0xFFFCD34D) : const Color(0xFF93C5FD);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A), Color(0xFF0B1220)],
        ),
        boxShadow: [BoxShadow(color: AppColors.scoreBlue.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          // Faint bat for texture
          Positioned(
            right: -18,
            top: -14,
            child: Icon(Icons.sports_cricket_rounded, size: 110, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tagColor.withValues(alpha: 0.5)),
                ),
                child: Text(tag,
                    style: TextStyle(fontSize: 8.5, letterSpacing: 1.1, fontWeight: FontWeight.w900, color: tagColor)),
              ),
              const Spacer(),
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(player.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(player.isGuest ? 'GUEST' : _role(player.role),
                        style: TextStyle(fontSize: 9, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.55))),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  retired && st != null
                      ? '${st.runs} (${st.ballsFaced})  ·  SR ${st.strikeRate.toStringAsFixed(0)}'
                      : 'Yet to bat',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
