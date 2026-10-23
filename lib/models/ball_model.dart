import 'package:equatable/equatable.dart';

enum BallType { normal, wide, noBall, wicket }

/// Dismissal types as recorded by the scoring screen. Older saved matches may
/// use title case ('Run Out'), so always compare via [Ball.dismissal].
class Dismissal {
  static const bowled  = 'BOWLED';
  static const caught  = 'CAUGHT';
  static const lbw     = 'LBW';
  static const stumped = 'STUMPED';
  static const runOut  = 'RUN OUT';
  static const others  = 'OTHERS';

  /// Case-insensitive normalisation of a stored dismissal type.
  static String? normalize(String? type) => type?.trim().toUpperCase();

  /// Run outs (and unspecified "others") are not credited to the bowler.
  static bool creditsBowler(String? type) {
    final t = normalize(type);
    return t != runOut && t != others;
  }
}

class Ball extends Equatable {
  final int runs;
  final BallType type;
  final int extraRuns;
  final String strikerId;
  final String bowlerId;
  final bool isWicket;
  final String? wicketType; // e.g., bowled, caught, run out
  final String? fielderId; // Player who took the catch or did the run out
  /// Batter dismissed on this ball. Null on older data, where the striker was
  /// always assumed out — use [dismissedId] to read it.
  final String? outPlayerId;

  const Ball({
    required this.runs,
    required this.type,
    this.extraRuns = 0,
    required this.strikerId,
    required this.bowlerId,
    this.isWicket = false,
    this.wicketType,
    this.fielderId,
    this.outPlayerId,
  });

  int get totalRuns => runs + extraRuns;
  bool get isLegalBall => type == BallType.normal || type == BallType.wicket;

  /// Who was out on this ball (only meaningful when [isWicket]).
  String get dismissedId => outPlayerId ?? strikerId;

  /// Normalised dismissal type, e.g. 'RUN OUT'.
  String? get dismissal => Dismissal.normalize(wicketType);

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'type': type.index,
    'extraRuns': extraRuns,
    'strikerId': strikerId,
    'bowlerId': bowlerId,
    'isWicket': isWicket,
    'wicketType': wicketType,
    'fielderId': fielderId,
    if (outPlayerId != null) 'outPlayerId': outPlayerId,
  };

  factory Ball.fromJson(Map<String, dynamic> json) => Ball(
    runs: json['runs'],
    type: BallType.values[json['type']],
    extraRuns: json['extraRuns'],
    strikerId: json['strikerId'],
    bowlerId: json['bowlerId'],
    isWicket: json['isWicket'],
    wicketType: json['wicketType'],
    fielderId: json['fielderId'],
    outPlayerId: json['outPlayerId'],
  );

  @override
  List<Object?> get props => [runs, type, extraRuns, strikerId, bowlerId, isWicket, wicketType, fielderId, outPlayerId];
}
