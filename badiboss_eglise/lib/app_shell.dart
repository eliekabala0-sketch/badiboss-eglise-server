import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

class AppShell extends StatefulWidget {
  final String phone;
  final String role;
  final String churchCode;

  const AppShell({
    super.key,
    required this.phone,
    required this.role,
    required this.churchCode,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        phone: widget.phone,
        role: widget.role,
        churchCode: widget.churchCode,
      ),
      const MembersPage(),
      const DonationsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Badiboss Église"),
        actions: [
          IconButton(
            tooltip: "Déconnexion",
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: "Accueil",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt),
            label: "Membres",
          ),
          NavigationDestination(
            icon: Icon(Icons.volunteer_activism),
            label: "Dons",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: "Réglages",
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final String phone;
  final String role;
  final String churchCode;

  const DashboardPage({
    super.key,
    required this.phone,
    required this.role,
    required this.churchCode,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          role == "super_admin"
              ? "Super Admin Dashboard"
              : role == "admin"
                  ? "Admin Dashboard"
                  : "Espace Membre",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Téléphone : $phone"),
                const SizedBox(height: 6),
                Text("Rôle : $role"),
                const SizedBox(height: 6),
                Text("Code Église : $churchCode"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Bienvenue dans Badiboss Église",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  "Tu as maintenant une base solide (Accueil, Membres, Dons, Réglages). "
                  "On va remplir chaque onglet avec le vrai contenu ensuite.",
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _QuickTile(icon: Icons.qr_code_2, title: "Cartes Membres"),
            _QuickTile(icon: Icons.check_circle, title: "Présences"),
            _QuickTile(icon: Icons.attach_money, title: "Finances"),
            _QuickTile(icon: Icons.campaign, title: "Annonces"),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;

  const _QuickTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Membres (à remplir)",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class DonationsPage extends StatelessWidget {
  const DonationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Dons (à remplir)",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Réglages (à remplir)",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}
