import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/stores/session_store.dart';
import '../core/config.dart';

/// Appels HTTP authentifiés vers `server_multichurch.py` (hors login public).
final class ChurchApi {
  const ChurchApi._();

  static Future<String> _token() async {
    final s = await const SessionStore().read();
    final t = (s?.token ?? '').trim();
    if (t.isEmpty) throw StateError('token manquant');
    return t;
  }

  static Map<String, String> _headers(String token) => {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, String> _jsonHeaders(String token) => {
        ..._headers(token),
        'Content-Type': 'application/json',
      };

  static Map<String, dynamic> _decodeMap(http.Response res) {
    final dec = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (dec is! Map) throw StateError('Réponse JSON invalide');
    return Map<String, dynamic>.from(dec);
  }

  static void _ok(http.Response res, Map<String, dynamic> dec) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw StateError((dec['detail'] ?? dec['message'] ?? res.body).toString());
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final t = await _token();
    final uri = Uri.parse('${Config.baseUrl}$path');
    final res = await http.get(uri, headers: _headers(t)).timeout(Duration(seconds: Config.timeoutSeconds));
    final dec = _decodeMap(res);
    _ok(res, dec);
    return dec;
  }

  static Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final t = await _token();
    final uri = Uri.parse('${Config.baseUrl}$path');
    final res = await http
        .post(uri, headers: _jsonHeaders(t), body: jsonEncode(body))
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
