import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config.dart';

class ApiService {
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    // Ton OpenAPI montre: POST /api/eglise/login avec phone/password en QUERY
    final uri = Uri.parse("${Config.baseUrl}/api/eglise/login").replace(
      queryParameters: {
        "phone": phone,
        "password": password,
      },
    );

    final r = await http.post(
      uri,
      headers: {"accept": "application/json"},
    );

    // Toujours renvoyer un Map propre
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final body = r.body.isEmpty ? "{}" : r.body;
      return jsonDecode(body) as Map<String, dynamic>;
    }

    // Erreur API
    try {
      final body = r.body.isEmpty ? "{}" : r.body;
      final parsed = jsonDecode(body);
      return {
        "success": false,
        "message": parsed is Map && parsed["detail"] != null
            ? parsed["detail"].toString()
            : "Erreur API (${r.statusCode})",
      };
    } catch (_) {
      return {
        "success": false,
        "message": "Erreur API (${r.statusCode})",
      };
    }
  }
}
