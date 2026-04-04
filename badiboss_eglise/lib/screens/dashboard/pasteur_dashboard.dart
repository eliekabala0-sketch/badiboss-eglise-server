import 'package:flutter/material.dart';

// 🔒 Verrouillage permissions
import '../../auth/ui/permission_gate.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../core/logout_helper.dart';
import '../../services/session_refresh.dart';
import '../../widgets/global_broadcasts_bootstrap.dart';
import '../pages/relations_page.dart';
import '../pages/pasteur_irregulars_page.dart';

class PasteurDashboard extends StatelessWidget {
  const PasteurDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalBroadcastsBootstrap(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Pasteur — Tableau de bord'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => SessionRefresh.bump(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HeroBlock(
            title: 'Pilotage pastoral',
            subtitle: 'Suivi des membres, accompagnement relationnel et irréguliers.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('Relations pastorales'),
              subtitle: const Text('Fréquentation, accompagnement, fiançailles, mariage'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RelationsPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.volunteer_activism_rounded),
              title: const Text('Irréguliers & bergers'),
              subtitle: const Text('Assignation, suivi, réconfort, statuts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final s = await const SessionStore().read();
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PasteurIrregularsPage(
                      codeEglise: (s?.churchCode ?? 'EGLISE001').trim(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ✅ Gestion Accès
          PermissionGate(
            permission: Permissions.manageAccess,
            child: _MenuTile(
              title: 'Gestion des accès',
              subtitle: 'Valider / suspendre / bannir membres',
              icon: Icons.lock_open,
              routeName: '/admin/access',
            ),
          ),

          // ✅ Gestion Rôles
          PermissionGate(
            permission: Permissions.manageRoles,
            child: _MenuTile(
              title: 'Gestion des rôles',
              subtitle: 'Créer et modifier les rôles personnalisés',
              icon: Icons.badge,
              routeName: '/admin/roles',
            ),
          ),

          // ✅ Membres
          PermissionGate(
            permission: Permissions.viewMembers,
            child: _MenuTile(
              title: 'Membres',
              subtitle: 'Liste complète des membres',
              icon: Icons.people,
              routeName: '/members',
            ),
          ),

          PermissionGate(
            permission: Permissions.editMembers,
            child: _MenuTile(
              title: 'Modifier membres',
              subtitle: 'Modifier profil / rôle / statut',
              icon: Icons.edit,
              routeName: '/members/edit',
            ),
          ),

          // ✅ Activités
          PermissionGate(
            permission: Permissions.launchActivity,
            child: _MenuTile(
              title: 'Lancer activité / culte',
              subtitle: 'Créer une nouvelle activité',
              icon: Icons.event_available,
              routeName: '/activities',
            ),
          ),

          PermissionGate(
            permission: Permissions.markPresence,
            child: _MenuTile(
              title: 'Pointer présence',
              subtitle: 'Scanner / marquer présence',
              icon: Icons.qr_code_scanner,
              routeName: '/presence/mark',
            ),
          ),

          PermissionGate(
            permission: Permissions.viewPresenceHistory,
            child: _MenuTile(
              title: 'Historique présences',
              subtitle: 'Consulter les présences',
              icon: Icons.history,
              routeName: '/presence/history',
            ),
          ),

          PermissionGate(
            permission: Permissions.exportPresence,
            child: _MenuTile(
              title: 'Exporter présences',
              subtitle: 'Exporter PDF / Excel',
              icon: Icons.download,
              routeName: '/presence/export',
            ),
          ),

          // ✅ Rapports
          PermissionGate(
            permission: Permissions.viewReports,
            child: _MenuTile(
              title: 'Rapports',
              subtitle: 'Statistiques et rapports',
              icon: Icons.analytics,
              routeName: '/reports',
            ),
          ),

          PermissionGate(
            permission: Permissions.exportReports,
            child: _MenuTile(
              title: 'Exporter rapports',
              subtitle: 'PDF / impression',
              icon: Icons.picture_as_pdf,
              routeName: '/reports/export',
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await LogoutHelper.logoutNow(context);
  }
}

class _HeroBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeroBlock({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle),
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