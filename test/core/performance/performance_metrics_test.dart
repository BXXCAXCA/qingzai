import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/performance/performance.dart';

void main() {
  group('PerformanceBenchmark', () {
    test('calculates P95 using nearest-rank semantics', () {
      final p95 = PerformanceBenchmark.calculateP95([
        const Duration(milliseconds: 1),
        const Duration(milliseconds: 2),
        const Duration(milliseconds: 3),
        const Duration(milliseconds: 4),
        const Duration(milliseconds: 5),
        const Duration(milliseconds: 6),
        const Duration(milliseconds: 7),
        const Duration(milliseconds: 8),
        const Duration(milliseconds: 9),
        const Duration(milliseconds: 10),
      ]);

      expect(p95, const Duration(milliseconds: 10));
    });

    test('records benchmark metadata and threshold status', () {
      final benchmark = PerformanceBenchmark(
        name: 'local-read',
        threshold: const Duration(milliseconds: 10),
        device: 'test-device',
        systemVersion: 'test-os',
      )
        ..addSample(const Duration(milliseconds: 3))
        ..addSample(const Duration(milliseconds: 5))
        ..addSample(const Duration(milliseconds: 8));

      final result = benchmark.result();

      expect(result.sampleCount, 3);
      expect(result.p95, const Duration(milliseconds: 8));
      expect(result.passed, isTrue);
      expect(result.toJson()['device'], 'test-device');
    });

    test('fails threshold when P95 is above the limit', () {
      final benchmark = PerformanceBenchmark(
        name: 'slow-sync',
        threshold: const Duration(milliseconds: 10),
        device: 'test-device',
        systemVersion: 'test-os',
      )..addSample(const Duration(milliseconds: 20));

      expect(benchmark.result().passed, isFalse);
    });
  });
}
