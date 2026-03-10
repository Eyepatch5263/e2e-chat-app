/// Represents a registered user.
class UserModel {
  final String userId;
  final String username;
  final String? identityPublicKey;   // Base64 Ed25519 signing key
  final String? identityDhPublicKey; // Base64 X25519 DH key

  UserModel({
    required this.userId,
    required this.username,
    this.identityPublicKey,
    this.identityDhPublicKey,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      identityPublicKey: json['identity_public_key'] as String?,
      identityDhPublicKey: json['identity_dh_public_key'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'identity_public_key': identityPublicKey,
        'identity_dh_public_key': identityDhPublicKey,
      };
}
