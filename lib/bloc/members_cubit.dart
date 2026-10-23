import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/group_model.dart';
import '../models/player_model.dart';
import '../services/group_repository.dart';
import '../services/guest_repository.dart';
import 'group_cubit.dart' show groupErrorMessage;

/// State for one group's Members tab: joined members plus saved guests.
sealed class MembersState {
  const MembersState();
}

class MembersLoading extends MembersState {
  const MembersLoading();
}

class MembersLoaded extends MembersState {
  final List<GroupMember> members;

  /// The group's saved guests (people without the app), shared by all members.
  final List<Player> guests;
  const MembersLoaded(this.members, this.guests);
}

class MembersError extends MembersState {
  final String message;
  const MembersError(this.message);
}

class MembersCubit extends Cubit<MembersState> {
  final GroupRepository repo;
  final GuestRepository guestRepo;
  final String groupId;

  MembersCubit({required this.repo, required this.guestRepo, required this.groupId})
      : super(const MembersLoading()) {
    load();
  }

  /// Reloads members and guests. [quiet] keeps the current list on screen
  /// instead of flashing the loading skeleton.
  Future<void> load({bool quiet = false}) async {
    if (!quiet) emit(const MembersLoading());
    try {
      // Future.wait (not record .wait) so the original error reaches
      // groupErrorMessage instead of a ParallelWaitError wrapper.
      final results = await Future.wait<Object>([
        repo.getGroupMembers(groupId),
        // Members still show if only the guest list fails.
        guestRepo.getSavedGuests(groupId).catchError((Object _) => <Player>[]),
      ]);
      if (!isClosed) {
        emit(MembersLoaded(results[0] as List<GroupMember>, results[1] as List<Player>));
      }
    } catch (e) {
      if (!isClosed) emit(MembersError(groupErrorMessage(e)));
    }
  }

  /// Saves each name to the group's guests; returns how many failed.
  Future<int> addGuests(List<(String, PlayerRole)> guests) async {
    var failed = 0;
    for (final (name, role) in guests) {
      try {
        await guestRepo.saveGuest(groupId, name, role);
      } catch (_) {
        failed++;
      }
    }
    await load(quiet: true);
    return failed;
  }

  Future<void> removeGuest(String id) async {
    await guestRepo.deleteSavedGuest(id);
    await load(quiet: true);
  }

  /// Removes a member; errors propagate so the caller can show them.
  Future<void> kickMember(String userId) async {
    await repo.kickMember(groupId, userId);
    await load();
  }
}
