import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'key_manager.dart';

// ---------------------------------------------------------------------------
// X3DH (Extended Triple Diffie-Hellman) Handshake
// ---------------------------------------------------------------------------
//
// SECURITY MODEL
// ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
// Signal-style key agreement producing a shared secret between two parties
// who have never communicated before.
//
// Initiator (Alice) starts a chat with Responder (Bob):
//
//   1.  Fetch Bob's key bundle from the server:
//         identity_dh_public (X25519), signed_prekey_public (X25519),
//         identity_public (Ed25519, for signature verification).
//
//   2.  Verify the Ed25519 signature on Bob's signed prekey.
//
//   3.  Generate an ephemeral X25519 keypair (EK_A).
//
//   4.  Compute three DH shared secrets:
//         DH1 = X25519(IK_A_dh_priv, SPK_B)     identity ↔ prekey
//         DH2 = X25519(EK_A_priv,    IK_B_dh)    ephemeral ↔ identity
//         DH3 = X25519(EK_A_priv,    SPK_B)      ephemeral ↔ prekey
//
//   5.  Derive session key = HKDF-SHA256(DH1 || DH2 || DH3).
//
//   6.  Send EK_A_pub to Bob so he can repeat the computation.
//
// The three DH legs guarantee:
//   • Mutual authentication (both long-term keys participate).
//   • Forward secrecy      (ephemeral key is deleted after use).
//   • Prekey freshness     (ephemeral ↔ prekey binding).
// ---------------------------------------------------------------------------

class X3dhHandshake {
  static final _x25519 = X25519();
  static final _hkdf   = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);

  /// Initiator side – returns session key + ephemeral public key to send.
  static Future<X3dhResult> performInitiatorHandshake({
    required SimpleKeyPair   identityDhKeyPair,
    required SimplePublicKey peerIdentityDhPublic,
    required SimplePublicKey peerSignedPrekeyPublic,
  }) async {
    // Ephemeral keypair – used once then discarded.
    final ek = await KeyManager.generateEphemeralKeyPair();
    final ekPublic = await ek.extractPublicKey();

    // Three DH shared secrets.
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: identityDhKeyPair, remotePublicKey: peerSignedPrekeyPublic);
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: ek, remotePublicKey: peerIdentityDhPublic);
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: ek, remotePublicKey: peerSignedPrekeyPublic);

    final sessionKey = await _deriveSessionKey(dh1, dh2, dh3);

    return X3dhResult(
      sessionKey:         base64Encode(Uint8List.fromList(sessionKey)),
      ephemeralPublicKey: base64Encode(Uint8List.fromList(ekPublic.bytes)),
    );
  }

  /// Responder side – called when receiving the first message with EK_A_pub.
  static Future<String> performResponderHandshake({
    required SimpleKeyPair   identityDhKeyPair,
    required SimpleKeyPair   signedPrekeyPair,
    required SimplePublicKey peerIdentityDhPublic,
    required SimplePublicKey peerEphemeralPublic,
  }) async {
    // Mirror the three DH computations with swapped roles.
    final dh1 = await _x25519.sharedSecretKey(
      keyPair: signedPrekeyPair, remotePublicKey: peerIdentityDhPublic);
    final dh2 = await _x25519.sharedSecretKey(
      keyPair: identityDhKeyPair, remotePublicKey: peerEphemeralPublic);
    final dh3 = await _x25519.sharedSecretKey(
      keyPair: signedPrekeyPair, remotePublicKey: peerEphemeralPublic);

    final sessionKey = await _deriveSessionKey(dh1, dh2, dh3);
    return base64Encode(Uint8List.fromList(sessionKey));
  }

  // ── internal ────────────────────────────────────────────────────────────

  static Future<List<int>> _deriveSessionKey(
    SecretKey dh1, SecretKey dh2, SecretKey dh3,
  ) async {
    final b1 = await dh1.extractBytes();
    final b2 = await dh2.extractBytes();
    final b3 = await dh3.extractBytes();

    final combined = Uint8List(b1.length + b2.length + b3.length)
      ..setAll(0, b1)
      ..setAll(b1.length, b2)
      ..setAll(b1.length + b2.length, b3);

    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(combined),
      nonce: utf8.encode('e2ee_x3dh_v1'), // protocol info string
    );
    return await derived.extractBytes();
  }
}

/// Result of an initiator X3DH handshake.
class X3dhResult {
  final String sessionKey;          // base64 – 32-byte session key
  final String ephemeralPublicKey;  // base64 – send to peer

  X3dhResult({required this.sessionKey, required this.ephemeralPublicKey});
}
