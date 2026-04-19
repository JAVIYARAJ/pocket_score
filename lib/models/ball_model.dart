import 'package:equatable/equatable.dart';

enum BallType { normal, wide, noBall, wicket }

class Ball extends Equatable {
  final int runs;
  final BallType type;
  final int extraRuns;
  final String strikerId;
  final String bowlerId;
  final bool isWicket;
  final String? wicketType; // e.g., bowled, caught, run out
  final String? fielderId; // Player who took the catch or did the run out

  const Ball({
    required this.runs,
    required this.type,
    this.extraRuns = 0,
    required this.strikerId,
    required this.bowlerId,
    this.isWicket = false,
    this.wicketType,
    this.fielderId,
  });

  int get totalRuns => runs + extraRuns;
  bool get isLegalBall => type == BallType.normal || type == BallType.wicket;

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'type': type.index,
    'extraRuns': extraRuns,
    'strikerId': strikerId,
    'bowlerId': bowlerId,
    'isWicket': isWicket,
    'wicketType': wicketType,
    'fielderId': fielderId,
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
  );

  @override
  List<Object?> get props => [runs, type, extraRuns, strikerId, bowlerId, isWicket, wicketType, fielderId];
}
