import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

import '../errors/app_exception.dart';
import 'encryption_service.dart';

/// AES-256-GCM based encryption service.
///
/// The master secret is converted to a 256-bit key with PBKDF2-HMAC-SHA256.
/// A fresh 12-byte IV is generated for each encryption operation.
final class AesGcmEncryptionService implements EncryptionService {
  AesGcmEncryptionService({
    this.pbkdf2Iterations = 100000,
    List<int>? salt,
  }) : _salt = Uint8List.fromList(
          salt ?? utf8.encode('qingzai.encryption.v1'),
        );

  static const int keyLengthBytes = 32;
  static const int ivLengthBytes = 12;
  static const int authTagLengthBits = 128;
  static const int authTagLengthBytes = authTagLengthBits ~/ 8;

  final int pbkdf2Iterations;
  final Uint8List _salt;
  Uint8List? _key;

  @override
  Future<void> initialize(String secret) async {
    if (secret.trim().isEmpty) {
      throw const AuthenticationException('Encryption secret cannot be empty.');
    }

    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(
        Pbkdf2Parameters(
          _salt,
          pbkdf2Iterations,
          keyLengthBytes,
        ),
      );

    _key = derivator.process(Uint8List.fromList(utf8.encode(secret)));
  }

  @override
  Future<EncryptedData> encryptBytes(List<int> plainData) async {
    final key = _requireKey();
    final iv = Uint8List.fromList(generateRandomBytes(ivLengthBytes));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          authTagLengthBits,
          iv,
          Uint8List(0),
        ),
      );

    final input = Uint8List.fromList(plainData);
    final output = Uint8List(cipher.getOutputSize(input.length));
    var outputLength = cipher.processBytes(input, 0, input.length, output, 0);
    outputLength += cipher.doFinal(output, outputLength);

    final sealed = output.sublist(0, outputLength);
    if (sealed.length < authTagLengthBytes) {
      throw const AuthenticationException('Encrypted output is unexpectedly short.');
    }

    return EncryptedData(
      ciphertext: sealed.sublist(0, sealed.length - authTagLengthBytes),
      iv: iv,
      authTag: sealed.sublist(sealed.length - authTagLengthBytes),
    );
  }

  @override
  Future<List<int>> decryptBytes(EncryptedData encryptedData) async {
    final key = _requireKey();
    if (encryptedData.iv.length != ivLengthBytes) {
      throw const AuthenticationException('Encrypted data has an invalid IV length.');
    }
    if (encryptedData.authTag.length != authTagLengthBytes) {
      throw const AuthenticationException('Encrypted data has an invalid auth tag length.');
    }

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          authTagLengthBits,
          Uint8List.fromList(encryptedData.iv),
          Uint8List(0),
        ),
      );

    final input = Uint8List.fromList([
      ...encryptedData.ciphertext,
      ...encryptedData.authTag,
    ]);
    final output = Uint8List(cipher.getOutputSize(input.length));

    try {
      var outputLength = cipher.processBytes(input, 0, input.length, output, 0);
      outputLength += cipher.doFinal(output, outputLength);
      return output.sublist(0, outputLength);
    } on InvalidCipherTextException catch (error) {
      throw AuthenticationException(
        'Authentication failed: encrypted data may be corrupted or tampered.',
        cause: error,
      );
    } on ArgumentError catch (error) {
      throw AuthenticationException(
        'Authentication failed: encrypted data is malformed.',
        cause: error,
      );
    }
  }

  @override
  Future<String> encryptText(String plainText) async {
    final encrypted = await encryptBytes(utf8.encode(plainText));
    return base64Encode(encrypted.toBytes());
  }

  @override
  Future<String> decryptText(String encryptedText) async {
    try {
      final encrypted = EncryptedData.fromBytes(base64Decode(encryptedText));
      final decrypted = await decryptBytes(encrypted);
      return utf8.decode(decrypted);
    } on FormatException catch (error) {
      throw AuthenticationException(
        'Encrypted text is not valid base64 data.',
        cause: error,
      );
    }
  }

  @override
  List<int> generateRandomBytes(int length) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'Length must be positive.');
    }

    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  @override
  String calculateSha256(List<int> data) {
    return crypto.sha256.convert(data).toString();
  }

  Uint8List _requireKey() {
    final key = _key;
    if (key == null) {
      throw const AuthenticationException('Encryption service has not been initialized.');
    }
    return key;
  }
}
