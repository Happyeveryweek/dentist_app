import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// 用户密码的生成与兼容验证入口。
class PasswordService {
  static const _algorithm = 'pbkdf2_sha256';
  static const _iterations = 100000;
  static const _saltLength = 16;
  static const _derivedKeyLength = 32;
  static const _maxSupportedIterations = 1000000;

  String hashPassword(String password) {
    final salt = List<int>.generate(
      _saltLength,
      (_) => Random.secure().nextInt(256),
    );
    final derivedKey = _deriveKey(password, salt, _iterations);
    return [
      _algorithm,
      _iterations.toString(),
      base64Encode(salt),
      base64Encode(derivedKey),
    ].join(r'$');
  }

  PasswordVerificationResult verifyPassword(
    String password,
    String storedPassword,
  ) {
    if (storedPassword.startsWith('$_algorithm\$')) {
      return _verifyPbkdf2Password(password, storedPassword);
    }

    if (_isHexDigest(storedPassword, 64)) {
      return PasswordVerificationResult(
        isValid: _constantTimeEquals(
          sha256.convert(utf8.encode(password)).toString(),
          storedPassword,
        ),
        needsUpgrade: true,
      );
    }

    if (_isHexDigest(storedPassword, 32)) {
      return PasswordVerificationResult(
        isValid: _constantTimeEquals(
          md5.convert(utf8.encode(password)).toString(),
          storedPassword,
        ),
        needsUpgrade: true,
      );
    }

    return PasswordVerificationResult(
      isValid: _constantTimeEquals(password, storedPassword),
      needsUpgrade: true,
    );
  }

  PasswordVerificationResult _verifyPbkdf2Password(
    String password,
    String storedPassword,
  ) {
    try {
      final parts = storedPassword.split(r'$');
      if (parts.length != 4 || parts[0] != _algorithm) {
        return const PasswordVerificationResult(isValid: false);
      }

      final iterations = int.tryParse(parts[1]);
      if (iterations == null ||
          iterations <= 0 ||
          iterations > _maxSupportedIterations) {
        return const PasswordVerificationResult(isValid: false);
      }

      final salt = base64Decode(parts[2]);
      final expectedHash = base64Decode(parts[3]);
      if (salt.isEmpty || expectedHash.length != _derivedKeyLength) {
        return const PasswordVerificationResult(isValid: false);
      }

      final actualHash = _deriveKey(password, salt, iterations);
      return PasswordVerificationResult(
        isValid: _constantTimeBytesEqual(actualHash, expectedHash),
        needsUpgrade: iterations != _iterations,
      );
    } on FormatException {
      return const PasswordVerificationResult(isValid: false);
    }
  }

  List<int> _deriveKey(String password, List<int> salt, int iterations) {
    final passwordBytes = utf8.encode(password);
    final output = <int>[];
    var blockIndex = 1;

    while (output.length < _derivedKeyLength) {
      var block = <int>[...salt, ..._int32BigEndian(blockIndex)];
      var digest = Hmac(sha256, passwordBytes).convert(block).bytes;
      final xor = List<int>.from(digest);

      for (var iteration = 1; iteration < iterations; iteration++) {
        digest = Hmac(sha256, passwordBytes).convert(digest).bytes;
        for (var index = 0; index < xor.length; index++) {
          xor[index] ^= digest[index];
        }
      }

      output.addAll(xor);
      blockIndex++;
    }

    return output.sublist(0, _derivedKeyLength);
  }

  List<int> _int32BigEndian(int value) => [
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff,
      ];

  bool _isHexDigest(String value, int length) =>
      value.length == length && RegExp(r'^[a-fA-F0-9]+$').hasMatch(value);

  bool _constantTimeEquals(String left, String right) =>
      _constantTimeBytesEqual(utf8.encode(left), utf8.encode(right));

  bool _constantTimeBytesEqual(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var index = 0; index < length; index++) {
      final leftByte = index < left.length ? left[index] : 0;
      final rightByte = index < right.length ? right[index] : 0;
      difference |= leftByte ^ rightByte;
    }
    return difference == 0;
  }
}

class PasswordVerificationResult {
  final bool isValid;
  final bool needsUpgrade;

  const PasswordVerificationResult({
    required this.isValid,
    this.needsUpgrade = false,
  });
}
