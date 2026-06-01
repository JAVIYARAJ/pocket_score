import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/match_bloc.dart';
import 'bloc/match_list_bloc.dart';
import 'bloc/score_bloc.dart';
import 'bloc/group_cubit.dart' show GroupBloc, LoadGroups;
import 'bloc/profile_bloc.dart';
import 'bloc/auth_cubit.dart'
    show
        AuthBloc,
        PocketAuthState,
        AuthAuthenticated;
import 'config/supabase_config.dart';
import 'models/group_model.dart';
import 'models/match_models.dart';
import 'models/player_model.dart';
import 'services/match_repository.dart';
import 'services/group_repository.dart';
import 'services/profile_repository.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/match_setup_screen.dart';
import 'screens/team_selection_screen.dart';
import 'screens/team_preview_screen.dart';
import 'screens/toss_screen.dart';
import 'screens/opening_selection_screen.dart';
import 'screens/scoring_screen.dart';
import 'screens/result_screen.dart';
import 'screens/scorecard_screen.dart';
import 'screens/live_score_screen.dart';
import 'screens/player_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF8F9FA),
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const PocketScoreApp());
}

// ── Refresh-listenable that wakes the router on every Bloc state change ───────
class _StreamRefreshListenable extends ChangeNotifier {
  _StreamRefreshListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root app — StatefulWidget so the AuthBloc and GoRouter are created once
// ─────────────────────────────────────────────────────────────────────────────
class PocketScoreApp extends StatefulWidget {
  const PocketScoreApp({super.key});

