import 'package:shared_preferences/shared_preferences.dart';

import '../models/role_policy.dart';

final class RolePolicyStore {
  static String _safe(String? s) => (s ?? '').trim();
  static String _key(String churchCode) => 'role_policy_${churchCode.trim()}';

  static Future<RolePolicy> read(String churchCode) async {
    final cc = _safe(churchCode);
    if (cc.isEmpty) return RolePolicy.empty();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(cc));
    if (raw == null || raw.trim().isEmpty) return RolePolicy.empty();

    try {
      return RolePolicy.fromJsonString(raw);
    } catch (_) {
      // VERROUILLÉ: policy corrompue => purge propre (pas de crash)
      await prefs.remove(_key(cc));
      return RolePolicy.empty();
    }
  }

  static Future<void> write(String churchCode, RolePolicy policy) async {
    final cc = _safe(churchCode);
    if (cc.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(cc), policy.toJsonString());
  }
}
