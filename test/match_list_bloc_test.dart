import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_score/bloc/match_list_bloc.dart';
import 'package:pocket_score/models/match_models.dart';
import 'package:pocket_score/services/match_repository.dart';

/// Records saved match statuses in the order they *complete*; the first save
/// is slow, so unordered writes would finish out of order.
class _RecordingRepo implements MatchRepository {
  final saved = <String>[];
  var _calls = 0;

  @override
  Future<void> upsert(MatchSummary match) async {
    final n = ++_calls;
    await Future<void>.delayed(Duration(milliseconds: n == 1 ? 40 : 0));
    saved.add(match.status);
  }

  @override
  Future<void> upsertPlayerMatchStats(MatchSummary match) async =>
      saved.add('stats');

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

MatchSummary _match(String status) => MatchSummary(
      id: 'm1',
      teamAName: 'A',
      teamBName: 'B',
      totalOvers: 5,
      status: status,
      createdAt: DateTime(2026),
      scoreData: const {},
    );

void main() {
  test('final "completed" save is never overtaken by an older one', () async {
    final repo = _RecordingRepo();
    final bloc = MatchListBloc(repo);

    bloc.add(AddMatchToList(_match('in_progress')));
    bloc.add(UpdateMatchInList(_match('completed')));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(repo.saved, ['in_progress', 'completed', 'stats']);
    expect(bloc.state.matches.single.status, 'completed');
    await bloc.close();
  });
}
