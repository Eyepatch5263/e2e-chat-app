# SecureChat — End-to-End Encrypted Messenger

A production-grade **end-to-end encrypted (E2EE)** chat application built with **Flutter** and a **Signal-inspired cryptographic protocol** (X3DH + chain-key ratchet). Designed for maximum security with hardware-level device binding, forward secrecy per message, and zero-knowledge server architecture.

---

## Features

- **Signal-style E2EE** — X3DH key agreement + HMAC-SHA256 chain-key ratchet + XChaCha20-Poly1305 AEAD
- **Forward secrecy** — unique encryption key per message; past messages stay safe even if current keys are compromised
- **Zero-knowledge relay server** — server never sees plaintext, private keys, or unencrypted metadata
- **USB hardware authentication** — app requires a specific USB device to be connected; removal triggers full account wipe
- **Device ID locking** — restricts the app to a single authorized Android device
- **Screenshot & screen recording blocked** — `FLAG_SECURE` on all screens
- **Self-destructing messages** — configurable timers: 15 s, 30 s, 1 min, or off
- **Automatic account reset** — USB removal wipes all keys, sessions, and local data instantly
- **Secure key storage** — Android Keystore / iOS Keychain via `flutter_secure_storage`
- **Material 3 UI** — pink-themed light mode design

---

## Architecture

```
Flutter UI (Material 3)
    │
Provider (AuthProvider, ChatProvider)
    │
Service Layer (ChatService, CryptoService, WebSocketService)
    │
┌───┴───┐
Crypto Layer             Storage Layer
(KeyManager, X3DH,       (SecureStorage,
 Ratchet, AEAD)           SessionStore)
    │                         │
Ed25519, X25519,         Android Keystore /
XChaCha20-Poly1305       iOS Keychain
```

---

## Cryptographic Protocol

### Key Generation

| Key | Algorithm | Purpose |
|-----|-----------|---------|
| Identity Signing Key | Ed25519 | Long-lived; signs prekeys |
| Identity DH Key | X25519 | Long-lived; X3DH leg |
| Signed Prekey | X25519 | Medium-term; signed by identity key |
| Ephemeral Key | X25519 | One-time per handshake; deleted after use |

**User ID** is derived deterministically: `hex(SHA-256(identity_signing_public_key))`.

### X3DH Handshake

Initiator (Alice) → Responder (Bob):

1. Fetch Bob’s key bundle from server (identity keys + signed prekey + signature)
2. Verify prekey signature (Ed25519)
3. Generate ephemeral keypair `EK_A`
4. Compute three X25519 DH shared secrets:
   ```
   DH1 = X25519(IK_A_dh_priv, SPK_B)       // identity <-> prekey
   DH2 = X25519(EK_A_priv,    IK_B_dh)     // ephemeral <-> identity
   DH3 = X25519(EK_A_priv,    SPK_B)       // ephemeral <-> prekey
   ```
5. Derive 32-byte session key:
   ```
   session_key = HKDF-SHA256(DH1 || DH2 || DH3, nonce='e2ee_x3dh_v1')
   ```
6. Delete ephemeral private key immediately

### Chain-Key Ratchet (Forward Secrecy)

```
chain_key_0 = HMAC-SHA256(session_key, "chain_init")

For each message N:
  message_key_N   = HMAC-SHA256(chain_key_N, "msg_key")
  chain_key_(N+1) = HMAC-SHA256(chain_key_N, "chain_advance")

  -> chain_key_N is deleted (replaced by N+1)
  -> message_key_N is used once then discarded
```

### Message Encryption (AEAD)

| Parameter | Value |
|-----------|-------|
| Cipher | XChaCha20-Poly1305 |
| Nonce | 24 random bytes per message |
| AAD | `senderId:recipientId` (prevents re-routing) |
| Wire format | `base64(nonce + ciphertext + MAC)` |

---

## Project Structure

