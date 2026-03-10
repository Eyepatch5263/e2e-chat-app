import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

// ---------------------------------------------------------------------------
// Chain-Key Ratchet – forward secrecy for every message
// ---------------------------------------------------------------------------
//
// SECURITY MODEL
// ‾‾‾‾‾‾‾‾‾‾‾‾‾‾
// After X3DH produces a session_key the ratchet derives a unique,
// single-use message key for each message while continuously advancing
// the chain key so that old keys can never be recovered.
//
// Protocol:
//   chain_key_0       = HMAC-SHA256(session_key, "chain_init")
//
//   For message N:
//     message_key_N   = HMAC-SHA256(chain_key_N, "msg_key")
//     chain_key_(N+1) = HMAC-SHA256(chain_key_N, "chain_advance")
//
//   After use:
//     DELETE chain_key_N           (replaced by N+1)
//     DELETE message_key_N         (used once then discarded)
//
// Compromise of the current chain_key cannot recover past message keys
// because HMAC is a one-way function – this is forward secrecy.
// ---------------------------------------------------------------------------

class Ratchet {
  static final _hmac = Hmac.sha256();

  /// Initialise chain_key_0 from the X3DH session key.
  static Future<String> initializeChainKey(String sessionKeyB64) async {
    final mac = await _hmac.calculateMac(
      utf8.encode('chain_init'),
      secretKey: SecretKey(base64Decode(sessionKeyB64)),
    );
    return base64Encode(Uint8List.fromList(mac.bytes));
  }

  /// Derive a one-time message key from the current chain key.
  static Future<String> deriveMessageKey(String chainKeyB64) async {
    final mac = await _hmac.calculateMac(
      utf8.encode('msg_key'),
      secretKey: SecretKey(base64Decode(chainKeyB64)),
    );
    return base64Encode(Uint8List.fromList(mac.bytes));
  }

  /// Advance the chain key – old value MUST be deleted.
  static Future<String> advanceChainKey(String chainKeyB64) async {
    final mac = await _hmac.calculateMac(
      utf8.encode('chain_advance'),
      secretKey: SecretKey(base64Decode(chainKeyB64)),
    );
    return base64Encode(Uint8List.fromList(mac.bytes));
  }

  /// Atomic ratchet step: derive message key + advance chain.
  static Future<RatchetStep> ratchetStep(String currentChainKeyB64) async {
    final messageKey   = await deriveMessageKey(currentChainKeyB64);
    final nextChainKey = await advanceChainKey(currentChainKeyB64);
    return RatchetStep(messageKey: messageKey, nextChainKey: nextChainKey);
  }
}

/// One ratchet tick: a single-use message key and the next chain key.
class RatchetStep {
  final String messageKey;    // base64 – encrypt/decrypt then DELETE
  final String nextChainKey;  // base64 – store, replacing the old chain key

  RatchetStep({required this.messageKey, required this.nextChainKey});
}
