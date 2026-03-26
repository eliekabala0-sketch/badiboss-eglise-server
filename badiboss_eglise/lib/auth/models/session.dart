import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'user_role.dart';

@immutable
final class AppSession {
  /// VERROUILLÉ :
  /// - SUPER ADMIN => churchCode == null
  /// - Autres rôles => churchCode obligatoire
  ///
  /// ÉVOLUTIF :
  /// - role = rôle système (superAdmin/pasteur/admin/membre)
  /// - roleName = nom réel du rôle (peut être personnalisé)
  ///
  /// API:
  /// - token = Bearer token (optionnel, backward-compatible)
  final String phone;
  final UserRole role;
  final String roleName;
  final String? churchCode;
  final String token;
  final int createdAtEpochMs;

  const AppSession({
    required this.phone,
    required this.role,
    required this.roleName,
    required this.createdAtEpochMs,
    required this.churchCode,
    required this.token,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'phone': phone,
        'role': role.toJson(),
        'roleName': roleName,
        'churchCode': churchCode,
        'token': token,
        'createdAtEpochMs': createdAtEpochMs,
      };

  String toJsonString() => jsonEncode(toMap());

  static AppSession fromMap(Map<String, dynamic> m) {
    final phone = (m['phone'] ?? '').toString();
    final roleRaw = (m['role'] ?? '').toString();
    final role = UserRole.safeFromString(roleRaw);

    // Backward compatible: si roleName absent => role.toJson()
    final roleNameRaw = (m['roleName'] ?? '').toString().trim();
    final roleName = roleNameRaw.isEmpty ? role.toJson() : roleNameRaw;

    final churchCode = m['churchCode']?.toString();
    final token = (m['token'] ?? '').toString();
    final createdAt = int.tryParse((m['createdAtEpochMs'] ?? '').toString());

    if (phone.trim().isEmpty) throw StateError('Session invalide: phone vide');
    if (createdAt == null) throw StateError('Session invalide: createdAt manquant');

    if (role == UserRole.superAdmin) {
      if (churchCode != null && churchCode.trim().isNotEmpty) {
        throw StateError('Session invalide: SUPER ADMIN ne doit pas avoir churchCode');
      }
    } else {
      if (churchCode == null || churchCode.trim().isEmpty) {
        throw StateError('Session invalide: churchCode obligatoire pour $role');
      }
    }

    return AppSession(
      phone: phone.trim(),
      role: role,
      roleName: roleName,
      churchCode: (churchCode == null || churchCode.trim().isEmpty) ? null : churchCode.trim(),
      token: token.trim(),
      createdAtEpochMs: createdAt,
    );
  }

  static AppSession fromJsonString(String s) {
    final dynamic decoded = jsonDecode(s);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Session invalide: JSON non-map');
    }
    return fromMap(decoded);
  }
}
