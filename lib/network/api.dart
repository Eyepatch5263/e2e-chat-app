import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/key_bundle.dart';
import '../models/user_model.dart';

/// REST client for the relay server.
///
/// The server is a zero-knowledge relay: it stores ONLY public keys
/// and forwards encrypted blobs.  It never sees plaintext.
class ApiClient {
  static String get _base => AppConfig.httpBaseUrl;

  /// Register this device's public keys and username.
  /// Returns a [RegisterResult] with success/failure details.
  static Future<RegisterResult> register({
    required String userId,
    required String username,
    required String identityPublicKey,
    required String identityDhPublicKey,
    required String signedPrekeyPublic,
    required String signedPrekeySignature,
  }) async {
    try {
      print('[API] Registering at $_base/register ...');
      final res = await http.post(
        Uri.parse('$_base/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'username': username,
          'identity_public_key': identityPublicKey,
          'identity_dh_public_key': identityDhPublicKey,
          'signed_prekey_public': signedPrekeyPublic,
          'signed_prekey_signature': signedPrekeySignature,
        }),
      );
      print('[API] register response: ${res.statusCode} ${res.body}');

      if (res.statusCode == 201) {
        return RegisterResult(success: true);
      } else if (res.statusCode == 409) {
        return RegisterResult(success: false, error: 'Username already taken');
      } else {
        final body = json.decode(res.body);
        return RegisterResult(
          success: false,
          error: body['error']?.toString() ?? 'Server error ${res.statusCode}',
        );
      }
    } catch (e) {
      print('[API] register failed: $e');
      return RegisterResult(success: false, error: e.toString());
    }
  }

  /// Search users by partial username (case-insensitive).
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      final res = await http.get(Uri.parse('$_base/search?username=$query'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return (data['results'] as List)
            .map((r) => UserModel.fromJson(r))
            .toList();
      }
    } catch (e) {
      print('[API] search failed: $e');
    }
    return [];
  }

  /// Fetch a peer's public key bundle for X3DH.
  static Future<KeyBundle?> fetchKeyBundle(String userId) async {
    try {
      final res = await http.get(Uri.parse('$_base/keys/$userId'));
      if (res.statusCode == 200) {
        return KeyBundle.fromJson(json.decode(res.body));
      }
    } catch (e) {
      print('[API] fetchKeyBundle failed: $e');
    }
    return null;
  }
}

/// Result of a registration attempt with error details.
class RegisterResult {
  final bool success;
  final String? error;
  RegisterResult({required this.success, this.error});
}
