import 'package:flutter/material.dart';

// 🔒 Verrouillage permissions
import '../../auth/ui/permission_gate.dart';
import '../../auth/permissions.dart';
import '../../core/logout_helper.dart';
import '../member_neighbors_screen.dart';
import '../member_history_page.dart';
import '../tabs/tab_profile.dart';

class MembreDashboard extends StatelessWidget {
  const MembreDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membre — Tableau de bord'),
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
        children: [
          const _HeroBlock(
            title: 'Mon espace membre',
            subtitle: 'Historique, voisins, annonces, finances personnelles et profil.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Mes voisins / communauté locale'),
              subtitle: const Text('Voir les membres proches (zone/quartier)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemberNeighborsScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: const Text('Mon historique personnel'),
              subtitle: const Text('Présences, événements et suivis enregistrés'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemberHistoryPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Mon profil'),
              subtitle: const Text('Informations personnelles et déconnexion'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TabProfile()),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ✅ Lecture seule: membres (selon permission)
          PermissionGate(
            permission: Permissions.viewMembers,
            child: _MenuTile(
              title: 'Membres (lecture)',
              subtitle: 'Consulter la liste des membres',
              icon: Icons.people,
              routeName: '/members',
            ),
          ),

          // ✅ Historique présences (si autorisé)
          PermissionGate(
            permission: Permissions.viewPresenceHistory,
            child: _MenuTile(
              title: 'Mes présences / Historique',
              subtitle: 'Voir les présences enregistrées',
              icon: Icons.history,
              routeName: '/presence/history',
            ),
          ),

          // ✅ Rapports (si l’église veut autoriser certains membres)
          PermissionGate(
            permission: Permissions.viewReports,
            child: _MenuTile(
              title: 'Rapports',
              subtitle: 'Consulter les statistiques disponibles',
              icon: Icons.analytics,
              routeName: '/reports',
            ),
          ),
          PermissionGate(
            permission: Permissions.viewAnnouncements,
            child: _MenuTile(
              title: 'Annonces',
              subtitle: 'Informations de l’église',
              icon: Icons.campaign_outlined,
              routeName: '/announcements',
            ),
          ),
          PermissionGate(
            permission: Permissions.viewFinance,
            child: _MenuTile(
              title: 'Mes dîmes / actions de grâce',
              subtitle: 'Historique financier lié au membre',
              icon: Icons.volunteer_activism,
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