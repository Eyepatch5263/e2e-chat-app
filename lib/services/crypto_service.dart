import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../crypto/key_manager.dart';
import '../crypto/x3dh_handshake.dart';
import '../crypto/ratchet.dart';
import '../crypto/encrypt.dart';
import '../crypto/decrypt.dart';
import '../models/key_bundle.dart';
import '../storage/secure_storage.dart';

// ---------------------------------------------------------------------------
// CryptoService – the ONLY bridge between UI/business and crypto layers
// ---------------------------------------------------------------------------
//
// ARCHITECTURE RULE:
//   Flutter widgets / providers MUST call CryptoService.
//   They MUST NEVER import anything from crypto/ directly.
//
// This centralisation guarantees:
//   1. Key material handling is auditable in one place.
//   2. Side effects (secure-storage writes, key deletion) are managed.
//   3. The crypto/ folder can be reviewed or replaced independently.
// ---------------------------------------------------------------------------

class CryptoService {
  /// Generate all keypairs on first launch and persist them.
  /// Returns the derived user_id.
  static Future<String> initializeKeys() async {
    final identityKP   = await KeyManager.generateIdentityKeyPair();
    final identityDhKP = await KeyManager.generateIdentityDhKeyPair();
    final prekeyKP     = await KeyManager.generateSignedPrekey();

    final prekeyPub = await prekeyKP.extractPublicKey();
    final sig = await KeyManager.signPrekey(prekeyPub.bytes, identityKP);
    final sigB64 = base64Encode(sig.bytes);

    final idPub = await identityKP.extractPublicKey();
    final userId = await KeyManager.deriveUserId(SimplePublicKey(idPub.bytes, type: KeyPairType.ed25519));

    await SecureStorage.storeKeyBundle(
      identityKeyPair:   identityKP,
      identityDhKeyPair: identityDhKP,
      signedPrekeyPair:  prekeyKP,
      signatureB64:      sigB64,
      userId:            userId,
    );
    return userId;
  }

  // ── X3DH handshake (initiator) ─────────────────────────────────────────

  static Future<X3dhSessionResult> initiateHandshake(
      KeyBundle peerBundle) async {
    final dhKP = await SecureStorage.getIdentityDhKeyPair();
    final idKP = await SecureStorage.getIdentityKeyPair();
    if (dhKP == null || idKP == null) {
      throw StateError('Keypairs not found in secure storage');
    }

    // Parse peer public keys
    final peerDhPub = SimplePublicKey(
        base64Decode(peerBundle.identityDhPublicKey),
        type: KeyPairType.x25519);
    final peerPrekeyPub = SimplePublicKey(
        base64Decode(peerBundle.signedPrekeyPublic),
        type: KeyPairType.x25519);
    final peerIdPub = SimplePublicKey(
        base64Decode(peerBundle.identityPublicKey),
        type: KeyPairType.ed25519);

    // Verify prekey signature
    final sigBytes = base64Decode(peerBundle.signedPrekeySignature);
    final valid = await KeyManager.verifyPrekeySignature(
      peerPrekeyPub.bytes,
      Signature(sigBytes, publicKey: peerIdPub),
      peerIdPub,
    );
    if (!valid) throw SecurityException('Prekey signature verification failed');

    // Perform X3DH
    final result = await X3dhHandshake.performInitiatorHandshake(
      identityDhKeyPair:      dhKP,
      peerIdentityDhPublic:   peerDhPub,
      peerSignedPrekeyPublic: peerPrekeyPub,
    );

    final chainKey = await Ratchet.initializeChainKey(result.sessionKey);
    return X3dhSessionResult(
      chainKey:           chainKey,
      ephemeralPublicKey: result.ephemeralPublicKey,
    );
  }

  // ── X3DH handshake (responder) ─────────────────────────────────────────

  static Future<String> respondToHandshake({
    required String peerIdentityDhPublicB64,
    required String peerEphemeralPublicB64,
  }) async {
    final dhKP = await SecureStorage.getIdentityDhKeyPair();
    final pkKP = await SecureStorage.getSignedPrekeyPair();
    if (dhKP == null || pkKP == null) {
      throw StateError('Keypairs not found');
    }

    final sessionKey = await X3dhHandshake.performResponderHandshake(
      identityDhKeyPair:   dhKP,
      signedPrekeyPair:    pkKP,
      peerIdentityDhPublic: SimplePublicKey(
          base64Decode(peerIdentityDhPublicB64), type: KeyPairType.x25519),
      peerEphemeralPublic: SimplePublicKey(
          base64Decode(peerEphemeralPublicB64), type: KeyPairType.x25519),
    );
    return await Ratchet.initializeChainKey(sessionKey);
  }

  // ── Encrypt / Decrypt with ratchet ─────────────────────────────────────

  static Future<EncryptResult> encryptMessage({
    required String plaintext,
    required String chainKey,
    required String senderId,
    required String recipientId,
  }) async {
    final step = await Ratchet.ratchetStep(chainKey);
    final ct = await MessageEncryptor.encrypt(
      plaintext:     plaintext,
      messageKeyB64: step.messageKey,
      senderId:      senderId,
      recipientId:   recipientId,
    );
    // messageKey is now consumed – only nextChainKey survives.
    return EncryptResult(ciphertext: ct, nextChainKey: step.nextChainKey);
  }

  static Future<DecryptResult> decryptMessage({
    required String ciphertext,
    required String chainKey,
    required String senderId,
    required String recipientId,
  }) async {
    final step = await Ratchet.ratchetStep(chainKey);
    final pt = await MessageDecryptor.decrypt(
      ciphertextB64: ciphertext,
      messageKeyB64: step.messageKey,
      senderId:      senderId,
      recipientId:   recipientId,
    );
    return DecryptResult(plaintext: pt, nextChainKey: step.nextChainKey);
  }
}

// ── Result types ──────────────────────────────────────────────────────────

class X3dhSessionResult {
  final String chainKey;
  final String ephemeralPublicKey;
  X3dhSessionResult({required this.chainKey, required this.ephemeralPublicKey});
}

class EncryptResult {
  final String ciphertext;
  final String nextChainKey;
  EncryptResult({required this.ciphertext, required this.nextChainKey});
}

class DecryptResult {
  final String plaintext;
  final String nextChainKey;
  DecryptResult({required this.plaintext, required this.nextChainKey});
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}
