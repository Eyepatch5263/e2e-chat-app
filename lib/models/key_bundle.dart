/// Public key bundle fetched from the server during X3DH handshake.
///
/// Contains the peer's identity and signed prekey material needed
/// to compute the three Diffie-Hellman shared secrets.
class KeyBundle {
  final String identityPublicKey;      // Ed25519 signing key (base64)
  final String identityDhPublicKey;    // X25519 DH key (base64)
  final String signedPrekeyPublic;     // X25519 signed prekey (base64)
  final String signedPrekeySignature;  // Ed25519 signature over prekey (base64)

  KeyBundle({
    required this.identityPublicKey,
    required this.identityDhPublicKey,
    required this.signedPrekeyPublic,
    required this.signedPrekeySignature,
  });

  factory KeyBundle.fromJson(Map<String, dynamic> json) {
    return KeyBundle(
      identityPublicKey: json['identity_public_key'] as String,
      identityDhPublicKey: json['identity_dh_public_key'] as String,
      signedPrekeyPublic: json['signed_prekey_public'] as String,
      signedPrekeySignature: json['signed_prekey_signature'] as String,
    );
  }
}
