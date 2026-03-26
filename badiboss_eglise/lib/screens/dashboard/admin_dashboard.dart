import 'package:flutter/material.dart';

// 🔒 Verrouillage permissions (menus)
import '../../auth/ui/permission_gate.dart';
import '../../auth/permissions.dart';
import '../../core/logout_helper.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Tableau de bord'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HeroBlock(
            title: 'Pilotage administration',
            subtitle: 'Membres, validations, rôles, présences, rapports et exports.',
          ),
          SizedBox(height: 16),

          // ✅ Gestion Accès (Admin) - contrôle Permission
          PermissionGate(
            permission: Permissions.manageAccess,
            child: _MenuTile(
              title: 'Gestion des accès',
              subtitle: 'Activer / suspendre / bannir / permissions',
              icon: Icons.lock_open,
              routeName: '/admin/access',
            ),
          ),

          // ✅ Gestion Rôles - contrôle Permission
          PermissionGate(
            permission: Permissions.manageRoles,
            child: _MenuTile(
              title: 'Gestion des rôles',
              subtitle: 'Créer des rôles personnalisés + permissions',
              icon: Icons.badge,
              routeName: '/admin/roles',
            ),
          ),

          // ✅ Membres - consulter
          PermissionGate(
            permission: Permissions.viewMembers,
            child: _MenuTile(
              title: 'Membres',
              subtitle: 'Liste / Recherche / Détails',
              icon: Icons.people,
              routeName: '/members',
            ),
          ),

          // ✅ Membres - modifier
          PermissionGate(
            permission: Permissions.editMembers,
            child: _MenuTile(
              title: 'Modifier membres',
              subtitle: 'Éditer profil / statut / rôle / fonctions',
              icon: Icons.edit,
              routeName: '/members/edit',
            ),
          ),

          // ✅ Activités & présences
          PermissionGate(
            permission: Permissions.launchActivity,
            child: _MenuTile(
              title: 'Lancer activité / culte',
              subtitle: 'Créer une activité pour la présence',
              icon: Icons.event_available,
              routeName: '/activities',
            ),
          ),

          PermissionGate(
            permission: Permissions.markPresence,
            child: _MenuTile(
              title: 'Pointer présence',
              subtitle: 'Scanner / marquer la présence',
              icon: Icons.qr_code_scanner,
              routeName: '/presence/mark',
            ),
          ),

          PermissionGate(
            permission: Permissions.viewPresenceHistory,
            child: _MenuTile(
              title: 'Historique présences',
              subtitle: 'Consulter les présences passées',
              icon: Icons.history,
              routeName: '/presence/history',
            ),
          ),

          PermissionGate(
            permission: Permissions.exportPresence,
            child: _MenuTile(
              title: 'Exporter présences',
              subtitle: 'Export CSV téléchargeable',
              icon: Icons.download,
              routeName: '/presence/export',
            ),
          ),

          // ✅ Rapports
          PermissionGate(
            permission: Permissions.viewReports,
            child: _MenuTile(
              title: 'Rapports',
              subtitle: 'Statistiques & rapports imprimables',
              icon: Icons.analytics,
              routeName: '/reports',
            ),
          ),

          PermissionGate(
            permission: Permissions.exportReports,
            child: _MenuTile(
              title: 'Exporter rapports',
              subtitle: 'Rapport global + template import',
              icon: Icons.picture_as_pdf,
              routeName: '/reports/export',
            ),
          ),
          PermissionGate(
            permission: Permissions.viewFinance,
            child: _MenuTile(
              title: 'Finance',
              subtitle: 'Entrées/sorties, source, export',
              icon: Icons.account_balance_wallet,
              routeName: '/finance',
            ),
          ),
        ],
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

// Petit composant UI interne (verrouillé dans ce fichier)
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