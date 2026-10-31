import 'package:flutter_test/flutter_test.dart';
import 'package:pkmon_app/core/request_id.dart';

void main() {
  group('RequestId', () {
    test('生成小写 UUID v4', () {
      final id = RequestId.generate();

      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: id,
      );
      expect(id, id.toLowerCase());
    });

    test('1000 个 id 不重复', () {
      final ids = List<String>.generate(1000, (_) => RequestId.generate());
      expect(ids.toSet().length, 1000);
    });
  });

  group('RequestIdTracker', () {
    test('重试复用同一个 id', () {
      final tracker = RequestIdTracker();
      final first = tracker.value;
      final retry = tracker.value;

      expect(retry, first);
    });

    test('reset 后生成新的 id', () {
      final tracker = RequestIdTracker();
      final first = tracker.value;

      tracker.reset();

      expect(tracker.value, isNot(first));
    });

    test('可以注入固定生成器', () {
      var next = 0;
      final tracker = RequestIdTracker(generate: () => 'id-${next++}');

      expect(tracker.value, 'id-0');
      expect(tracker.value, 'id-0');
      tracker.reset();
      expect(tracker.value, 'id-1');
    });
  });
}
