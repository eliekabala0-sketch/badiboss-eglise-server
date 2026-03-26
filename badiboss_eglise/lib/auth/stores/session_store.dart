import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

final class SessionStore {
  static const String _kKey = 'badiboss_eglise__session_v1';

  const SessionStore();

  Future<AppSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      return AppSession.fromJsonString(raw);
    } catch (_) {
      // VERROUILLÉ : session corrompue => purge immédiate (pas de crash)
      await prefs.remove(_kKey);
      return null;
    }
  }

  Future<void> write(AppSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, session.toJsonString());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    return raw != null && raw.trim().isNotEmpty;
  }
}
