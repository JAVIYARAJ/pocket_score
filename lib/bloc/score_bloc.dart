import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/ball_model.dart';
import '../models/innings_model.dart';
import '../models/player_model.dart';
import '../services/match_repository.dart';

// Events
abstract class ScoreEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartInnings extends ScoreEvent {
  final String battingTeamName;
  final List<Player> battingLineup;
  final List<Player> bowlingLineup;
  final int target;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;

  StartInnings({
    required this.battingTeamName,
    required this.battingLineup,
    required this.bowlingLineup,
    this.target = 0,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
  });
}

class RecordBall extends ScoreEvent {
  final int runs;
  final BallType type;
  final int extraRuns;
  final bool isWicket;
  final String? wicketType;
  final String? nextBatsmanId;
  final String? outPlayerId;
  final String? fielderId;

  RecordBall({
    required this.runs,
    required this.type,
    this.extraRuns = 0,
    this.isWicket = false,
    this.wicketType,
    this.nextBatsmanId,
    this.outPlayerId,
    this.fielderId,
  });

  @override
  List<Object?> get props => [runs, type, extraRuns, isWicket, wicketType, nextBatsmanId, outPlayerId, fielderId];
}

class ChangeBowler extends ScoreEvent {
  final String newBowlerId;
  ChangeBowler(this.newBowlerId);
  @override
  List<Object?> get props => [newBowlerId];
}

class UndoBall extends ScoreEvent {}

class ResetScoreboard extends ScoreEvent {}

class SwapStriker extends ScoreEvent {}

class RetirePlayer extends ScoreEvent {
  final String playerId;
  final String? nextBatsmanId;
  RetirePlayer({required this.playerId, this.nextBatsmanId});
  @override
  List<Object?> get props => [playerId, nextBatsmanId];
}

class SelectNextBatsman extends ScoreEvent {
  final String playerId;
  final bool isStriker;
  SelectNextBatsman({required this.playerId, required this.isStriker});
  @override
  List<Object?> get props => [playerId, isStriker];
}

// State
class ScoreState extends Equatable {
  final Innings? firstInnings;
  final Innings? secondInnings;
  final bool isFirstInnings;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
  final List<Player> battingLineup;
  final List<Player> bowlingLineup;
  final List<String> outPlayerIds;
  final bool pendingBowlerChange;
  final bool isFreeHit;
  final bool isLastManStanding;
  final List<String> retiredHurtIds;
  final List<ScoreState> history;

  const ScoreState({
    this.firstInnings,
    this.secondInnings,
    this.isFirstInnings = true,
    this.strikerId = '',
    this.nonStrikerId = '',
    this.bowlerId = '',
    this.battingLineup = const [],
    this.bowlingLineup = const [],
    this.outPlayerIds = const [],
    this.retiredHurtIds = const [],
    this.history = const [],
    this.pendingBowlerChange = false,
    this.isFreeHit = false,
    this.isLastManStanding = false,
  });

