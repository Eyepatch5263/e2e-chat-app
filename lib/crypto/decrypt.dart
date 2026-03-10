import 'dart:convert';
import 'package:cryptography/cryptography.dart';

// ---------------------------------------------------------------------------
// Message Decryption – XChaCha20-Poly1305 AEAD
// ---------------------------------------------------------------------------
//
// SECURITY MODEL
// ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
// • Reverses the encryption performed by MessageEncryptor.
// • Verifies the Poly1305 MAC before returning plaintext – a tampered
//   or re-routed message will throw, preventing the app from displaying
//   corrupted data.
// • The message key MUST be deleted after decryption (forward secrecy).
// ---------------------------------------------------------------------------

class MessageDecryptor {
  static final _cipher = Xchacha20.poly1305Aead();

  /// Decrypt [ciphertextB64] (nonce ‖ ciphertext ‖ MAC) with [messageKeyB64].
  ///
  /// Throws [SecretBoxAuthenticationError] if the MAC check fails
  /// (tampered message or wrong key).
  ///
  /// SECURITY: caller MUST delete [messageKeyB64] after this call.
  static Future<String> decrypt({
    required String ciphertextB64,
    required String messageKeyB64,
    required String senderId,
    required String recipientId,
  }) async {
    final secretKey = SecretKey(base64Decode(messageKeyB64));
    final combined  = base64Decode(ciphertextB64);

    const nonceLen = 24; // XChaCha20 nonce
    const macLen   = 16; // Poly1305 tag

    if (combined.length < nonceLen + macLen) {
      throw const FormatException(
          'Ciphertext too short to contain nonce and MAC');
    }

    final nonce      = combined.sublist(0, nonceLen);
    final cipherText = combined.sublist(nonceLen, combined.length - macLen);
    final macBytes   = combined.sublist(combined.length - macLen);

    final aad = utf8.encode('$senderId:$recipientId');

    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));

    final plainBytes = await _cipher.decrypt(box, secretKey: secretKey, aad: aad);
    return utf8.decode(plainBytes);
  }
}
