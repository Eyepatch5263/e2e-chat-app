import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import '../crypto/key_manager.dart';

// ---------------------------------------------------------------------------
// SecureStorage – platform-backed encrypted key storage
// ---------------------------------------------------------------------------
//
// SECURITY MODEL
// ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
// • Android → EncryptedSharedPreferences (backed by Android Keystore).
// • iOS     → Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
//
// Private keys NEVER leave secure storage in cleartext.
// All values are base64-encoded byte strings.
// ---------------------------------------------------------------------------

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // ── Storage key constants ───────────────────────────────────────────────
  static const _kIdentityPriv     = 'identity_private_key';
  static const _kIdentityPub      = 'identity_public_key';
  static const _kIdentityDhPriv   = 'identity_dh_private_key';
  static const _kIdentityDhPub    = 'identity_dh_public_key';
  static const _kPrekeyPriv       = 'signed_prekey_private_key';
  static const _kPrekeyPub        = 'signed_prekey_public_key';
  static const _kPrekeySig        = 'signed_prekey_signature';
  static const _kUserId           = 'user_id';
  static const _kUsername          = 'username';

  // ── Existence check ─────────────────────────────────────────────────────

  static Future<bool> hasIdentityKeys() async =>
      (await _storage.read(key: _kIdentityPriv)) != null;

  // ── Bulk store after key generation ─────────────────────────────────────

  static Future<void> storeKeyBundle({
    required SimpleKeyPair identityKeyPair,
    required SimpleKeyPair identityDhKeyPair,
    required SimpleKeyPair signedPrekeyPair,
    required String signatureB64,
    required String userId,
  }) async {
    final id   = await KeyManager.serializeKeyPair(identityKeyPair);
    final idDh = await KeyManager.serializeKeyPair(identityDhKeyPair);
    final pk   = await KeyManager.serializeKeyPair(signedPrekeyPair);

    await Future.wait([
      _storage.write(key: _kIdentityPriv,   value: id['private']!),
      _storage.write(key: _kIdentityPub,    value: id['public']!),
      _storage.write(key: _kIdentityDhPriv, value: idDh['private']!),
      _storage.write(key: _kIdentityDhPub,  value: idDh['public']!),
      _storage.write(key: _kPrekeyPriv,     value: pk['private']!),
      _storage.write(key: _kPrekeyPub,      value: pk['public']!),
      _storage.write(key: _kPrekeySig,      value: signatureB64),
      _storage.write(key: _kUserId,         value: userId),
    ]);
  }

  // ── Username ────────────────────────────────────────────────────────────

  static Future<void> storeUsername(String u) =>
      _storage.write(key: _kUsername, value: u);

  static Future<String?> getUsername() => _storage.read(key: _kUsername);

  // ── Scalar reads ────────────────────────────────────────────────────────

  static Future<String?> getUserId()              => _storage.read(key: _kUserId);
  static Future<String?> getIdentityPublicKey()   => _storage.read(key: _kIdentityPub);
  static Future<String?> getIdentityDhPublicKey() => _storage.read(key: _kIdentityDhPub);
  static Future<String?> getSignedPrekeyPublic()  => _storage.read(key: _kPrekeyPub);
  static Future<String?> getSignedPrekeySignature() => _storage.read(key: _kPrekeySig);

  // ── Keypair reads ───────────────────────────────────────────────────────

  static Future<SimpleKeyPair?> getIdentityKeyPair() async {
    final priv = await _storage.read(key: _kIdentityPriv);
    final pub  = await _storage.read(key: _kIdentityPub);
    if (priv == null || pub == null) return null;
    return KeyManager.deserializeEd25519KeyPair(priv, pub);
  }

  static Future<SimpleKeyPair?> getIdentityDhKeyPair() async {
    final priv = await _storage.read(key: _kIdentityDhPriv);
    final pub  = await _storage.read(key: _kIdentityDhPub);
    if (priv == null || pub == null) return null;
    return KeyManager.deserializeX25519KeyPair(priv, pub);
  }

  static Future<SimpleKeyPair?> getSignedPrekeyPair() async {
    final priv = await _storage.read(key: _kPrekeyPriv);
    final pub  = await _storage.read(key: _kPrekeyPub);
    if (priv == null || pub == null) return null;
    return KeyManager.deserializeX25519KeyPair(priv, pub);
  }

  // ── Wipe ────────────────────────────────────────────────────────────────

  static Future<void> clearAll() => _storage.deleteAll();
}
