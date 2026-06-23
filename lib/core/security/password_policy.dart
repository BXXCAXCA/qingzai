import '../errors/app_exception.dart';

class PasswordPolicy {
  const PasswordPolicy({
    this.minLength = 12,
    this.minCharacterClasses = 3,
    this.blockedPasswords = const {
      'password',
      '12345678',
      '123456789',
      'qwerty123',
      'qingzai',
    },
  });

  final int minLength;
  final int minCharacterClasses;
  final Set<String> blockedPasswords;

  PasswordStrength evaluate(String secret) {
    final issues = <String>[];
    final value = secret.trim();

    if (value.length < minLength) {
      issues.add('Master password must be at least $minLength characters long.');
    }
    if (blockedPasswords.contains(value.toLowerCase())) {
      issues.add('Master password is too common.');
    }
    if (RegExp(r'(.)\1{3,}').hasMatch(value)) {
      issues.add('Master password must not contain long repeated character runs.');
    }
    if (_characterClassCount(value) < minCharacterClasses) {
      issues.add(
        'Master password must include at least $minCharacterClasses character types.',
      );
    }

    return PasswordStrength(
      score: _score(value),
      issues: List.unmodifiable(issues),
    );
  }

  void validate(String secret) {
    final strength = evaluate(secret);
    if (!strength.isAcceptable) {
      throw AuthenticationException(
        'Weak master password: ${strength.issues.join(' ')}',
      );
    }
  }

  int _characterClassCount(String value) {
    var count = 0;
    if (RegExp(r'[a-z]').hasMatch(value)) count++;
    if (RegExp(r'[A-Z]').hasMatch(value)) count++;
    if (RegExp(r'\d').hasMatch(value)) count++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) count++;
    return count;
  }

  int _score(String value) {
    var score = 0;
    score += value.length.clamp(0, 24).toInt() * 2;
    score += _characterClassCount(value) * 10;
    if (value.length >= 16) score += 10;
    if (value.length >= 20) score += 10;
    if (RegExp(r'(.)\1{3,}').hasMatch(value)) score -= 20;
    if (blockedPasswords.contains(value.toLowerCase())) score -= 40;
    return score.clamp(0, 100).toInt();
  }
}

class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.issues,
  });

  final int score;
  final List<String> issues;

  bool get isAcceptable => issues.isEmpty;
}
