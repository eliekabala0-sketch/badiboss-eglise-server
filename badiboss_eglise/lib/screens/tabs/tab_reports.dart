import 'package:flutter/material.dart';

import '../../auth/ui/permission_gate.dart';
import '../../auth/permissions.dart';
import '../../reports/ui/reports_page.dart';
import '../../reports/ui/reports_export_page.dart';

class TabReports extends StatelessWidget {
  const TabReports({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            'Module Rapports',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16),

          PermissionGate(
            permission: Permissions.viewReports,
            child: _MenuTile(
              title: 'Voir rapports',
              subtitle: 'Statistiques & rapports imprimables',
              icon: Icons.analytics,
              routeName: ReportsPage.routeName,
            ),
          ),

          PermissionGate(
            permission: Permissions.exportReports,
            child: _MenuTile(
              title: 'Exporter rapports',
              subtitle: 'PDF / impression / export',
              icon: Icons.picture_as_pdf,
              routeName: ReportsExportPage.routeName,
            ),
          ),
        ],
      ),
    );
  }
}

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
