final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

void validateUuid(String id, {String fieldName = 'id'}) {
  if (!_uuidPattern.hasMatch(id)) {
    throw ArgumentError.value(id, fieldName, 'Value must be a valid UUID.');
  }
}

void validateNonEmptyString(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, fieldName, 'Value must not be empty.');
  }
}

void validateDeviceId(String deviceId) {
  validateNonEmptyString(deviceId, 'deviceId');
}

void validatePriority(int priority) {
  if (priority < 0 || priority > 2) {
    throw ArgumentError.value(
      priority,
      'priority',
      'Priority must be between 0 and 2.',
    );
  }
}

void validateNonNegativeClock(int lamportClock) {
  if (lamportClock < 0) {
    throw ArgumentError.value(
      lamportClock,
      'lamportClock',
      'Lamport clock must be non-negative.',
    );
  }
}

DateTime parseRequiredDateTime(Object? value, String fieldName) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$fieldName must be a non-empty ISO 8601 string.');
  }

  return DateTime.parse(value);
}

DateTime? parseOptionalDateTime(Object? value, String fieldName) {
  if (value == null) {
    return null;
  }

  return parseRequiredDateTime(value, fieldName);
}

List<String> parseStringList(Object? value, {String fieldName = 'items'}) {
  if (value == null) {
    return const <String>[];
  }

  if (value is! List) {
    throw FormatException('$fieldName must be a JSON array.');
  }

  return List<String>.from(value);
}

int parseInt(Object? value, String fieldName, {int defaultValue = 0}) {
  if (value == null) {
    return defaultValue;
  }

  if (value is! int) {
    throw FormatException('$fieldName must be an integer.');
  }

  return value;
}

bool parseBool(Object? value, String fieldName, {bool defaultValue = false}) {
  if (value == null) {
    return defaultValue;
  }

  if (value is! bool) {
    throw FormatException('$fieldName must be a boolean.');
  }

  return value;
}

String parseRequiredString(Object? value, String fieldName) {
  if (value is! String || value.isEmpty) {
    throw FormatException('$fieldName must be a non-empty string.');
  }

  return value;
}

String? parseOptionalString(Object? value, String fieldName) {
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw FormatException('$fieldName must be a string.');
  }

  return value;
}
