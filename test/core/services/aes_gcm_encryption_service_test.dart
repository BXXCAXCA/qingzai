import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingzai/core/errors/app_exception.dart';
import 'package:qingzai/core/services/services.dart';

void main() {
  group('EncryptedData', () {
    test('serializes and deserializes bytes without losing fields', () {
      const encrypted = EncryptedData(
        ciphertext: [1, 2, 3, 4],
        iv: [5, 6, 7],
        authTag: [8, 9],
      );

      final decoded = EncryptedData.fromBytes(encrypted.toBytes());

      expect(decoded.ciphertext, encrypted.ciphertext);
      expect(decoded.iv, encrypted.iv);
      expect(decoded.authTag, encrypted.authTag);
    });

    test('rejects malformed byte payloads', () {
      expect(
        () => EncryptedData.fromBytes([0, 12]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AesGcmEncryptionService', () {
    test('rejects empty master secret', () async {
      final service = AesGcmEncryptionService();

      expect(
        () => service.initialize('   '),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('encrypts and decrypts binary data', () async {
      final service = AesGcmEncryptionService();
      await service.initialize('correct horse battery staple');
      final plainData = List<int>.generate(256, (index) => index % 251);

      final encrypted = await service.encryptBytes(plainData);
      final decrypted = await service.decryptBytes(encrypted);

      expect(encrypted.iv, hasLength(AesGcmEncryptionService.ivLengthBytes));
      expect(encrypted.authTag, hasLength(AesGcmEncryptionService.authTagLengthBytes));
      expect(encrypted.ciphertext, isNot(plainData));
      expect(decrypted, plainData);
    });

    test('encrypts and decrypts unicode text', () async {
      final service = AesGcmEncryptionService();
      await service.initialize('qingzai-secret');
      const plainText = '轻载 Qing Zai 🔐';

      final encryptedText = await service.encryptText(plainText);
      final decryptedText = await service.decryptText(encryptedText);

      expect(encryptedText, isNot(plainText));
      expect(decryptedText, plainText);
    });

    test('generates a unique IV for each encryption', () async {
      final service = AesGcmEncryptionService();
      await service.initialize('qingzai-secret');
      final plainData = utf8.encode('same data');

      final first = await service.encryptBytes(plainData);
      final second = await service.encryptBytes(plainData);

      expect(first.iv, isNot(second.iv));
      expect(first.toBytes(), isNot(second.toBytes()));
    });

    test('detects tampered ciphertext or auth tag', () async {
      final service = AesGcmEncryptionService();
      await service.initialize('qingzai-secret');
      final encrypted = await service.encryptBytes(utf8.encode('do not tamper'));
      final tampered = EncryptedData(
        ciphertext: encrypted.ciphertext,
        iv: encrypted.iv,
        authTag: [
          encrypted.authTag.first ^ 0x01,
          ...encrypted.authTag.skip(1),
        ],
      );

      expect(
        () => service.decryptBytes(tampered),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('requires initialization before use', () async {
      final service = AesGcmEncryptionService();

      expect(
        () => service.encryptBytes([1, 2, 3]),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('calculates sha256 hashes', () {
      final service = AesGcmEncryptionService();

      expect(
        service.calculateSha256(utf8.encode('hello')),
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });
  });
}
