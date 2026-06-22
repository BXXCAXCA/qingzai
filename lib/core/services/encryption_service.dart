import 'dart:typed_data';

abstract interface class EncryptionService {
  Future<void> initialize(String secret);

  Future<EncryptedData> encryptBytes(List<int> plainData);

  Future<List<int>> decryptBytes(EncryptedData encryptedData);

  Future<String> encryptText(String plainText);

  Future<String> decryptText(String encryptedText);

  List<int> generateRandomBytes(int length);

  String calculateSha256(List<int> data);
}

class EncryptedData {
  const EncryptedData({
    required this.ciphertext,
    required this.iv,
    required this.authTag,
  });

  factory EncryptedData.fromBytes(List<int> bytes) {
    if (bytes.length < 4) {
      throw const FormatException('Encrypted payload is too short.');
    }

    var offset = 0;
    final ivLength = _bytesToInt16(bytes.sublist(offset, offset + 2));
    offset += 2;

    if (ivLength <= 0 || bytes.length < offset + ivLength + 2) {
      throw const FormatException('Encrypted payload has an invalid IV length.');
    }

    final iv = bytes.sublist(offset, offset + ivLength);
    offset += ivLength;

    final tagLength = _bytesToInt16(bytes.sublist(offset, offset + 2));
    offset += 2;

    if (tagLength <= 0 || bytes.length < offset + tagLength) {
      throw const FormatException('Encrypted payload has an invalid auth tag length.');
    }

    final authTag = bytes.sublist(offset, offset + tagLength);
    offset += tagLength;

    return EncryptedData(
      ciphertext: bytes.sublist(offset),
      iv: iv,
      authTag: authTag,
    );
  }

  final List<int> ciphertext;
  final List<int> iv;
  final List<int> authTag;

  List<int> toBytes() {
    if (iv.length > 0xFFFF || authTag.length > 0xFFFF) {
      throw const FormatException('Encrypted payload headers are too large.');
    }

    final buffer = BytesBuilder();
    buffer.add(_int16ToBytes(iv.length));
    buffer.add(iv);
    buffer.add(_int16ToBytes(authTag.length));
    buffer.add(authTag);
    buffer.add(ciphertext);
    return buffer.toBytes();
  }

  static List<int> _int16ToBytes(int value) => [value >> 8, value & 0xFF];

  static int _bytesToInt16(List<int> bytes) => (bytes[0] << 8) | bytes[1];
}
