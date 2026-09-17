import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_bridge_service.dart';

class PinService {
  static const String _keyPinHash = 'security_pin_hash';
  static const String _keyPinEnabled = 'security_pin_enabled';
  static const String _keyFailedAttempts = 'pin_failed_attempts';
  static const String _keyLockoutUntil = 'pin_lockout_until';

  static const int _pbkdf2Iterations = 10000;
  static const int _keyLength = 32;

  /// Generates a cryptographically secure 16-byte random salt
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// PBKDF2-HMAC-SHA256 derivation
  static List<int> _pbkdf2HmacSha256({
    required List<int> passwordBytes,
    required List<int> saltBytes,
    required int iterations,
    int keyLength = _keyLength,
  }) {
    final hmac = Hmac(sha256, passwordBytes);
    // Block 1 (i = 1 in big-endian 32-bit int)
    final block1Input = <int>[...saltBytes, 0, 0, 0, 1];
    var u = hmac.convert(block1Input).bytes;
    final result = List<int>.from(u);

    for (var iter = 1; iter < iterations; iter++) {
      u = hmac.convert(u).bytes;
      for (var i = 0; i < result.length; i++) {
        result[i] ^= u[i];
      }
    }

    return result.sublist(0, keyLength);
  }

  /// Formats a PBKDF2 hash string: pbkdf2$iterations$salt$hashHex
  static String _createPbkdf2Hash(String pin, String saltBase64) {
    final passwordBytes = utf8.encode(pin);
    final saltBytes = base64Decode(saltBase64);
    final derivedKey = _pbkdf2HmacSha256(
      passwordBytes: passwordBytes,
      saltBytes: saltBytes,
      iterations: _pbkdf2Iterations,
    );
    final hashHex = derivedKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pbkdf2\$$_pbkdf2Iterations\$$saltBase64\$$hashHex';
  }

  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPinEnabled) ?? false;
  }

  static Future<bool> setPin(String pin) async {
    if (pin.length < 4) return false;
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hashRecord = _createPbkdf2Hash(pin, salt);
    await prefs.setString(_keyPinHash, hashRecord);
    await prefs.setBool(_keyPinEnabled, true);
    await NativeBridgeService.syncPinNative(hashRecord, true);
    return true;
  }

  static Future<void> disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyPinEnabled, false);
    await prefs.remove(_keyFailedAttempts);
    await prefs.remove(_keyLockoutUntil);
    await NativeBridgeService.syncPinNative('', false);
  }

  static Future<PinVerificationResult> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockoutUntil = prefs.getInt(_keyLockoutUntil) ?? 0;

    if (now < lockoutUntil) {
      final secondsLeft = ((lockoutUntil - now) / 1000).ceil();
      return PinVerificationResult(
        isSuccess: false,
        isLockedOut: true,
        secondsRemaining: secondsLeft,
        errorMessage: 'Too many failed attempts. Try again in $secondsLeft seconds.',
      );
    }

    final storedHash = prefs.getString(_keyPinHash);
    if (storedHash == null) {
      return PinVerificationResult(isSuccess: true);
    }

    bool isMatch = false;

    // Check if stored hash is PBKDF2 format
    if (storedHash.startsWith('pbkdf2\$')) {
      final parts = storedHash.split('\$');
      if (parts.length == 4) {
        final saltBase64 = parts[2];
        final expectedHex = parts[3];
        final computed = _createPbkdf2Hash(pin, saltBase64);
        final computedParts = computed.split('\$');
        if (computedParts.length == 4) {
          isMatch = _constantTimeEquals(expectedHex, computedParts[3]);
        }
      }
    } else {
      // Legacy SHA-256 fallback with static salt
      const legacySalt = 'app_locker_secure_salt_v2';
      final legacyBytes = utf8.encode(pin + legacySalt);
      final legacyHash = sha256.convert(legacyBytes).toString();
      isMatch = _constantTimeEquals(storedHash, legacyHash);

      // If matched legacy hash, transparently migrate to PBKDF2
      if (isMatch) {
        await setPin(pin);
      }
    }

    if (isMatch) {
      // Reset failed attempts upon successful verification
      await prefs.setInt(_keyFailedAttempts, 0);
      await prefs.remove(_keyLockoutUntil);
      return PinVerificationResult(isSuccess: true);
    } else {
      final attempts = (prefs.getInt(_keyFailedAttempts) ?? 0) + 1;
      await prefs.setInt(_keyFailedAttempts, attempts);

      if (attempts >= 5) {
        final lockUntil = now + 30000; // 30 seconds rate limiting
        await prefs.setInt(_keyLockoutUntil, lockUntil);
        return PinVerificationResult(
          isSuccess: false,
          isLockedOut: true,
          secondsRemaining: 30,
          errorMessage: '5 failed attempts. Please wait 30 seconds.',
        );
      }

      return PinVerificationResult(
        isSuccess: false,
        isLockedOut: false,
        errorMessage: 'Incorrect PIN. ${5 - attempts} attempts remaining.',
      );
    }
  }
}

class PinVerificationResult {
  final bool isSuccess;
  final bool isLockedOut;
  final int secondsRemaining;
  final String? errorMessage;

  PinVerificationResult({
    required this.isSuccess,
    this.isLockedOut = false,
    this.secondsRemaining = 0,
    this.errorMessage,
  });
}
