import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

// ---------------------------------------------------------------------------
// Message Encryption – XChaCha20-Poly1305 AEAD
// ---------------------------------------------------------------------------
//
// SECURITY MODEL
// ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
// • Each message is encrypted with a UNIQUE message key from the ratchet.
// • XChaCha20-Poly1305 provides authenticated encryption:
//     – Confidentiality  (ChaCha20 stream cipher)
//     – Integrity + Auth (Poly1305 MAC)
// • A random 24-byte nonce is generated per message (XChaCha20 nonce space
//   is large enough that collisions are negligible).
// • AAD = "senderId:recipientId" binds ciphertext to participants,
//   preventing message re-routing attacks.
// • The message key MUST be deleted after encryption (forward secrecy).
// ---------------------------------------------------------------------------

class MessageEncryptor {
  static final _cipher = Xchacha20.poly1305Aead();

  /// Encrypt [plaintext] with a single-use [messageKeyB64].
  ///
  /// Returns base64(nonce ‖ ciphertext ‖ MAC).
  ///
  /// SECURITY: caller MUST delete [messageKeyB64] after this call.
  static Future<String> encrypt({
    required String plaintext,
    required String messageKeyB64,
    required String senderId,
    required String recipientId,
  }) async {
    final secretKey = SecretKey(base64Decode(messageKeyB64));

    // AAD prevents a relay from re-routing a ciphertext to another user.
    final aad = utf8.encode('$senderId:$recipientId');

    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      aad: aad,
    );

    // Wire format: nonce (24 B) ‖ ciphertext ‖ MAC (16 B)
    final combined = Uint8List(
        box.nonce.length + box.cipherText.length + box.mac.bytes.length)
      ..setAll(0, box.nonce)
      ..setAll(box.nonce.length, box.cipherText)
      ..setAll(box.nonce.length + box.cipherText.length, box.mac.bytes);

    return base64Encode(combined);
  }
}