```
lib/
├── main.dart                    # Entry point, MultiProvider setup
├── app.dart                     # Root widget, routing, Material 3 theme
├── config.dart                  # Server URL configuration
├── components/
│   ├── chat_input.dart          # Message input + self-destruct timer
│   └── message_bubble.dart      # Message bubble with status & countdown
├── crypto/
│   ├── key_manager.dart         # Key generation & signing
│   ├── x3dh_handshake.dart      # X3DH key agreement
│   ├── ratchet.dart             # Chain-key ratchet
│   ├── encrypt.dart             # XChaCha20-Poly1305 encryption
│   └── decrypt.dart             # AEAD decryption + MAC verification
├── models/
│   ├── chat_message.dart        # Message model with expiry & status
│   ├── chat_session.dart        # Peer session with chain key state
│   ├── key_bundle.dart          # Peer public key material
│   └── user_model.dart
├── network/
│   ├── api.dart                 # REST client (register, search, keys)
│   └── websocket_service.dart   # Real-time WebSocket relay
├── providers/
│   ├── auth_provider.dart       # Key generation & registration state
│   └── chat_provider.dart       # ChangeNotifier exposing ChatService
├── screens/
│   ├── splash_screen.dart       # Key generation on first launch
│   ├── username_setup_screen.dart
│   ├── security_check_screen.dart  # USB + device ID verification
│   ├── chat_list_screen.dart
│   ├── chat_screen.dart         # Individual chat UI
│   ├── search_screen.dart
│   └── settings_screen.dart
├── services/
│   ├── chat_service.dart        # Message orchestration & session mgmt
│   └── crypto_service.dart      # Bridge between UI and crypto layer
└── storage/
    ├── secure_storage.dart      # Android Keystore / iOS Keychain
    └── session_store.dart       # Persistent session state

android/app/src/main/kotlin/com/pratyush/securechat/
└── MainActivity.kt              # USB detection, device ID, FLAG_SECURE
```

---

## Security Features

### USB Hardware Authentication
- App requires a specific USB device (vendor/product ID) to be physically connected
- Native `MethodChannel` + `EventChannel` for USB attach/detach detection
- **USB removal instantly wipes** all keys, sessions, and local data

### Device ID Locking
- Verifies `Settings.Secure.ANDROID_ID` against a hardcoded whitelist
- Prevents the app from running on unauthorized devices

### Screenshot Prevention
- `FLAG_SECURE` set in `MainActivity.onCreate()`
- Blocks screenshots, screen recording, and screen mirroring on all screens

### Self-Destructing Messages
- Configurable per-message: **15 s**, **30 s**, **1 min**, or **off**
- Visual countdown timer in message bubble
- Messages removed from UI after expiry

### Account Wipe on USB Removal
- USB detach event triggers full reset:
  - Clears `SecureStorage` (all private keys)
  - Clears `SessionStore` (all chain keys)
  - Resets `ChatProvider` and `AuthProvider` in-memory state
  - Navigates back to registration screen

---

## Server Protocol

The relay server is a **zero-knowledge** Node.js + Express + WebSocket service.

### REST Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/register` | Register user with public keys |
| `GET` | `/search?username=query` | Search for users |
| `GET` | `/keys/:user_id` | Fetch peer's key bundle |
| `GET` | `/health` | Health check |

### WebSocket (`/connect`)

```json
// Authentication
{ "type": "auth", "user_id": "..." }
{ "type": "welcome" }

// Encrypted message relay
{
    "type": "chat_message",
    "recipient_id": "...",
    "ciphertext": "base64(...)",
    "ratchet_counter": 42,
    "ephemeral_key": "base64(...)",
    "timestamp": "...",
    "expires_at": "... | null"
}

// Delivery acknowledgment
{ "type": "delivery_ack", "message_id": "..." }
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.9.2)
- Android device or emulator
- A deployed relay server instance

### Install Dependencies

```bash
flutter pub get
```

### Run (Development)

```bash
flutter run
```

By default connects to `http://10.0.2.2:3000` (Android emulator loopback to host).

### Build Release APK

```bash
flutter build apk --release --dart-define=SERVER_URL=https://your-relay-server.com
```

### Configure Server URL

Set at compile time via `--dart-define`:

```bash
flutter run --dart-define=SERVER_URL=https://your-relay-server.com
```

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `cryptography` | ^2.7.0 | Ed25519, X25519, XChaCha20-Poly1305, HKDF, SHA-256 |
| `flutter_secure_storage` | ^9.2.4 | Android Keystore / iOS Keychain |
| `web_socket_channel` | ^3.0.2 | WebSocket client |
| `http` | ^1.3.0 | REST API client |
| `provider` | ^6.1.5 | State management |
| `intl` | ^0.20.2 | Date/time formatting |
| `shared_preferences` | ^2.5.3 | Session persistence |

---

## License

This project is for educational and personal use.