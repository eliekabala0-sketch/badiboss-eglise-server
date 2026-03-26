import 'package:flutter/material.dart';

import '../screens/dashboard/admin_dashboard.dart';
import '../screens/dashboard/membre_dashboard.dart';
import '../screens/dashboard/pasteur_dashboard.dart';
import '../screens/dashboard/protocole_dashboard.dart';
import '../screens/dashboard/super_admin_dashboard.dart';

class RoleRouter {
  /// Retourne le bon dashboard selon le role
  static Widget dashboardForRole(String? role) {
    final r = (role ?? '').toLowerCase().trim();
    final normalized = r.replaceAll('_', ' ').replaceAll('-', ' ');
    final isSuperAdmin = normalized == 'super admin' ||
        normalized == 'superadmin' ||
        normalized == 'super administrateur' ||
        normalized == 'super administrator' ||
        (normalized.contains('super') && normalized.contains('admin'));

    if (isSuperAdmin) {
      return const SuperAdminDashboard();
    }

    switch (r) {

      case 'admin':
        return const AdminDashboard();

      case 'pasteur':
      case 'pastor':
        return const PasteurDashboard();

      case 'protocole':
        return const ProtocoleDashboard();
      case 'finance':
      case 'financier':
        return const AdminDashboard();

      case 'member':
      case 'membre':
      default:
        return const MembreDashboard();
    }
  }
}