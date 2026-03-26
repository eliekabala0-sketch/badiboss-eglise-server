import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_account.dart';

final class AuthAccountsStore {
  /// auth_accounts_<churchCode> => List<Map>
  static String _key(String churchCode) => 'auth_accounts_${churchCode.trim()}';

  static String _safe(String? s) => (s ?? '').trim();

  static Future<List<Map<String, dynamic>>> _readMaps(SharedPreferences prefs, String churchCode) async {
    final raw = prefs.getString(_key(churchCode));
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> _writeMaps(SharedPreferences prefs, String churchCode, List<Map<String, dynamic>> list) async {
    await prefs.setString(_key(churchCode), jsonEncode(list));
  }

  /// Retourne null si aucun compte d’accès n’est enregistré.
  static Future<AuthAccount?> findByPhone({
    required String churchCode,
    required String phone,
  }) async {
    final cc = _safe(churchCode);
    final ph = _safe(phone);
    if (cc.isEmpty || ph.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);

    final idx = maps.indexWhere((x) => _safe(x['phone']?.toString()) == ph);
    if (idx < 0) return null;

    try {
      return AuthAccount.fromMap(maps[idx]);
    } catch (_) {
      return null;
    }
  }

  /// Crée ou met à jour un compte d’accès (pour admin/pasteur/membre).
  static Future<void> upsert(AuthAccount account) async {
    final cc = _safe(account.churchCode);
    final ph = _safe(account.phone);
    if (cc.isEmpty || ph.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);

    final map = account.toMap();
    final idx = maps.indexWhere((x) => _safe(x['phone']?.toString()) == ph);
    if (idx >= 0) {
      maps[idx] = map;
    } else {
      maps.add(map);
    }

    await _writeMaps(prefs, cc, maps);
  }

  static Future<void> removeByPhone({
    required String churchCode,
    required String phone,
  }) async {
    final cc = _safe(churchCode);
    final ph = _safe(phone);
    if (cc.isEmpty || ph.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);
    maps.removeWhere((x) => _safe(x['phone']?.toString()) == ph);
    await _writeMaps(prefs, cc, maps);
  }
}
