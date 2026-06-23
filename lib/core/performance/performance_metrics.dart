class PerformanceSample {
  const PerformanceSample({
    required this.name,
    required this.elapsed,
    required this.timestamp,
  });

  final String name;
  final Duration elapsed;
  final DateTime timestamp;
}

class PerformanceBenchmarkResult {
  const PerformanceBenchmarkResult({
    required this.name,
    required this.samples,
    required this.p95,
    required this.threshold,
    required this.device,
    required this.systemVersion,
    required this.networkCondition,
  });

  final String name;
  final List<PerformanceSample> samples;
  final Duration p95;
  final Duration threshold;
  final String device;
  final String systemVersion;
  final String networkCondition;

  bool get passed => p95 <= threshold;

  int get sampleCount => samples.length;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'sampleCount': sampleCount,
      'p95Ms': p95.inMicroseconds / Duration.microsecondsPerMillisecond,
      'thresholdMs': threshold.inMicroseconds / Duration.microsecondsPerMillisecond,
      'passed': passed,
      'device': device,
      'systemVersion': systemVersion,
      'networkCondition': networkCondition,
    };
  }
}

class PerformanceBenchmark {
  PerformanceBenchmark({
    required this.name,
    required this.threshold,
    required this.device,
    required this.systemVersion,
    this.networkCondition = 'local',
  });

  final String name;
  final Duration threshold;
  final String device;
  final String systemVersion;
  final String networkCondition;
  final _samples = <PerformanceSample>[];

  Future<T> measure<T>(Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _samples.add(
        PerformanceSample(
          name: name,
          elapsed: stopwatch.elapsed,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  void addSample(Duration elapsed) {
    _samples.add(
      PerformanceSample(
        name: name,
        elapsed: elapsed,
        timestamp: DateTime.now(),
      ),
    );
  }

  PerformanceBenchmarkResult result() {
    if (_samples.isEmpty) {
      throw StateError('Cannot calculate benchmark result without samples.');
    }

    return PerformanceBenchmarkResult(
      name: name,
      samples: List<PerformanceSample>.unmodifiable(_samples),
      p95: calculateP95(_samples.map((sample) => sample.elapsed)),
      threshold: threshold,
      device: device,
      systemVersion: systemVersion,
      networkCondition: networkCondition,
    );
  }

  static Duration calculateP95(Iterable<Duration> durations) {
    final sorted = durations.toList(growable: false)
      ..sort((left, right) => left.compareTo(right));
    if (sorted.isEmpty) {
      throw StateError('Cannot calculate P95 without samples.');
    }

    final rank = (sorted.length * 0.95).ceil() - 1;
    return sorted[rank.clamp(0, sorted.length - 1)];
  }
}
