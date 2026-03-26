import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/config.dart';

class ApiClient {
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse("${Config.baseUrl}$path")
        .replace(queryParameters: query);

    final res = await http
        .post(
          uri,
          headers: {
            "accept": "application/json",
            if (headers != null) ...headers,
          },
          body: body,
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? "{}" : res.body;
    final decoded = jsonDecode(text);

    if (decoded is Map<String, dynamic>) return decoded;
    return {"success": false, "message": "Réponse API invalide"};
  }
}
