class SensitiveValueRedactor {
  const SensitiveValueRedactor();

  static const redacted = '***REDACTED***';

  String redact(String input) {
    var output = input;
    output = output.replaceAllMapped(
      RegExp(r'(?i)(authorization\s*[:=]\s*)(basic|bearer)\s+[^\s,;]+'),
      (match) => '${match.group(1)}${match.group(2)} $redacted',
    );
    output = output.replaceAllMapped(
      RegExp(r'(?i)(password|secret|token|api[_-]?key)\s*[:=]\s*([^\s,;]+)'),
      (match) => '${match.group(1)}=$redacted',
    );
    output = output.replaceAllMapped(
      RegExp(r'(https?:\/\/)([^\s/@:]+):([^\s/@]+)@'),
      (match) => '${match.group(1)}$redacted:$redacted@',
    );
    return output;
  }

  Object redactError(Object error) => redact(error.toString());
}
