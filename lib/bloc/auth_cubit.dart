import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../config/supabase_config.dart';

// ── States ────────────────────────────────────────────────────
// Named "PocketAuthState" to avoid collision with supabase_flutter's AuthState.
abstract class PocketAuthState extends Equatable {
  const PocketAuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends PocketAuthState {
  const AuthInitial();
}

class AuthLoading extends PocketAuthState {
  const AuthLoading();
}

class AuthAuthenticated extends PocketAuthState {
  final sb.User user;
  const AuthAuthenticated(this.user);
  @override
  List<Object?> get props => [user.id];
}

class AuthUnauthenticated extends PocketAuthState {
  const AuthUnauthenticated();
}

class AuthError extends PocketAuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Events ─────────────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class SignInWithGoogle extends AuthEvent {
  const SignInWithGoogle();
}

class SignOut extends AuthEvent {
  const SignOut();
}

/// Debug-only: email + password sign-in. Never used in release builds.
class SignInWithEmailPassword extends AuthEvent {
  final String email;
  final String password;
  const SignInWithEmailPassword({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

// Internal: fired from the Supabase auth stream — not for external use.
class _AuthStateChanged extends AuthEvent {
  final sb.User? user;
  final String? error;
  const _AuthStateChanged({this.user, this.error});
  @override
  List<Object?> get props => [user?.id, error];
}

// ── Bloc ─────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, PocketAuthState> {
  final sb.SupabaseClient _client;
  StreamSubscription<sb.AuthState>? _authSub;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: SupabaseConfig.googleWebClientId,
    clientId: (!kIsWeb && Platform.isIOS) ? SupabaseConfig.googleIosClientId : null,
    scopes: const ['email', 'profile'],
  );

  AuthBloc(this._client) : super(const AuthInitial()) {
    on<_AuthStateChanged>((event, emit) {
      if (event.error != null) {
        emit(AuthError(event.error!));
      } else if (event.user != null) {
        emit(AuthAuthenticated(event.user!));
      } else {
        emit(const AuthUnauthenticated());
      }
    });

    on<SignInWithGoogle>((event, emit) async {
      try {
        emit(const AuthLoading());

        debugPrint('[Auth] Starting Google Sign-In...');
        debugPrint('[Auth] serverClientId = ${SupabaseConfig.googleWebClientId}');

        final googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          debugPrint('[Auth] Google sign-in cancelled by user');
          emit(const AuthUnauthenticated());
          return;
        }

        debugPrint('[Auth] Google account selected: ${googleUser.email}');

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        debugPrint('[Auth] idToken is ${idToken == null ? "NULL ❌" : "present ✓"}');
        debugPrint('[Auth] accessToken is ${accessToken == null ? "NULL" : "present ✓"}');

        if (idToken == null) {
          emit(const AuthError(
            'No ID token from Google.\n'
            'Check: Web Client ID is correct in SupabaseConfig, '
            'and Android OAuth client is registered in Google Cloud Console.',
          ));
          return;
        }

        debugPrint('[Auth] Sending token to Supabase...');

        await _client.auth.signInWithIdToken(
          provider: sb.OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        debugPrint('[Auth] Supabase signInWithIdToken succeeded ✓');
        // onAuthStateChange fires → _AuthStateChanged → AuthAuthenticated

      } on sb.AuthException catch (e) {
        debugPrint('[Auth] Supabase AuthException: ${e.message} (status: ${e.statusCode})');
        emit(AuthError('Supabase error: ${e.message}'));
      } catch (e) {
        debugPrint('[Auth] Unexpected error: $e');
        emit(AuthError(e.toString()));
      }
    });

    on<SignOut>((event, emit) async {
      await Future.wait([
        _client.auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      // onAuthStateChange fires → _AuthStateChanged → AuthUnauthenticated
    });

    // Debug-only: email + password sign-in (never compiled into release builds
    // because the UI that dispatches this event is gated by kDebugMode).
    on<SignInWithEmailPassword>((event, emit) async {
      try {
        emit(const AuthLoading());
        await _client.auth.signInWithPassword(
          email   : event.email.trim(),
          password: event.password,
        );
        // onAuthStateChange fires → _AuthStateChanged → AuthAuthenticated
      } on sb.AuthException catch (e) {
        emit(AuthError('Auth error: ${e.message}'));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    // Seed from the current session (synchronous on cold start).
    final session = _client.auth.currentSession;
    add(_AuthStateChanged(user: session?.user));

    // Stay in sync with future auth changes (sign-in from elsewhere, token expiry).
    _authSub = _client.auth.onAuthStateChange.listen(
      (data) => add(_AuthStateChanged(user: data.session?.user)),
      onError: (e) => add(_AuthStateChanged(error: e.toString())),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  sb.User? get currentUser => _client.auth.currentUser;
  String?  get userId      => currentUser?.id;
  String?  get userEmail   => currentUser?.email;
  String?  get userName    =>
      currentUser?.userMetadata?['full_name'] as String? ??
      currentUser?.userMetadata?['name']      as String? ??
      currentUser?.email?.split('@').first;
  String?  get avatarUrl   => currentUser?.userMetadata?['avatar_url'] as String?;

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
