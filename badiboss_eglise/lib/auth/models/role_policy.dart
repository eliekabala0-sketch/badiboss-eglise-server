import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
final class RolePolicy {
  /// roleName -> permissions
  final Map<String, Set<String>> rolePermissions;

  const RolePolicy({required this.rolePermissions});

  static RolePolicy empty() => const RolePolicy(rolePermissions: <String, Set<String>>{});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rolePermissions': rolePermissions.map((k, v) => MapEntry(k, v.toList())),
    };
  }

  String toJsonString() => jsonEncode(toMap());

  static RolePolicy fromMap(Map<String, dynamic> m) {
    final rpRaw = m['rolePermissions'];
    final out = <String, Set<String>>{};

    if (rpRaw is Map) {
      final map = Map<String, dynamic>.from(rpRaw);
      for (final e in map.entries) {
        final roleName = e.key.toString().trim();
        if (roleName.isEmpty) continue;

        final val = e.value;
        if (val is List) {
          out[roleName] =
              val.map((x) => x.toString().trim()).where((x) => x.isNotEmpty).toSet();
        }
      }
    }

    return RolePolicy(rolePermissions: out);
  }

  static RolePolicy fromJsonString(String s) {
    final decoded = jsonDecode(s);
    if (decoded is! Map) {
      throw StateError('RolePolicy invalide: JSON non-map');
    }
    return fromMap(Map<String, dynamic>.from(decoded));
  }

  RolePolicy upsertRole(String roleName, Set<String> permissions) {
    final rn = roleName.trim();
    final next = Map<String, Set<String>>.from(rolePermissions);
    next[rn] = Set<String>.from(permissions);
    return RolePolicy(rolePermissions: next);
  }

  RolePolicy removeRole(String roleName) {
    final rn = roleName.trim();
    final next = Map<String, Set<String>>.from(rolePermissions);
    next.remove(rn);
    return RolePolicy(rolePermissions: next);
  }

  Set<String> permissionsOf(String roleName) {
    final rn = roleName.trim();
    return rolePermissions[rn] ?? <String>{};
  }
}
