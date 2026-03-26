import 'package:flutter/material.dart';

import '../models/session.dart';
import '../stores/session_store.dart';
import 'access_denied_page.dart';

/// 🔒 PermissionGate (verrouillé)
/// Source de vérité: SessionStore (pas Provider)
///
/// Règles simples (cohérentes + évolutives):
/// - SUPER ADMIN : tout autorisé
/// - ADMIN / PASTEUR : tout autorisé pour l’instant (étape suivante = permissions par rôle)
/// - Autres rôles : autorisé seulement si permission dans la matrice minimale ci-dessous
class PermissionGate extends StatefulWidget {
  final String permission;
  final Widget child;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  AppSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await const SessionStore().read();
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _loading = false;
      });
    }
  }

  bool _allowed(AppSession s, String perm) {
    // 🔒 SUPER ADMIN = tout
    if (s.role.toJson() == 'superAdmin') return true;

    // 🔒 ADMIN + PASTEUR = tout (pour l’instant, étape suivante: matrice DB)
    if (s.role.toJson() == 'admin' || s.role.toJson() == 'pasteur') return true;

    // Matrice minimale (protocole/membre) — évolutif
    const protoAllowed = <String>{
      'mark_presence',
      'view_members',
      'view_presence_history',
    };

    const membreAllowed = <String>{
      'view_members',
      'view_presence_history',
      'view_reports',
    };

    final r = s.role.toJson();
    if (r == 'protocole') return protoAllowed.contains(perm);
    if (r == 'membre') return membreAllowed.contains(perm);

    // Par défaut on refuse (sécurité)
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _session;
    if (s == null) {
      return const AccessDeniedPage(message: 'Session introuvable.');
    }

    final ok = _allowed(s, widget.permission);
    if (!ok) {
      return const AccessDeniedPage(message: 'Accès refusé (permission).');
    }

    return widget.child;
  }
}
