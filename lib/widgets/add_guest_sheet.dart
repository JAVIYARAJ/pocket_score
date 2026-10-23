import 'package:flutter/material.dart';

import '../models/player_model.dart';
import '../theme/animations.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add Guest Player bottom sheet — used from a group's Members tab and from
// team selection in solo matches. [onAdd] is called once per entered name.
// ─────────────────────────────────────────────────────────────────────────────
class AddGuestSheet extends StatefulWidget {
  final void Function(String name, PlayerRole role) onAdd;
  const AddGuestSheet({super.key, required this.onAdd});

  @override
  State<AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<AddGuestSheet> {
  final _ctrl = TextEditingController();
  final ValueNotifier<PlayerRole> _roleNotifier = ValueNotifier<PlayerRole>(PlayerRole.allRounder);
  final ValueNotifier<bool> _multiLineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _hasTextNotifier.value = _ctrl.text.trim().isNotEmpty;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _roleNotifier.dispose();
    _multiLineNotifier.dispose();
    _hasTextNotifier.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final names = _multiLineNotifier.value
        ? text
            .split(RegExp(r'[,;\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : [text];

    for (final name in names) {
      widget.onAdd(name, _roleNotifier.value);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Add Guest Player',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                  'Saved for future matches. Guest scores are tracked per match but not shown in the leaderboard.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),

                // Mode Selector Segmented Control (Single vs Bulk)
                ValueListenableBuilder<bool>(
                  valueListenable: _multiLineNotifier,
                  builder: (context, isBulk, _) {
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tabWidth = constraints.maxWidth / 2;
                          return SizedBox(
                            height: 38,
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.fastOutSlowIn,
                                  left: isBulk ? tabWidth : 0,
                                  top: 0,
                                  bottom: 0,
                                  width: tabWidth,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    _modeTab('Single Player', false, isBulk),
                                    _modeTab('Bulk Add (Multiple)', true, isBulk),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    );
                  }
                ),
                const SizedBox(height: 20),

                // Name field
                ValueListenableBuilder<bool>(
                  valueListenable: _multiLineNotifier,
                  builder: (context, isBulk, _) {
                    return TextField(
                      controller: _ctrl,
                      autofocus: true,
                      maxLines: isBulk ? 4 : 1,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: isBulk ? 'Player Names' : 'Player Name',
                        hintText: isBulk
                            ? 'One name per line, or comma-separated'
                            : 'Enter player name',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: isBulk
                            ? null
                            : const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    );
                  }
                ),
                const SizedBox(height: 20),

                // Role selector
                const Text('ROLE',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ValueListenableBuilder<PlayerRole>(
                  valueListenable: _roleNotifier,
                  builder: (context, currentRole, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlayerRole.values.map((role) {
                        final selected = currentRole == role;
                        return TapBounce(
                          onTap: () => _roleNotifier.value = role,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border),
                            ),
                            child: Text(
                              _roleLabel(role),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }
                ),
                const SizedBox(height: 24),

                // Add button
                ValueListenableBuilder<bool>(
                  valueListenable: _hasTextNotifier,
                  builder: (context, hasText, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _multiLineNotifier,
                      builder: (context, isBulk, _) {
                        final isEnabled = hasText;
                        return SizedBox(
                          width: double.infinity,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: isEnabled ? AppColors.primaryGradient : null,
                              color: isEnabled ? null : AppColors.border.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isEnabled
                                  ? [
                                      BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4))
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton(
                              onPressed: isEnabled ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                disabledForegroundColor: AppColors.textMuted,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                isBulk ? 'Add Players' : 'Add Player',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isEnabled ? Colors.white : AppColors.textMuted),
                              ),
                            ),
                          ),
                        );
                      }
                    );
                  }
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, bool value, bool currentValue) {
    final bool active = currentValue == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _multiLineNotifier.value = value,
        child: Center(
          // Plain Text (not AnimatedDefaultTextStyle) so the app font is kept.
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(PlayerRole role) {
    switch (role) {
      case PlayerRole.batsman:      return 'Batsman';
      case PlayerRole.bowler:       return 'Bowler';
      case PlayerRole.allRounder:   return 'All-Rounder';
      case PlayerRole.wicketKeeper: return 'WK';
    }
  }
}
