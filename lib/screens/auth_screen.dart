import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../bloc/auth_cubit.dart' show AuthCubit, AuthError, AuthLoading, PocketAuthState;
import '../theme/app_theme.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

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
        body: BlocListener<AuthCubit, PocketAuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          child: BlocBuilder<AuthCubit, PocketAuthState>(
            builder: (context, state) {
              return Stack(
                children: [
                  // ── Background gradient ─────────────────────────
                  Container(
                    height: MediaQuery.of(context).size.height * 0.55,
                    decoration: const BoxDecoration(
                      gradient: AppColors.headerGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        // ── Top branding ──────────────────────────
                        const SizedBox(height: 48),
                        _buildBranding(),

                        const SizedBox(height: 40),

                        // ── Cricket illustration ──────────────────
                        _buildIllustration(),

                        const SizedBox(height: 40),

                        // ── Card ──────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _buildCard(context, state),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pocket Score',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Live Cricket Scorer',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _featureChip(Icons.wifi_rounded, 'Real-time'),
        const SizedBox(width: 10),
        _featureChip(Icons.people_rounded, 'Share Scores'),
        const SizedBox(width: 10),
        _featureChip(Icons.cloud_done_rounded, 'Cloud Sync'),
      ],
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, PocketAuthState state) {
    final isLoading = state is AuthLoading;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in to score matches, share live\nupdates and track player stats.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 28),

          // ── Google Sign-In button ───────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isLoading ? AppColors.surfaceLight : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: isLoading
                  ? []
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLoading
                    ? null
                    : () => context.read<AuthCubit>().signInWithGoogle(),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            SizedBox(width: 14),
                            Text(
                              'Opening Google Sign-In…',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Official Google multicolor logo
                            SvgPicture.asset(
                              'assets/icons/google_logo.svg',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Divider ─────────────────────────────────────────
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AppColors.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('More providers coming soon',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
              Expanded(child: Container(height: 1, color: AppColors.border)),
            ],
          ),

          const SizedBox(height: 20),

          // ── Info strip ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data is securely stored in the cloud and synced across devices.',
                    style: TextStyle(fontSize: 11, color: AppColors.primary, height: 1.4),
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
