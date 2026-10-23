import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the app can actually reach its backend — not just whether Wi-Fi or
/// mobile data is switched on (a router with no internet still reports Wi-Fi).
/// State is `true` while online.
///
/// While offline it also swallows the Android back button, so the screen under
/// the full-screen offline block can't be popped (e.g. the scoring screen's
/// discard dialog opening unseen behind it). That only works because the
/// cubit is created before the router registers its own back handler.
class ConnectivityCubit extends Cubit<bool> with WidgetsBindingObserver {
  final Future<bool> Function() _probe;
  late final StreamSubscription<List<ConnectivityResult>> _changes;
  Timer? _poll;
  Future<void>? _inFlight;

  static const _offlinePoll = Duration(seconds: 4);
  static const _onlinePoll = Duration(seconds: 20);
  static const _confirmDelay = Duration(seconds: 2);

  ConnectivityCubit({
    required String probeHost,
    Stream<List<ConnectivityResult>>? changes,
    Future<bool> Function()? probe,
  })  : _probe = probe ?? (() => _canReach(probeHost)),
        // Assume online so the app doesn't flash the offline screen at launch.
        super(true) {
    WidgetsBinding.instance.addObserver(this);
    _changes = (changes ?? Connectivity().onConnectivityChanged).listen((r) {
      if (r.every((c) => c == ConnectivityResult.none)) {
        _setOnline(false); // radios off: no need to probe
      } else {
        check();
      }
    });
    check();
  }

  /// Re-tests the connection (e.g. from a "Try again" button). Concurrent
  /// calls share one check.
  Future<void> check() => _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    var ok = await _probe();
    if (!ok && state) {
      // One failed probe on a flaky network shouldn't block the whole app.
      await Future<void>.delayed(_confirmDelay);
      if (isClosed) return;
      ok = await _probe();
    }
    _setOnline(ok);
  }

  void _setOnline(bool online) {
    if (isClosed) return;
    emit(online);
    // Polling catches changes the OS doesn't report, like internet dropping
    // on a Wi-Fi network that stays connected.
    _poll?.cancel();
    _poll = Timer(online ? _onlinePoll : _offlinePoll, check);
  }

  static Future<bool> _canReach(String host) async {
    if (kIsWeb) return true; // no raw sockets on web
    try {
      // A real TCP connect — DNS lookups can be answered from cache offline.
      final socket = await Socket.connect(host, 443,
          timeout: const Duration(seconds: 4));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  @override
  Future<bool> didPopRoute() async => !state; // consume back while offline

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _changes.cancel();
    return super.close();
  }
}
