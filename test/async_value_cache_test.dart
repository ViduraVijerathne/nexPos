import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nex_pos_desktop/core/services/async_value_cache.dart';

void main() {
  test('coalesces requests, reuses values and reloads after expiry', () async {
    var now = DateTime(2026);
    final cache = AsyncValueCache<int>(
      maxAge: const Duration(seconds: 30),
      now: () => now,
    );
    var reads = 0;
    final pending = Completer<int>();
    final first = cache.get(() {
      reads++;
      return pending.future;
    });
    final second = cache.get(() async {
      reads++;
      return 2;
    });
    pending.complete(1);
    expect(await first, 1);
    expect(await second, 1);
    expect(
      await cache.get(() async {
        reads++;
        return 2;
      }),
      1,
    );
    expect(reads, 1);
    now = now.add(const Duration(seconds: 30));
    expect(
      await cache.get(() async {
        reads++;
        return 2;
      }),
      2,
    );
    expect(reads, 2);
  });
  test('failed and invalidated reads do not poison future loads', () async {
    final cache = AsyncValueCache<int>(maxAge: const Duration(minutes: 1));
    await expectLater(
      cache.get(() async => throw StateError('read failed')),
      throwsStateError,
    );
    final pending = Completer<int>();
    final old = cache.get(() => pending.future);
    cache.invalidate();
    expect(await cache.get(() async => 2), 2);
    pending.complete(1);
    expect(await old, 1);
    expect(await cache.get(() async => 3), 2);
    cache.update((value) => value - 1);
    expect(await cache.get(() async => 3), 1);
  });
}