  @override
  State<PocketScoreApp> createState() => _PocketScoreAppState();
}

class _PocketScoreAppState extends State<PocketScoreApp> {
  final _client = Supabase.instance.client;
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(_client);
    _router = _buildRouter();
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: _StreamRefreshListenable(_authBloc.stream),
      redirect: (context, state) {
        final isAuthed = _authBloc.state is AuthAuthenticated;
        final loc = state.matchedLocation;

        // Splash manages its own exit — never auto-redirect out of it.
        if (loc.startsWith('/splash')) return null;

        // Not signed in: send everything to auth.
        if (!isAuthed && loc != '/auth') return '/auth';

        // Already signed in but landed on auth: go home.
        if (isAuthed && loc == '/auth') return '/home';

        return null;
      },
      routes: [
        // ── Splash ─────────────────────────────────────────────────────
        GoRoute(
          path: '/splash',
          builder: (context, state) =>
              SplashScreen(onComplete: () => context.go('/home')),
        ),

        // ── Auth ────────────────────────────────────────────────────────
        GoRoute(
          path: '/auth',
          builder: (_, __) => const AuthScreen(),
        ),

        // ── Main shell (bottom navigation) ─────────────────────────────
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _MainShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/groups',
                builder: (_, __) => const GroupsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/rankings',
                  builder: (_, __) => const LeaderboardScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/profile',
                  builder: (_, __) => const ProfileScreen()),
            ]),
          ],
        ),

        // ── Group Detail ────────────────────────────────────────────────
        GoRoute(
          path: '/groups/:id',
          builder: (context, state) {
            final group = state.extra as Group;
            return GroupDetailScreen(group: group);
          },
        ),

        // ── Match flow ──────────────────────────────────────────────────
        GoRoute(
          path: '/match/setup',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final groupId = extra?['groupId'] as String?;
            final isRematch = extra?['isRematch'] as bool? ?? false;
            return MatchSetupScreen(preselectedGroupId: groupId, isRematch: isRematch);
          },
        ),
        GoRoute(path: '/match/teams', builder: (_, __) => const TeamSelectionScreen()),
        GoRoute(
          path: '/match/preview',
          builder: (context, state) {
            final extra = state.extra! as Map<String, dynamic>;
            return TeamPreviewScreen(
              teamA: extra['teamA'] as Team,
              teamB: extra['teamB'] as Team,
            );
          },
        ),
        GoRoute(path: '/match/toss', builder: (_, __) => const TossScreen()),
        GoRoute(
          path: '/match/opening',
          builder: (context, state) {
            final extra = state.extra! as Map<String, dynamic>;
            return OpeningSelectionScreen(
              battingTeamName: extra['battingTeamName'] as String,
              battingPlayers: extra['battingPlayers'] as List<Player>,
              bowlingPlayers: extra['bowlingPlayers'] as List<Player>,
              target: (extra['target'] as int?) ?? 0,
            );
          },
        ),
        GoRoute(path: '/match/result', builder: (_, __) => const ResultScreen()),

        // ── Live spectator view ─────────────────────────────────────────
        GoRoute(
          path: '/live/:matchId',
          builder: (context, state) {
            final extra = state.extra! as Map<String, dynamic>;
            return LiveScoreScreen(
              matchId   : state.pathParameters['matchId']!,
              teamAName : extra['teamAName']  as String,
              teamBName : extra['teamBName']  as String,
              totalOvers: (extra['totalOvers'] as int?) ?? 0,
            );
          },
        ),
        GoRoute(
          path: '/scorecard',
          builder: (context, state) {
            final scoreState = state.extra! as ScoreState;
            return ScorecardScreen(scoreState: scoreState);
          },
        ),

        // ── Player profile — opens from member lists, leaderboards, etc. ───
        GoRoute(
          path: '/player/:userId',
          builder: (context, state) {
            final extra       = state.extra as Map<String, dynamic>?;
            return PlayerProfileScreen(
              userId      : state.pathParameters['userId']!,
              displayName : extra?['displayName'] as String?,
              avatarUrl   : extra?['avatarUrl']   as String?,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final outfitBase = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => MatchBloc()),
        BlocProvider(create: (_) => MatchListBloc(MatchRepository(_client))),
        BlocProvider(create: (_) => ScoreBloc(MatchRepository(_client))),
        BlocProvider(create: (_) => GroupBloc(GroupRepository(_client))),
        BlocProvider(create: (_) => ProfileBloc(ProfileRepository(_client))),
      ],
      child: BlocListener<AuthBloc, PocketAuthState>(
        bloc: _authBloc,
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.read<MatchListBloc>().add(SyncMatchesFromSupabase());
            context.read<GroupBloc>().add(const LoadGroups());
            context.read<ProfileBloc>().add(const LoadProfile());
          }
        },
        child: MaterialApp.router(
          title: 'Pocket Score',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          theme: AppTheme.light.copyWith(
            textTheme: outfitBase.copyWith(
              displayLarge: outfitBase.displayLarge
                  ?.copyWith(color: AppColors.textPrimary),
              displayMedium: outfitBase.displayMedium
                  ?.copyWith(color: AppColors.textPrimary),
              headlineLarge: outfitBase.headlineLarge?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w800),
              headlineMedium: outfitBase.headlineMedium?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              titleLarge: outfitBase.titleLarge?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              titleMedium: outfitBase.titleMedium?.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              bodyLarge: outfitBase.bodyLarge
                  ?.copyWith(color: AppColors.textSecondary),
              bodyMedium: outfitBase.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              labelLarge: outfitBase.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            appBarTheme: AppTheme.light.appBarTheme.copyWith(
              titleTextStyle: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main shell — bottom navigation tab host.
// While a scoring session is active it renders ScoringScreen as a full-screen
// overlay (no bottom nav), matching the previous _MainApp behaviour.
// ─────────────────────────────────────────────────────────────────────────────
class _MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _MainShell({required this.shell});

  @override
  Widget build(BuildContext context) {
    final scoreState = context.watch<ScoreBloc>().state;
    if (scoreState.firstInnings != null) return const ScoringScreen();

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Builder(
            builder: (context) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final width = box.size.width;
                  final dx = details.localPosition.dx;
                  final targetIndex = (dx / (width / 4)).floor().clamp(0, 3);
                  if (shell.currentIndex != targetIndex) {
                    shell.goBranch(targetIndex, initialLocation: targetIndex == shell.currentIndex);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BottomNavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: shell.currentIndex == 0,
                        onTap: () => shell.goBranch(0, initialLocation: shell.currentIndex == 0),
                      ),
                      _BottomNavItem(
                        icon: Icons.group_outlined,
                        selectedIcon: Icons.group_rounded,
                        label: 'Groups',
                        isSelected: shell.currentIndex == 1,
                        onTap: () => shell.goBranch(1, initialLocation: shell.currentIndex == 1),
                      ),
                      _BottomNavItem(
                        icon: Icons.emoji_events_outlined,
                        selectedIcon: Icons.emoji_events_rounded,
                        label: 'Rankings',
                        isSelected: shell.currentIndex == 2,
                        onTap: () => shell.goBranch(2, initialLocation: shell.currentIndex == 2),
                      ),
                      _BottomNavItem(
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        isSelected: shell.currentIndex == 3,
                        onTap: () => shell.goBranch(3, initialLocation: shell.currentIndex == 3),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isSelected ? selectedIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.centerLeft,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : const SizedBox(width: 0, height: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
