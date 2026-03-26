import 'package:flutter/material.dart';

import '../models/session.dart';
import '../ui/access_denied_page.dart';

/// 🔒 VERROUILLÉ : Guard global
/// - si session == null => accès refusé
/// - sinon on laisse passer
/// (les permissions fines sont gérées par PermissionGate / AccessControl)
final class RouteGuard {
  static Route<dynamic> guard({
    required AppSession? session,
    required String routeName,
    required Route<dynamic> route,
  }) {
    if (session == null) {
      return MaterialPageRoute(
        settings: RouteSettings(name: '/access-denied?from=$routeName'),
        builder: (_) => const AccessDeniedPage(),
      );
    }
    return route;
  }
}