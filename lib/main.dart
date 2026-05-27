import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bloc/player_bloc.dart';
import 'bloc/match_bloc.dart';
import 'bloc/match_list_bloc.dart';
import 'bloc/score_bloc.dart';
import 'bloc/group_cubit.dart';
import 'bloc/auth_cubit.dart'
    show
        AuthCubit,
        PocketAuthState,
        AuthInitial,
        AuthLoading,
        AuthAuthenticated;
import 'config/supabase_config.dart';
import 'services/match_repository.dart';
import 'services/player_repository.dart';
import 'services/group_repository.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/scoring_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory(
            (await getApplicationDocumentsDirectory()).path),
  );

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const PocketScoreApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Root app
// ─────────────────────────────────────────────────────────────────────────────
class PocketScoreApp extends StatelessWidget {
  const PocketScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final outfitBase = GoogleFonts.outfitTextTheme(ThemeData.light().textTheme);

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthCubit(client)),
        BlocProvider(create: (_) => PlayerBloc(PlayerRepository(client))),
        BlocProvider(create: (_) => MatchBloc()),
        BlocProvider(create: (_) => MatchListBloc(MatchRepository(client))),
        BlocProvider(create: (_) => ScoreBloc(MatchRepository(client))),
        BlocProvider(create: (_) => GroupCubit(GroupRepository(client))),
      ],
      child: MaterialApp(
        title: 'Pocket Score',
        debugShowCheckedModeBanner: false,
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
        home: const _AppRoot(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppRoot — persistent widget that lives for the whole app lifetime.
//
// Responsibilities:
//  • Shows SplashScreen on first launch (with minimum display gate).
//  • Once splash signals completion, switches to the auth-appropriate screen.
//  • Continuously listens to AuthCubit so EVERY future sign-in and sign-out
//    is handled automatically — no Navigator calls needed in AuthScreen or
//    ProfileScreen.
// ─────────────────────────────────────────────────────────────────────────────
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  // Flips to true once SplashScreen calls onComplete().
  bool _splashDone = false;

  void _onSplashComplete() {
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // ── Phase 1: splash ────────────────────────────────────────────
    if (!_splashDone) {
      return SplashScreen(onComplete: _onSplashComplete);
    }

    // ── Phase 2: auth-aware routing (persists forever) ─────────────
    //
    // BlocListener  → side-effects (sync cloud data on sign-in)
    // BlocBuilder   → rebuild UI on every auth state change
    //
    // This is the single source of truth for routing. AuthScreen and
    // ProfileScreen just call cubit.signIn() / cubit.signOut() and this
    // widget reacts automatically.
    return BlocListener<AuthCubit, PocketAuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.read<PlayerBloc>().add(SyncPlayersFromSupabase());
          context.read<MatchListBloc>().add(SyncMatchesFromSupabase());
          context.read<GroupCubit>().loadMyGroups();
        }
      },
      child: BlocBuilder<AuthCubit, PocketAuthState>(
        builder: (context, state) {
          // Auth still resolving (very rare after splash gate)
          if (state is AuthInitial || state is AuthLoading) {
            return const _LoadingScreen();
          }

          if (state is AuthAuthenticated) {
            return const _MainApp();
          }

          // AuthUnauthenticated or AuthError
          return const AuthScreen();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin fallback shown if auth is still resolving after the splash timer
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF064E3B),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main app — live match takes over scoring screen, otherwise home
// ─────────────────────────────────────────────────────────────────────────────
class _MainApp extends StatelessWidget {
  const _MainApp();

  @override
  Widget build(BuildContext context) {
    final scoreState = context.watch<ScoreBloc>().state;
    if (scoreState.firstInnings != null) return const ScoringScreen();
    return const HomeScreen();
  }
}