  Map<String, dynamic> toJson() {
    final List<Map<String, dynamic>> historyJson = history.map((h) {
      return <String, dynamic>{
        'firstInnings': h.firstInnings?.toJson(),
        'secondInnings': h.secondInnings?.toJson(),
        'isFirstInnings': h.isFirstInnings,
        'strikerId': h.strikerId,
        'nonStrikerId': h.nonStrikerId,
        'bowlerId': h.bowlerId,
        'battingLineup': h.battingLineup.map((p) => p.toJson()).toList(),
        'bowlingLineup': h.bowlingLineup.map((p) => p.toJson()).toList(),
        'outPlayerIds': h.outPlayerIds,
        'retiredHurtIds': h.retiredHurtIds,
        'pendingBowlerChange': h.pendingBowlerChange,
        'isFreeHit': h.isFreeHit,
        'isLastManStanding': h.isLastManStanding,
        'history': <Map<String, dynamic>>[],
      };
    }).toList();

    return {
      'firstInnings': firstInnings?.toJson(),
      'secondInnings': secondInnings?.toJson(),
      'isFirstInnings': isFirstInnings,
      'strikerId': strikerId,
      'nonStrikerId': nonStrikerId,
      'bowlerId': bowlerId,
      'battingLineup': battingLineup.map((p) => p.toJson()).toList(),
      'bowlingLineup': bowlingLineup.map((p) => p.toJson()).toList(),
      'outPlayerIds': outPlayerIds,
      'retiredHurtIds': retiredHurtIds,
      'pendingBowlerChange': pendingBowlerChange,
      'isFreeHit': isFreeHit,
      'isLastManStanding': isLastManStanding,
      'history': historyJson,
    };
  }
  factory ScoreState.fromJson(Map<String, dynamic> json) => ScoreState(
    firstInnings: json['firstInnings'] != null ? Innings.fromJson(json['firstInnings']) : null,
    secondInnings: json['secondInnings'] != null ? Innings.fromJson(json['secondInnings']) : null,
    isFirstInnings: json['isFirstInnings'] ?? true,
    strikerId: json['strikerId'] ?? '',
    nonStrikerId: json['nonStrikerId'] ?? '',
    bowlerId: json['bowlerId'] ?? '',
    battingLineup: (json['battingLineup'] as List?)?.map((p) => Player.fromJson(p)).toList() ?? const [],
    bowlingLineup: (json['bowlingLineup'] as List?)?.map((p) => Player.fromJson(p)).toList() ?? const [],
    outPlayerIds: List<String>.from(json['outPlayerIds'] ?? []),
    retiredHurtIds: List<String>.from(json['retiredHurtIds'] ?? []),
    pendingBowlerChange: json['pendingBowlerChange'] ?? false,
    isFreeHit: json['isFreeHit'] ?? false,
    isLastManStanding: json['isLastManStanding'] ?? false,
    history: (json['history'] as List?)?.map((h) => ScoreState.fromJson(h)).toList() ?? const [],
  );

  Innings? get currentInnings => isFirstInnings ? firstInnings : secondInnings;

  @override
  List<Object?> get props => [
    firstInnings, secondInnings, isFirstInnings,
    strikerId, nonStrikerId, bowlerId,
    battingLineup, bowlingLineup, outPlayerIds, retiredHurtIds, 
    pendingBowlerChange, isFreeHit, isLastManStanding, history,
  ];

  ScoreState copyWith({
    Innings? firstInnings,
    Innings? secondInnings,
    bool? isFirstInnings,
    String? strikerId,
    String? nonStrikerId,
    String? bowlerId,
    List<Player>? battingLineup,
    List<Player>? bowlingLineup,
    List<String>? outPlayerIds,
    bool? pendingBowlerChange,
    bool? isFreeHit,
    bool? isLastManStanding,
    List<String>? retiredHurtIds,
    List<ScoreState>? history,
  }) {
    return ScoreState(
      firstInnings: firstInnings ?? this.firstInnings,
      secondInnings: secondInnings ?? this.secondInnings,
      isFirstInnings: isFirstInnings ?? this.isFirstInnings,
      strikerId: strikerId ?? this.strikerId,
      nonStrikerId: nonStrikerId ?? this.nonStrikerId,
      bowlerId: bowlerId ?? this.bowlerId,
      battingLineup: battingLineup ?? this.battingLineup,
      bowlingLineup: bowlingLineup ?? this.bowlingLineup,
      outPlayerIds: outPlayerIds ?? this.outPlayerIds,
      retiredHurtIds: retiredHurtIds ?? this.retiredHurtIds,
      pendingBowlerChange: pendingBowlerChange ?? this.pendingBowlerChange,
      isFreeHit: isFreeHit ?? this.isFreeHit,
      isLastManStanding: isLastManStanding ?? this.isLastManStanding,
      history: history ?? this.history,
    );
  }
}

// Bloc
class ScoreBloc extends HydratedBloc<ScoreEvent, ScoreState> {
  final MatchRepository _repo;

  /// The current match ID is provided externally so the BLoC can
  /// push live-score updates to Supabase.
  String? activeMatchId;

