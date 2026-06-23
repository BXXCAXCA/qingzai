class RetryPolicy {
  const RetryPolicy({
    this.initialDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 5),
    this.multiplier = 2,
  }) : assert(multiplier >= 1, 'multiplier must be at least 1');

  final Duration initialDelay;
  final Duration maxDelay;
  final int multiplier;

  Duration delayForAttempt(int attemptCount) {
    if (attemptCount <= 0) {
      return Duration.zero;
    }

    var delay = initialDelay;
    for (var index = 1; index < attemptCount; index++) {
      delay *= multiplier;
      if (delay >= maxDelay) {
        return maxDelay;
      }
    }

    return delay > maxDelay ? maxDelay : delay;
  }

  DateTime nextRetryAt({
    required int attemptCount,
    DateTime? now,
  }) {
    final base = now ?? DateTime.now();
    return base.add(delayForAttempt(attemptCount));
  }
}
