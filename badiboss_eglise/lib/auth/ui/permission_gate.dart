import 'package:flutter/material.dart';

import '../models/session.dart';
import '../stores/session_store.dart';
import '../access_control.dart';
import 'access_denied_page.dart';

/// Source de vérité des droits: [AccessControl] (alignée sur le backend terrain).
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _session;
    if (s == null) {
      return const AccessDeniedPage(message: 'Session introuvable.');
    }

    return FutureBuilder<bool>(
      future: AccessControl.has(s, widget.permission),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data != true) {
          return const AccessDeniedPage(message: 'Accès refusé (permission).');
        }
        return widget.child;
      },
    );
  }
}