  ScoreBloc(this._repo) : super(const ScoreState()) {
    on<ResetScoreboard>((event, emit) {
      if (activeMatchId != null) {
        _repo.deleteLiveScore(activeMatchId!).ignore();
        activeMatchId = null;
      }
      emit(const ScoreState());
    });

    on<StartInnings>((event, emit) {
      final newInnings = Innings(
        battingTeamName: event.battingTeamName,
        target: event.target,
        battingPlayers: event.battingLineup,
        bowlingPlayers: event.bowlingLineup,
      );
      if (event.target == 0) {
        emit(ScoreState(
          firstInnings: newInnings,
          isFirstInnings: true,
          strikerId: event.strikerId,
          nonStrikerId: event.nonStrikerId,
          bowlerId: event.bowlerId,
          battingLineup: event.battingLineup,
          bowlingLineup: event.bowlingLineup,
          isLastManStanding: event.nonStrikerId.isEmpty,
        ));
      } else {
        emit(state.copyWith(
          secondInnings: newInnings,
          isFirstInnings: false,
          strikerId: event.strikerId,
          nonStrikerId: event.nonStrikerId,
          bowlerId: event.bowlerId,
          battingLineup: event.battingLineup,
          bowlingLineup: event.bowlingLineup,
          outPlayerIds: [],
          retiredHurtIds: [],
          isLastManStanding: event.nonStrikerId.isEmpty,
          pendingBowlerChange: false,
        ));
      }
    });

    on<RecordBall>((event, emit) {
      final currentInnings = state.currentInnings;
      if (currentInnings == null) return;

      final newHistory = List<ScoreState>.from(state.history);
      newHistory.add(state.copyWith(history: const []));
      if (newHistory.length > 20) {
        newHistory.removeRange(0, newHistory.length - 20);
      }

      final ball = Ball(
        runs: event.runs,
        type: event.type,
        extraRuns: event.extraRuns,
        strikerId: state.strikerId,
        bowlerId: state.bowlerId,
        isWicket: event.isWicket,
        wicketType: event.wicketType,
        fielderId: event.fielderId,
      );

      final updatedBalls = List<Ball>.from(currentInnings.balls)..add(ball);
      final updatedInnings = currentInnings.copyWith(balls: updatedBalls);

      String newStrikerId = state.strikerId;
      String newNonStrikerId = state.nonStrikerId;
      List<String> newOutPlayerIds = List<String>.from(state.outPlayerIds);
      List<String> newRetiredIds = List<String>.from(state.retiredHurtIds);
      bool newLastMan = state.isLastManStanding;

      if (event.isWicket) {
        final actualOutId = event.outPlayerId ?? state.strikerId;
        newOutPlayerIds.add(actualOutId);
        
        if (event.nextBatsmanId != null) {
          if (newRetiredIds.contains(event.nextBatsmanId)) {
            newRetiredIds.remove(event.nextBatsmanId);
          }
          if (actualOutId == state.strikerId) {
            newStrikerId = event.nextBatsmanId!;
          } else {
            newNonStrikerId = event.nextBatsmanId!;
          }
        } else if (!state.isLastManStanding) {
          final remaining = state.battingLineup.where((p) => 
            !newOutPlayerIds.contains(p.id) && 
            p.id != state.strikerId && 
            p.id != state.nonStrikerId
          ).toList();

          if (remaining.isEmpty) {
            newLastMan = true;
            if (actualOutId == state.strikerId) {
              newStrikerId = state.nonStrikerId;
              newNonStrikerId = '';
            } else {
              newNonStrikerId = '';
            }
          } else {
            if (actualOutId == state.strikerId) {
              newStrikerId = '';
            } else {
              newNonStrikerId = '';
            }
          }
        }
      }

      // Strike Rotation
      if (!newLastMan && newStrikerId.isNotEmpty && newNonStrikerId.isNotEmpty) {
        if (event.runs % 2 != 0) {
          final temp = newStrikerId;
          newStrikerId = newNonStrikerId;
          newNonStrikerId = temp;
        }
      }

      // Over Completion
      bool overJustEnded = false;
      if (ball.isLegalBall) {
        int ballsThisOver = updatedInnings.legalBallsCount % 6;
        if (ballsThisOver == 0 && updatedInnings.legalBallsCount > 0) {
          overJustEnded = true;
          if (!newLastMan && newStrikerId.isNotEmpty && newNonStrikerId.isNotEmpty) {
            final temp = newStrikerId;
            newStrikerId = newNonStrikerId;
            newNonStrikerId = temp;
          }
        }
      }

      bool nextBallIsFreeHit = (ball.type == BallType.noBall) || (state.isFreeHit && ball.type == BallType.wide);

      final nextState = state.copyWith(
        firstInnings: state.isFirstInnings ? updatedInnings : null,
        secondInnings: !state.isFirstInnings ? updatedInnings : null,
        strikerId: newStrikerId,
        nonStrikerId: newNonStrikerId,
        outPlayerIds: newOutPlayerIds,
        retiredHurtIds: newRetiredIds,
        isLastManStanding: newLastMan,
        pendingBowlerChange: overJustEnded,
        isFreeHit: nextBallIsFreeHit,
        history: newHistory,
      );
      emit(nextState);

      // ── Publish live score to Supabase (fire-and-forget) ──
      if (activeMatchId != null) {
        _repo.upsertLiveScore(
          activeMatchId!,
          nextState.toJson(),
        ).ignore();
      }
    });

    on<SelectNextBatsman>((event, emit) {
      List<String> newRetiredIds = List<String>.from(state.retiredHurtIds);
      if (newRetiredIds.contains(event.playerId)) {
        newRetiredIds.remove(event.playerId);
      }

      if (event.isStriker) {
        emit(state.copyWith(
          strikerId: event.playerId, 
          retiredHurtIds: newRetiredIds,
          isLastManStanding: state.nonStrikerId.isEmpty,
        ));
      } else {
        emit(state.copyWith(
          nonStrikerId: event.playerId, 
          retiredHurtIds: newRetiredIds,
          isLastManStanding: false,
        ));
      }
    });

    on<ChangeBowler>((event, emit) {
      emit(state.copyWith(bowlerId: event.newBowlerId, pendingBowlerChange: false));
    });

    on<UndoBall>((event, emit) {
      if (state.history.isNotEmpty) {
        final previous = state.history.last;
        final updatedHistory = List<ScoreState>.from(state.history)..removeLast();
        emit(previous.copyWith(history: updatedHistory));
      }
    });

    on<SwapStriker>((event, emit) {
      if (state.isLastManStanding || state.strikerId.isEmpty || state.nonStrikerId.isEmpty) return;
      emit(state.copyWith(strikerId: state.nonStrikerId, nonStrikerId: state.strikerId));
    });

    on<RetirePlayer>((event, emit) {
      final newHistory = List<ScoreState>.from(state.history);
      newHistory.add(state.copyWith(history: const []));
      
      List<String> newRetiredIds = List<String>.from(state.retiredHurtIds);
      if (!newRetiredIds.contains(event.playerId)) newRetiredIds.add(event.playerId);

      String newStrikerId = state.strikerId;
      String newNonStrikerId = state.nonStrikerId;
      bool newLastMan = state.isLastManStanding;

      if (event.playerId == state.strikerId) {
        if (event.nextBatsmanId != null) {
          if (newRetiredIds.contains(event.nextBatsmanId)) newRetiredIds.remove(event.nextBatsmanId);
          newStrikerId = event.nextBatsmanId!;
        } else {
          newStrikerId = '';
          if (state.nonStrikerId.isNotEmpty) {
             final remaining = state.battingLineup.where((p) => !state.outPlayerIds.contains(p.id) && !newRetiredIds.contains(p.id) && p.id != state.nonStrikerId).toList();
             if (remaining.isEmpty) {
               newStrikerId = state.nonStrikerId;
               newNonStrikerId = '';
               newLastMan = true;
             }
          }
        }
      } else {
        if (event.nextBatsmanId != null) {
          if (newRetiredIds.contains(event.nextBatsmanId)) newRetiredIds.remove(event.nextBatsmanId);
          newNonStrikerId = event.nextBatsmanId!;
        } else {
          newNonStrikerId = '';
          final remaining = state.battingLineup.where((p) => !state.outPlayerIds.contains(p.id) && !newRetiredIds.contains(p.id) && p.id != state.strikerId).toList();
          if (remaining.isEmpty) newLastMan = true;
        }
      }

      emit(state.copyWith(
        strikerId: newStrikerId,
        nonStrikerId: newNonStrikerId,
        retiredHurtIds: newRetiredIds,
        isLastManStanding: newLastMan,
        history: newHistory,
      ));
    });
  }

  @override
  ScoreState? fromJson(Map<String, dynamic> json) {
    try { return ScoreState.fromJson(json); } catch (_) { return null; }
  }

  @override
  Map<String, dynamic>? toJson(ScoreState state) => state.toJson();
}
