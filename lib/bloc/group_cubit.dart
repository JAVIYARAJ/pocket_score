import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/group_model.dart';
import '../services/group_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────────────
abstract class GroupState extends Equatable {
  const GroupState();
  @override
  List<Object?> get props => [];
}

class GroupInitial extends GroupState {
  const GroupInitial();
}

class GroupLoading extends GroupState {
  const GroupLoading();
}

class GroupLoaded extends GroupState {
  final List<Group> myGroups;

  const GroupLoaded({required this.myGroups});

  GroupLoaded copyWith({List<Group>? myGroups}) =>
      GroupLoaded(myGroups: myGroups ?? this.myGroups);

  @override
  List<Object?> get props => [myGroups];
}

class GroupError extends GroupState {
  final String message;
  const GroupError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// Cubit
// ─────────────────────────────────────────────────────────────────────────────
/// Manages the list of groups the signed-in user belongs to.
///
/// Not a HydratedCubit — group data is always fetched fresh from Supabase on
/// sign-in. Call [loadMyGroups] once in the auth listener in main.dart.
class GroupCubit extends Cubit<GroupState> {
  final GroupRepository _repo;
  GroupCubit(this._repo) : super(const GroupInitial());

  // ── Fetch ────────────────────────────────────────────────────────────────
  Future<void> loadMyGroups() async {
    emit(const GroupLoading());
    try {
      final groups = await _repo.getMyGroups();
      emit(GroupLoaded(myGroups: groups));
    } catch (e) {
      emit(GroupError(e.toString()));
    }
  }

  // ── Create ───────────────────────────────────────────────────────────────
  /// Creates a new group and prepends it to the list.
  /// Returns the created [Group] on success, null on failure.
  Future<Group?> createGroup(String name) async {
    final prev = _currentGroups;
    try {
      final group = await _repo.createGroup(name);
      emit(GroupLoaded(myGroups: [group, ...prev]));
      return group;
    } catch (e) {
      emit(GroupError(e.toString()));
      _restoreAfterError(prev);
      return null;
    }
  }

  // ── Join ─────────────────────────────────────────────────────────────────
  /// Joins a group via invite code.
  /// Returns the joined [Group] on success, null on failure.
  Future<Group?> joinGroup(String inviteCode) async {
    final prev = _currentGroups;
    try {
      final group = await _repo.joinGroup(inviteCode);
      final alreadyIn = prev.any((g) => g.id == group.id);
      emit(GroupLoaded(myGroups: alreadyIn ? prev : [group, ...prev]));
      return group;
    } catch (e) {
      emit(GroupError(e.toString()));
      _restoreAfterError(prev);
      return null;
    }
  }

  // ── Leave ────────────────────────────────────────────────────────────────
  Future<void> leaveGroup(String groupId) async {
    await _repo.leaveGroup(groupId);
    final updated = _currentGroups.where((g) => g.id != groupId).toList();
    emit(GroupLoaded(myGroups: updated));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  List<Group> get _currentGroups =>
      state is GroupLoaded ? (state as GroupLoaded).myGroups : const [];

  void _restoreAfterError(List<Group> prev) {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!isClosed) emit(GroupLoaded(myGroups: prev));
    });
  }
}
