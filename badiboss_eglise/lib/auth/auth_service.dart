import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import 'models/session.dart';
import 'models/user_role.dart';
import 'stores/session_store.dart';
import '../api_client.dart';

final class AuthService {
  const AuthService();

  /// LOGIN API (backend: server_multichurch.py)
  Future<AuthResult> login({
    required String churchCode,
    required String phone,
    required String password,
  }) async {
    try {
      final api = ApiClient();

      final loginRes = await api.post(
        '/login',
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'church_code': churchCode.trim(),
          'phone': phone.trim(),
          'password': password,
        }),
      );

      if (loginRes['ok'] != true) {
        final msg = (loginRes['detail'] ?? loginRes['message'] ?? 'Connexion échouée.').toString();
        return AuthFailure(msg);
      }

      final token = (loginRes['token'] ?? '').toString().trim();
      if (token.isEmpty) return const AuthFailure('Token manquant.');
      final int? churchId = _asInt(loginRes['church_id']);
      final userFromLogin = (loginRes['user'] is Map)
          ? Map<String, dynamic>.from(loginRes['user'] as Map)
          : <String, dynamic>{};

      // Vérifie/charge profil via /me/profile (exigé)
      final me = await _getMeProfile(token);
      final userFromMe = (me['user'] is Map) ? Map<String, dynamic>.from(me['user'] as Map) : <String, dynamic>{};
      final user = userFromLogin.isNotEmpty ? userFromLogin : userFromMe;

      final roleBackend = (loginRes['role'] ?? user['role'] ?? '').toString();
      final roleName = _mapBackendRoleToRoleName(roleBackend);
      final role = UserRole.safeFromString(roleName);
      final isSuperAdmin = role == UserRole.superAdmin;
      if (!isSuperAdmin && churchId == null) {
        return const AuthFailure('church_id manquant dans la réponse login.');
      }

      final session = AppSession(
        phone: (user['phone'] ?? phone).toString(),
        role: role,
        roleName: roleName,
        churchCode: isSuperAdmin ? null : churchCode.trim(),
        token: token,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

      await const SessionStore().write(session);
      return AuthSuccess(session);
    } catch (e) {
      return AuthFailure(e.toString());
    }
  }

  Future<void> logout() => const SessionStore().clear();

  static String _mapBackendRoleToRoleName(String raw) {
    final r = raw.trim().toUpperCase();
    final norm = r.replaceAll('-', '_').replaceAll(' ', '_');
    switch (norm) {
      case 'SUPER_ADMIN':
        return 'super_admin';
      case 'PASTEUR_RESPONSABLE':
        return 'pasteur';
      case 'PROTOCOLE':
        return 'protocole';
      case 'FINANCE':
        return 'finance';
      case 'SECRETAIRE':
        return 'admin';
      case 'MEMBRE':
        return 'membre';
      default:
        // fallback: keep something stable for router
        return 'membre';
    }
  }

  Future<Map<String, dynamic>> _getMeProfile(String token) async {
    final uri = Uri.parse('${Config.baseUrl}/me/profile');
    final res = await http
        .get(
          uri,
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Réponse API invalide');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;

    final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString();
    throw Exception('HTTP ${res.statusCode}: $detail');
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString().trim());
  }
}

/// 🔒 RESULT TYPES

sealed class AuthResult {
  const AuthResult();
}

final class AuthSuccess extends AuthResult {
  final AppSession session;
  const AuthSuccess(this.session);
}

final class AuthFailure extends AuthResult {
  final String message;
  const AuthFailure(this.message);
}