import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart' show AuthBloc;
import '../bloc/profile_bloc.dart';
import '../theme/animations.dart';
import '../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Player card customization sheet — role, batting and bowling style.
///
/// Shared by the first-time setup on Home ([firstTime] = true: not dismissible,
/// "Start Playing" CTA) and the "Customize Player Card" action on Profile.
/// The header shows a live preview of the card as the user picks options.
/// ─────────────────────────────────────────────────────────────────────────────
class PlayerCardSheet extends StatefulWidget {
  final bool firstTime;

  const PlayerCardSheet._({required this.firstTime});

  static Future<void> show(BuildContext context, {bool firstTime = false}) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true, // Keeps the bottom nav from overlapping
      isScrollControlled: true,
      isDismissible: !firstTime,
      enableDrag: !firstTime,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerCardSheet._(firstTime: firstTime),
    );
  }

  @override
  State<PlayerCardSheet> createState() => _PlayerCardSheetState();
}

// Stored values must stay exactly as-is — they're persisted in `profiles`.
const _roles = [
  _Option('Batsman', 'Runs on the board', AppColors.info),
  _Option('Bowler', 'Wickets in the bag', AppColors.danger),
  _Option('All-Rounder', 'Bat and ball, both', AppColors.accent),
  _Option('Wicketkeeper', 'Gloves behind stumps', AppColors.primary),
];
const _battingStyles = ['Right-hand Bat', 'Left-hand Bat'];
const _noBowling = 'None';

class _Option {
  final String value;
  final String blurb;
  final Color color;
  const _Option(this.value, this.blurb, this.color);
}

class _PlayerCardSheetState extends State<PlayerCardSheet> {
  late String _role;
  late String _batting;
  late String _bowling;

  @override
  void initState() {
    super.initState();
    final s = context.read<ProfileBloc>().state;
    final profile = s is ProfileLoaded ? s.profile : null;
    _role = profile?.playerRole ?? 'All-Rounder';
    _batting = profile?.battingStyle ?? 'Right-hand Bat';
    _bowling = profile?.bowlingStyle ?? 'Right-arm Fast';
  }

  void _save() {
    context.read<ProfileBloc>().add(UpdatePlayerPreferences(
          playerRole: _role,
          battingStyle: _batting,
          bowlingStyle: _bowling,
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Your role', Icons.person_rounded),
                    const SizedBox(height: 12),
                    _roleGrid(),
                    const SizedBox(height: 24),
                    const _SectionLabel(
                        'Batting', Icons.sports_cricket_rounded),
                    const SizedBox(height: 12),
                    _HandToggle(
                      value: _batting,
                      onChanged: (v) => setState(() => _batting = v),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel(
                        'Bowling', Icons.sports_baseball_rounded),
                    const SizedBox(height: 12),
                    _bowlingGrid(),
                  ],
                ),
              ),
            ),
            _footer(media.padding.bottom),
          ],
        ),
      ),
    );
  }

  // ── Header with live card preview ──
  Widget _header() {
    final auth = context.read<AuthBloc>();
    final saved = context.select<ProfileBloc, String?>((b) {
      final s = b.state;
      return s is ProfileLoaded ? s.profile.fullName?.trim() : null;
    });
    final name =
        saved != null && saved.isNotEmpty ? saved : (auth.userName ?? 'Player');
    final avatarUrl = auth.avatarUrl;
    final role =
        _roles.firstWhere((r) => r.value == _role, orElse: () => _roles[2]);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Stack(
        children: [
          // Faint oversized bat for texture
          Positioned(
            right: -24,
            top: -10,
            child: Icon(Icons.sports_cricket_rounded,
                size: 150, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.firstTime
                                ? 'Welcome to Pocket Score!'
                                : 'Customize Player Card',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.firstTime
                                ? 'Build your player card to get started.'
                                : 'Tap an option to see your card update.',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.firstTime)
                      TapBounce(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _PreviewCard(
                  name: name,
                  avatarUrl: avatarUrl,
                  role: role,
                  batting: _batting,
                  bowling: _bowling,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Role: 2×2 grid of tiles ──
  Widget _roleGrid() {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final r in _roles)
            SizedBox(
              width: w,
              child: _RoleTile(
                option: r,
                selected: _role == r.value,
                onTap: () => setState(() => _role = r.value),
              ),
            ),
        ],
      );
    });
  }

  // ── Bowling: arm × pace grid + "don't bowl" ──
  Widget _bowlingGrid() {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      Widget tile(String arm, String pace) {
        final value = '$arm-arm $pace';
        return SizedBox(
          width: w,
          child: _BowlTile(
            arm: arm,
            pace: pace,
            selected: _bowling == value,
            onTap: () => setState(() => _bowling = value),
          ),
        );
      }

      return Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              tile('Right', 'Fast'),
              tile('Right', 'Spin'),
              tile('Left', 'Fast'),
              tile('Left', 'Spin'),
            ],
          ),
          const SizedBox(height: 10),
          _NoBowlTile(
            selected: _bowling == _noBowling,
            onTap: () => setState(() => _bowling = _noBowling),
          ),
        ],
      );
    });
  }

  Widget _footer(double safeBottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, safeBottom + 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: TapBounce(
        onTap: _save,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  widget.firstTime
                      ? Icons.sports_cricket_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18),
              const SizedBox(width: 8),
              Text(
                widget.firstTime ? 'Start Playing' : 'Save Player Card',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live preview card ────────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final _Option role;
  final String batting;
  final String bowling;

  const _PreviewCard({
    required this.name,
    required this.avatarUrl,
    required this.role,
    required this.batting,
    required this.bowling,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    role.color,
                    Colors.white.withValues(alpha: 0.6)
                  ]),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? Image.network(avatarUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initialAvatar(initial))
                      : _initialAvatar(initial),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 5),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: a, child: child)),
                      child: Container(
                        key: ValueKey(role.value),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: role.color.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoleGlyph(role.value,
                                color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text(role.value.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _PreviewStat('BATTING', batting)),
              Container(
                  width: 1,
                  height: 26,
                  color: Colors.white.withValues(alpha: 0.12)),
              Expanded(
                  child: _PreviewStat('BOWLING',
                      bowling == _noBowling ? "Doesn't bowl" : bowling)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initialAvatar(String initial) => Container(
        width: 48,
        height: 48,
        color: AppColors.primaryDark,
        alignment: Alignment.center,
        child: Text(initial,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      );
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.white.withValues(alpha: 0.55))),
        const SizedBox(height: 3),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                  .animate(a),
              child: child,
            ),
          ),
          child: Text(value,
              key: ValueKey(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ],
    );
  }
}

