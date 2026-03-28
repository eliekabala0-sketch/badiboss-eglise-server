import '../models/role_policy.dart';
import '../../services/church_api.dart';

final class RolePolicyStore {
  static String _key = '';
  static RolePolicy? _mem;

  static String _keyFor(String churchCode) => churchCode.trim();

  static Future<RolePolicy> read(String churchCode) async {
    final k = _keyFor(churchCode);
    if (_mem != null && _key == k) return _mem!;
    try {
      final dec = await ChurchApi.getJson('/church/role_policy');
      final pol = dec['policy'];
      if (pol is! Map || pol.isEmpty) {
        _mem = RolePolicy.empty();
      } else {
        _mem = RolePolicy.fromMap(Map<String, dynamic>.from(pol));
      }
      _key = k;
      return _mem!;
    } catch (_) {
      _mem = RolePolicy.empty();
      _key = k;
      return _mem!;
    }
  }

  static Future<void> write(String churchCode, RolePolicy policy) async {
    await ChurchApi.postJson('/church/role_policy', {'payload': policy.toMap()});
    _mem = policy;
    _key = _keyFor(churchCode);
  }

  static void invalidate() {
    _mem = null;
    _key = '';
  }
}
