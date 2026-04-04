import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/models/user_role.dart';
import '../auth/stores/session_store.dart';
import '../core/config.dart';
import 'church_service.dart';

final class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException([this.message = 'Session expirée']);

  @override
  String toString() => message;
}

/// Appels HTTP authentifiés vers `server_multichurch.py` (hors login public).
final class ChurchApi {
  const ChurchApi._();

  static Future<String?> readToken() async {
    final s = await const SessionStore().read();
    return (s?.token ?? '').trim();
  }

  static Future<String> _token() async {
    final t = (await readToken()) ?? '';
    if (t.isEmpty) throw const SessionExpiredException('Session invalide: token manquant');
    return t;
  }

  static Map<String, String> _headers(String token) => {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Super admin : église « visitée » (ChurchService) pour le ciblage API (ex. /me/broadcasts).
  static Future<Map<String, String>> _scopedHeaders(String token) async {
    final h = _headers(token);
    try {
      final s = await const SessionStore().read();
      if (s != null && s.role == UserRole.superAdmin) {
        final cc = ChurchService.getChurchCode().trim();
        if (cc.isNotEmpty) {
          h['X-Badiboss-Active-Church'] = cc.toUpperCase();
        }
      }
    } catch (_) {}
    return h;
  }

  static Future<Map<String, String>> _jsonScopedHeaders(String token) async => {
        ...(await _scopedHeaders(token)),
        'Content-Type': 'application/json',
      };

  static Map<String, dynamic> _decodeMap(http.Response res) {
    final text = res.bodyBytes.isEmpty ? '{}' : utf8.decode(res.bodyBytes);
    final dec = jsonDecode(text);
    if (dec is! Map) throw StateError('Réponse JSON invalide');
    return Map<String, dynamic>.from(dec);
  }

  static void _ok(http.Response res, Map<String, dynamic> dec) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    if (res.statusCode == 401) {
      // Session serveur expirée/invalide: purge locale immédiate pour éviter boucles 401.
      const SessionStore().clear();
      throw const SessionExpiredException('Session expirée (401)');
    }
    throw StateError((dec['detail'] ?? dec['message'] ?? res.body).toString());
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final t = await _token();
    final uri = Uri.parse('${Config.baseUrl}$path');
    final res = await http.get(uri, headers: await _scopedHeaders(t)).timeout(Duration(seconds: Config.timeoutSeconds));
    final dec = _decodeMap(res);
    _ok(res, dec);
    return dec;
  }

  static Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final t = await _token();
    final uri = Uri.parse('${Config.baseUrl}$path');
    final res = await http
        .post(uri, headers: await _jsonScopedHeaders(t), body: jsonEncode(body))
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final dec = _decodeMap(res);
    _ok(res, dec);
    return dec;
  }

  /// Sans jeton (login public, listes publiques).
  static Future<Map<String, dynamic>> getPublicJson(String path) async {
    final uri = Uri.parse('${Config.baseUrl}$path');
    final res = await http
        .get(uri, headers: {'accept': 'application/json'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final dec = _decodeMap(res);
    _ok(res, dec);
    return dec;
  }

  static Future<Map<String, dynamic>> postPublicJson(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${Config.baseUrl}$path');
    final res = await http
        .post(
          uri,
          headers: {'accept': 'application/json', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final dec = _decodeMap(res);
    _ok(res, dec);
    return dec;
  }
}
