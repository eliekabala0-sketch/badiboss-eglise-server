import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_account.dart';

final class LocalAuthAccountsStore {
  static const String _kPrefix = 'auth_accounts_'; // auth_accounts_<churchCode>

  static String _safe(String? s) => (s ?? '').trim();
  static String _key(String churchCode) => '$_kPrefix${_safe(churchCode)}';

  static String newId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return 'acc_$ms';
  }

  static Future<List<AuthAccount>> loadByChurch(String churchCode) async {
    final cc = _safe(churchCode);
    if (cc.isEmpty) return <AuthAccount>[];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cc));
    if (raw == null || raw.trim().isEmpty) return <AuthAccount>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AuthAccount>[];
      return decoded
          .whereType<Map>()
          .map((e) => AuthAccount.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <AuthAccount>[];
    }
  }

  static Future<void> upsert(AuthAccount acc) async {
    final cc = _safe(acc.churchCode);
    if (cc.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = await loadByChurch(cc);

    final idx = list.indexWhere((x) => _safe(x.id) == _safe(acc.id));
    final next = List<AuthAccount>.from(list);

    if (idx >= 0) {
      next[idx] = acc;
    } else {
      next.add(acc);
    }

    final maps = next.map((e) => e.toMap()).toList();
    await prefs.setString(_key(cc), jsonEncode(maps));
  }

  static Future<void> removeById(String churchCode, String id) async {
    final cc = _safe(churchCode);
    if (cc.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = await loadByChurch(cc);
    final next = list.where((x) => _safe(x.id) != _safe(id)).toList();

    final maps = next.map((e) => e.toMap()).toList();
    await prefs.setString(_key(cc), jsonEncode(maps));
  }
}