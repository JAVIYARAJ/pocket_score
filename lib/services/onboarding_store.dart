import 'package:shared_preferences/shared_preferences.dart';

/// Remembers on the device whether the intro onboarding has been shown, so it
/// appears only once. Loaded at startup ([load]) so routing can decide
/// synchronously, without a flash of the wrong screen.
class OnboardingStore {
  static const _key = 'onboarding_seen_v1';
  static bool _seen = false;

  static bool get seen => _seen;

  static Future<void> load() async {
    try {
      _seen = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } catch (_) {
      // Storage unavailable: treat as seen rather than show it every launch.
      _seen = true;
    }
  }

  static Future<void> markSeen() async {
    _seen = true;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {}
  }
}
