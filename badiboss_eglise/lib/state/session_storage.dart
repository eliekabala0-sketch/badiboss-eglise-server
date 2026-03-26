import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _kToken = "bb_token";

  static Future<void> setToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  static Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
  }

  // compat (certains fichiers appellent save/load)
  static Future<void> save(String token) async => setToken(token);
  static Future<String?> load() async => getToken();
}
