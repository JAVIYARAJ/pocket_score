import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_score/bloc/connectivity_cubit.dart';

void main() {
  late StreamController<List<ConnectivityResult>> changes;
  late List<bool> probeResults; // consumed in order; last one repeats

  ConnectivityCubit build() => ConnectivityCubit(
        probeHost: 'unused',
        changes: changes.stream,
        probe: () async =>
            probeResults.length > 1 ? probeResults.removeAt(0) : probeResults.first,
      );

  setUp(() => changes = StreamController.broadcast());
  tearDown(() => changes.close());

  testWidgets('radios off goes offline at once and blocks back', (tester) async {
    probeResults = [true];
    final cubit = build();
    await tester.pump();
    expect(cubit.state, isTrue);
    expect(await cubit.didPopRoute(), isFalse);

    changes.add([ConnectivityResult.none]);
    await tester.pump();
    expect(cubit.state, isFalse);
    expect(await cubit.didPopRoute(), isTrue);
    await cubit.close();
  });

  testWidgets('a single failed probe does not block the app', (tester) async {
    probeResults = [false, true];
    final cubit = build();
    await tester.pump(const Duration(seconds: 3));
    expect(cubit.state, isTrue);
    await cubit.close();
  });

  testWidgets('no internet on Wi-Fi goes offline, then recovers by itself',
      (tester) async {
    probeResults = [false, false, false, true];
    final cubit = build();
    await tester.pump(const Duration(seconds: 3)); // probe + confirm
    expect(cubit.state, isFalse);

    await tester.pump(const Duration(seconds: 5)); // offline poll, still down
    expect(cubit.state, isFalse);

    await tester.pump(const Duration(seconds: 5)); // next poll succeeds
    expect(cubit.state, isTrue);
    await cubit.close();
  });

  testWidgets('"Try again" check comes back online immediately', (tester) async {
    probeResults = [false, false, true];
    final cubit = build();
    await tester.pump(const Duration(seconds: 3));
    expect(cubit.state, isFalse);

    await cubit.check();
    expect(cubit.state, isTrue);
    await cubit.close();
  });
}
