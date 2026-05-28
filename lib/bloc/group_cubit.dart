import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/group_model.dart';
import '../services/group_repository.dart';

// ── Events ─────────────────────────────────────────────────────
abstract class GroupEvent extends Equatable {
  const GroupEvent();
  @override
  List<Object?> get props => [];
}

class LoadGroups extends GroupEvent {
  const LoadGroups();
}

class CreateGroupEvent extends GroupEvent {
  final String name;
  const CreateGroupEvent(this.name);
  @override
  List<Object?> get props => [name];
}

class JoinGroupEvent extends GroupEvent {
  final String inviteCode;
  const JoinGroupEvent(this.inviteCode);
  @override
  List<Object?> get props => [inviteCode];
}

class LeaveGroupEvent extends GroupEvent {
  final String groupId;
  const LeaveGroupEvent(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

class DeleteGroupEvent extends GroupEvent {
  final String groupId;
  const DeleteGroupEvent(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

// ── States ─────────────────────────────────────────────────────
// All states expose a `groups` getter so the UI doesn't need type-switches
// just to read the current list.
abstract class GroupState extends Equatable {
  const GroupState();
  List<Group> get groups => const [];
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
  final List<Group> _groups;
  const GroupLoaded(this._groups);
  @override
  List<Group> get groups => _groups;
  @override
  List<Object?> get props => [_groups];
}

/// Emitted after a group is successfully created.
/// UI can listen for this to show a confirmation snackbar.
class GroupCreated extends GroupState {
  final List<Group> _groups;
  final Group created;
  const GroupCreated({required List<Group> groups, required this.created})
      : _groups = groups;
  @override
  List<Group> get groups => _groups;
  @override
  List<Object?> get props => [_groups, created];
}

/// Emitted after the user successfully joins a group.
class GroupJoined extends GroupState {
  final List<Group> _groups;
  final Group joined;
  const GroupJoined({required List<Group> groups, required this.joined})
      : _groups = groups;
  @override
  List<Group> get groups => _groups;
  @override
  List<Object?> get props => [_groups, joined];
}

class GroupError extends GroupState {
  final String message;
  final List<Group> _previousGroups;
  const GroupError(this.message, {List<Group> previousGroups = const []})
      : _previousGroups = previousGroups;
  @override
  List<Group> get groups => _previousGroups;
  @override
  List<Object?> get props => [message, _previousGroups];
}

// ── Bloc ───────────────────────────────────────────────────────
class GroupBloc extends Bloc<GroupEvent, GroupState> {
  final GroupRepository _repo;

  GroupBloc(this._repo) : super(const GroupInitial()) {
    on<LoadGroups>((event, emit) async {
      emit(const GroupLoading());
      try {
        final list = await _repo.getMyGroups();
        emit(GroupLoaded(list));
      } catch (e) {
        emit(GroupError(e.toString()));
      }
    });

    on<CreateGroupEvent>((event, emit) async {
      final prev = state.groups;
      try {
        final group = await _repo.createGroup(event.name);
        emit(GroupCreated(groups: [group, ...prev], created: group));
      } catch (e) {
        emit(GroupError(e.toString(), previousGroups: prev));
        // Restore list so the main screen stays consistent.
        emit(GroupLoaded(prev));
      }
    });

    on<JoinGroupEvent>((event, emit) async {
      final prev = state.groups;
      try {
        final group = await _repo.joinGroup(event.inviteCode);
        final updated = prev.any((g) => g.id == group.id) ? prev : [group, ...prev];
        emit(GroupJoined(groups: updated, joined: group));
      } catch (e) {
        emit(GroupError(e.toString(), previousGroups: prev));
        emit(GroupLoaded(prev));
      }
    });

    on<LeaveGroupEvent>((event, emit) async {
      await _repo.leaveGroup(event.groupId);
      final updated = state.groups.where((g) => g.id != event.groupId).toList();
      emit(GroupLoaded(updated));
    });

    on<DeleteGroupEvent>((event, emit) async {
      final prev = state.groups;
      try {
        await _repo.deleteGroup(event.groupId);
        final updated = prev.where((g) => g.id != event.groupId).toList();
        emit(GroupLoaded(updated));
      } catch (e) {
        emit(GroupError(e.toString(), previousGroups: prev));
        emit(GroupLoaded(prev));
      }
    });
  }
}
