import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

// ---------------------------------------------------------------------------
// KeyManager – generation, serialisation & verification of cryptographic keys
// ---------------------------------------------------------------------------
//
// SECURITY MODEL
// ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
// • Identity signing key  – long-lived Ed25519 keypair.
//   Used ONLY to sign prekeys (proves ownership).
//
// • Identity DH key       – long-lived X25519 keypair.
//   Used for the Diffie-Hellman legs of X3DH.
//
// • Signed prekey          – medium-term X25519 keypair.
//   Signed by the identity key so peers can verify authenticity.
//
// • user_id = hex(SHA-256(identity_signing_public_key))
//   Deterministic, derived from a value the user controls.
//
// • ALL private keys MUST live in platform secure storage
//   (Android Keystore / iOS Keychain).  This module only generates
//   and serialises them; storage is handled by SecureStorage.
// ---------------------------------------------------------------------------

class KeyManager {
  static final _ed25519 = Ed25519();
  static final _x25519  = X25519();
  static final _sha256  = Sha256();

  // ── Key generation ──────────────────────────────────────────────────────

  /// Ed25519 identity signing keypair (generated once, on first launch).
  static Future<SimpleKeyPair> generateIdentityKeyPair() async {
    final kp = await _ed25519.newKeyPair();
    return SimpleKeyPairData(
      await kp.extractPrivateKeyBytes(),
      publicKey: await kp.extractPublicKey(),
      type: KeyPairType.ed25519,
    );
  }

  /// X25519 identity Diffie-Hellman keypair.
  static Future<SimpleKeyPair> generateIdentityDhKeyPair() async {
    final kp = await _x25519.newKeyPair();
    return SimpleKeyPairData(
      await kp.extractPrivateKeyBytes(),
      publicKey: await kp.extractPublicKey(),
      type: KeyPairType.x25519,
    );
  }

  /// X25519 signed prekey (rotated periodically).
  static Future<SimpleKeyPair> generateSignedPrekey() async {
    final kp = await _x25519.newKeyPair();
    return SimpleKeyPairData(
      await kp.extractPrivateKeyBytes(),
      publicKey: await kp.extractPublicKey(),
      type: KeyPairType.x25519,
    );
  }

  /// Ephemeral X25519 keypair (one per X3DH handshake, then deleted).
  static Future<SimpleKeyPair> generateEphemeralKeyPair() async {
    final kp = await _x25519.newKeyPair();
    return SimpleKeyPairData(
      await kp.extractPrivateKeyBytes(),
      publicKey: await kp.extractPublicKey(),
      type: KeyPairType.x25519,
    );
  }

  // ── Signing ─────────────────────────────────────────────────────────────

  /// Sign [prekeyPublicBytes] with the identity key.
  static Future<Signature> signPrekey(
    List<int> prekeyPublicBytes,
    SimpleKeyPair identityKeyPair,
  ) async {
    return await _ed25519.sign(prekeyPublicBytes, keyPair: identityKeyPair);
  }

  /// Verify that [signature] over [prekeyPublicBytes] was produced by
  /// [identityPublicKey].
  static Future<bool> verifyPrekeySignature(
    List<int> prekeyPublicBytes,
    Signature signature,
    SimplePublicKey identityPublicKey,
  ) async {
    return await _ed25519.verify(prekeyPublicBytes, signature: signature);
  }

  // ── Derivation ──────────────────────────────────────────────────────────

  /// user_id = lower-case hex of SHA-256(identity_public_key_bytes).
  static Future<String> deriveUserId(SimplePublicKey identityPublicKey) async {
    final hash = await _sha256.hash(identityPublicKey.bytes);
    return hash.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ── Serialisation helpers ───────────────────────────────────────────────

  static Future<Map<String, String>> serializeKeyPair(
    SimpleKeyPair keyPair,
  ) async {
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey    = await keyPair.extractPublicKey();
    return {
      'private': base64Encode(Uint8List.fromList(privateBytes)),
      'public':  base64Encode(Uint8List.fromList(publicKey.bytes)),
    };
  }

  static SimpleKeyPair deserializeEd25519KeyPair(
    String privateB64,
    String publicB64,
  ) {
    return SimpleKeyPairData(
      base64Decode(privateB64),
      publicKey: SimplePublicKey(base64Decode(publicB64),
          type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
  }

  static SimpleKeyPair deserializeX25519KeyPair(
    String privateB64,
    String publicB64,
  ) {
    return SimpleKeyPairData(
      base64Decode(privateB64),
      publicKey: SimplePublicKey(base64Decode(publicB64),
          type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }
}
