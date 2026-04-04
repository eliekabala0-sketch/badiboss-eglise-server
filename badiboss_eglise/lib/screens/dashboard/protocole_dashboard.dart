import 'package:flutter/material.dart';

// 🔒 Verrouillage permissions
import '../../auth/ui/permission_gate.dart';
import '../../auth/permissions.dart';
import '../../core/logout_helper.dart';
import '../../services/session_refresh.dart';
import '../../widgets/global_broadcasts_bootstrap.dart';

class ProtocoleDashboard extends StatelessWidget {
  const ProtocoleDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalBroadcastsBootstrap(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Protocole — Tableau de bord'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => SessionRefresh.bump(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => LogoutHelper.logoutNow(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Dashboard Protocole',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16),

          // ✅ Pointer présence (autorisé typiquement au protocole)
          PermissionGate(
            permission: Permissions.markPresence,
            child: _MenuTile(
              title: 'Pointer présence',
              subtitle: 'Scanner / marquer présence des membres',
              icon: Icons.qr_code_scanner,
              routeName: '/presence/mark',
            ),
          ),

          // ✅ Voir membres (lecture seule)
          PermissionGate(
            permission: Permissions.viewMembers,
            child: _MenuTile(
              title: 'Liste des membres',
              subtitle: 'Consulter les membres',
              icon: Icons.people,
              routeName: '/members',
            ),
          ),

          // ✅ Historique présences
          PermissionGate(
            permission: Permissions.viewPresenceHistory,
            child: _MenuTile(
              title: 'Historique présences',
              subtitle: 'Voir les présences enregistrées',
              icon: Icons.history,
              routeName: '/presence/history',
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// 🔒 Composant interne verrouillé
class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(routeName),
      ),
    );
  }
}