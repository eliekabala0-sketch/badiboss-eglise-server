import 'package:flutter/material.dart';

// 🔒 Verrouillage permissions
import '../../auth/ui/permission_gate.dart';
import '../../auth/permissions.dart';

final class TabPresence extends StatelessWidget {
  const TabPresence({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Présences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Module Présences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),

          PermissionGate(
            permission: Permissions.launchActivity,
            child: _MenuTile(
              title: 'Lancer une activité / culte',
              subtitle: 'Créer une activité OPEN pour la présence',
              icon: Icons.event_available,
              routeName: '/activities',
            ),
          ),

          PermissionGate(
            permission: Permissions.markPresence,
            child: _MenuTile(
              title: 'Pointer présence',
              subtitle: 'Scanner / marquer la présence des membres',
              icon: Icons.qr_code_scanner,
              routeName: '/presence/mark',
            ),
          ),

          PermissionGate(
            permission: Permissions.viewPresenceHistory,
            child: _MenuTile(
              title: 'Historique présences',
              subtitle: 'Consulter les présences enregistrées',
              icon: Icons.history,
              routeName: '/presence/history',
            ),
          ),

          PermissionGate(
            permission: Permissions.exportPresence,
            child: _MenuTile(
              title: 'Exporter présences',
              subtitle: 'PDF / Excel / impression',
              icon: Icons.download,
              routeName: '/presence/export',
            ),
          ),
        ],
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