// ── Building blocks ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

/// Role icon — uses the app's stumps artwork for the keeper, where it fits
/// better than any Material icon.
class _RoleGlyph extends StatelessWidget {
  final String role;
  final Color color;
  final double size;
  const _RoleGlyph(this.role, {required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    Widget asset(String path) => Image.asset(path,
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn);
    switch (role) {
      case 'Bowler':
        return Icon(Icons.sports_baseball_rounded, color: color, size: size);
      case 'Wicketkeeper':
        return asset('assets/icons/wickets.png');
      case 'All-Rounder':
        return Icon(Icons.bolt_rounded, color: color, size: size);
      default:
        return Icon(Icons.sports_cricket_rounded, color: color, size: size);
    }
  }
}

class _RoleTile extends StatelessWidget {
  final _Option option;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTile(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = option.color;
    return TapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? c : AppColors.border,
              width: selected ? 1.8 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: c.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ]
              : const [
                  BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c : c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _RoleGlyph(option.value,
                      color: selected ? Colors.white : c, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected ? c : AppColors.textPrimary)),
                      const SizedBox(height: 1),
                      Text(option.blurb,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: -8,
              right: -4,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sliding two-way toggle for batting hand.
class _HandToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _HandToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isLeft = value == _battingStyles[1];
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                for (final style in _battingStyles)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(style),
                      child: _handLabel(style, value == style),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handLabel(String style, bool selected) {
    final left = style == _battingStyles[1];
    final color = selected ? Colors.white : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mirror the bat for left-handers.
        Transform.flip(
          flipX: left,
          child: Icon(Icons.sports_cricket_rounded, size: 17, color: color),
        ),
        const SizedBox(width: 7),
        Text(
          left ? 'Left-hand' : 'Right-hand',
          style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color),
        ),
      ],
    );
  }
}

class _BowlTile extends StatelessWidget {
  final String arm;
  final String pace;
  final bool selected;
  final VoidCallback onTap;
  const _BowlTile(
      {required this.arm,
      required this.pace,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fast = pace == 'Fast';
    final c = fast ? AppColors.danger : AppColors.noBall;
    return TapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? c : AppColors.border,
              width: selected ? 1.8 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? c : c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(fast ? Icons.bolt_rounded : Icons.cyclone_rounded,
                  size: 19, color: selected ? Colors.white : c),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pace,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? c : AppColors.textPrimary)),
                  Text('$arm-arm',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBowlTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _NoBowlTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const c = AppColors.textSecondary;
    return TapBounce(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? c : AppColors.border,
              width: selected ? 1.8 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.do_not_disturb_alt_rounded,
                size: 16, color: selected ? c : AppColors.textMuted),
            const SizedBox(width: 8),
            Text("I don't bowl",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? c : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
