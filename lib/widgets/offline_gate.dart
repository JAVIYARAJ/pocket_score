import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/connectivity_cubit.dart';
import '../theme/animations.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// Covers the whole app — every route, dialog and bottom sheet — with a
/// non-dismissible "no internet" screen while [ConnectivityCubit] is offline.
/// Sits above the Navigator (in `MaterialApp.builder`), so nothing underneath
/// can be tapped; it goes away by itself once the connection is back.
class OfflineGate extends StatelessWidget {
  final Widget child;
  const OfflineGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, bool>(
      // Close the keyboard so it doesn't float over the offline screen.
      listener: (_, online) {
        if (!online) FocusManager.instance.primaryFocus?.unfocus();
      },
      builder: (context, online) => Stack(
        children: [
          child,
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: online ? const SizedBox.shrink() : const _OfflineScreen(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineScreen extends StatefulWidget {
  const _OfflineScreen();

  @override
  State<_OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<_OfflineScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    await context.read<ConnectivityCubit>().check();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: EmptyState(
          art: EmptyArt.offline,
          title: 'No internet connection',
          message: 'Pocket Score needs the internet to save and sync matches. '
              "A match in progress is safe — you'll carry on right where you "
              "left off once you're back online.",
          action: Column(
            children: [
              TapBounce(
                onTap: _checking ? () {} : _retry,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_checking)
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _checking ? 'Checking…' : 'Try again',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Reconnecting automatically…',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
