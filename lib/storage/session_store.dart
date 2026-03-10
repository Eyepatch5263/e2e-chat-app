import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';

/// Persists chat session state (chain keys, counters) across app restarts.
///
/// NOTE: In production the chain keys should also go into secure storage.
/// SharedPreferences is used here for demo simplicity.
class SessionStore {
  static const _key = 'chat_sessions';

  static Future<Map<String, ChatSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final Map<String, dynamic> decoded = json.decode(raw);
    return decoded.map((k, v) => MapEntry(k, ChatSession.fromJson(v)));
  }

  static Future<void> saveSession(ChatSession session) async {
    final all = await loadSessions();
    all[session.peerId] = session;
    await _persist(all);
  }

  static Future<ChatSession?> getSession(String peerId) async =>
      (await loadSessions())[peerId];

  static Future<void> deleteSession(String peerId) async {
    final all = await loadSessions();
    all.remove(peerId);
    await _persist(all);
  }

  static Future<void> clearAll() async =>
      (await SharedPreferences.getInstance()).remove(_key);

  static Future<void> _persist(Map<String, ChatSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      json.encode(sessions.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
