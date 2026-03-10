import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../storage/secure_storage.dart';
import '../network/api.dart';

enum AuthState { loading, needsSetup, needsUsername, authenticated }

/// Manages identity key generation, registration, and auth state.
class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.loading;
  String? _userId;
  String? _username;
  String? _lastError;

  AuthState get state     => _state;
  String?   get userId    => _userId;
  String?   get username  => _username;
  String?   get lastError => _lastError;

  /// Check secure storage for existing keys.
  Future<void> initialize() async {
    if (!(await SecureStorage.hasIdentityKeys())) {
      _state = AuthState.needsSetup;
      notifyListeners();
      return;
    }
    _userId   = await SecureStorage.getUserId();
    _username = await SecureStorage.getUsername();
    _state = _username == null ? AuthState.needsUsername : AuthState.authenticated;
    notifyListeners();
  }

  /// First launch: generate identity + DH + signed prekey.
  Future<void> generateKeys() async {
    _state = AuthState.loading;
    notifyListeners();
    _userId = await CryptoService.initializeKeys();
    _state = AuthState.needsUsername;
    notifyListeners();
  }

  /// Register username with the relay server.
  /// Returns true on success; on failure sets [lastError].
  Future<bool> registerUsername(String username) async {
    _lastError = null;
    if (_userId == null) {
      _lastError = 'No user ID – keys may not have been generated';
      return false;
    }

    final idPub   = await SecureStorage.getIdentityPublicKey();
    final dhPub   = await SecureStorage.getIdentityDhPublicKey();
    final pkPub   = await SecureStorage.getSignedPrekeyPublic();
    final pkSig   = await SecureStorage.getSignedPrekeySignature();

    if ([idPub, dhPub, pkPub, pkSig].any((v) => v == null)) {
      _lastError = 'Key material missing from secure storage';
      return false;
    }

    final result = await ApiClient.register(
      userId:                _userId!,
      username:              username,
      identityPublicKey:     idPub!,
      identityDhPublicKey:   dhPub!,
      signedPrekeyPublic:    pkPub!,
      signedPrekeySignature: pkSig!,
    );

    if (result.success) {
      await SecureStorage.storeUsername(username);
      _username = username;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } else {
      _lastError = result.error ?? 'Registration failed';
      notifyListeners();
      return false;
    }
  }
}
