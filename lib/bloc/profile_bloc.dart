import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_profile.dart';
import '../services/profile_repository.dart';

// ── Events ─────────────────────────────────────────────────────────────────
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {
  const LoadProfile();
}

class UpdatePlayerPreferences extends ProfileEvent {
  final String playerRole;
  final String battingStyle;
  final String bowlingStyle;

  const UpdatePlayerPreferences({
    required this.playerRole,
    required this.battingStyle,
    required this.bowlingStyle,
  });

  @override
  List<Object?> get props => [playerRole, battingStyle, bowlingStyle];
}

// ── States ──────────────────────────────────────────────────────────────────
abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final UserProfile profile;
  const ProfileLoaded(this.profile);
  @override
  List<Object?> get props => [profile];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Bloc ─────────────────────────────────────────────────────────────────────
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository _repo;

  ProfileBloc(this._repo) : super(const ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      emit(const ProfileLoading());
      try {
        final profile = await _repo.getMyProfile();
        if (profile != null) {
          emit(ProfileLoaded(profile));
        } else {
          emit(const ProfileError('Profile not found'));
        }
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });

    on<UpdatePlayerPreferences>((event, emit) async {
      final current = state is ProfileLoaded
          ? (state as ProfileLoaded).profile
          : null;
      try {
        await _repo.updatePreferences(
          playerRole   : event.playerRole,
          battingStyle : event.battingStyle,
          bowlingStyle : event.bowlingStyle,
        );
        if (current != null) {
          emit(ProfileLoaded(current.copyWith(
            playerRole   : event.playerRole,
            battingStyle : event.battingStyle,
            bowlingStyle : event.bowlingStyle,
          )));
        } else {
          add(const LoadProfile());
        }
      } catch (e) {
        emit(ProfileError(e.toString()));
      }
    });
  }
}
