import 'package:badiboss_eglise/routes/role_router.dart';
import 'package:badiboss_eglise/screens/dashboard/admin_dashboard.dart';
import 'package:badiboss_eglise/screens/dashboard/membre_dashboard.dart';
import 'package:badiboss_eglise/screens/dashboard/pasteur_dashboard.dart';
import 'package:badiboss_eglise/screens/dashboard/super_admin_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('super admin role is routed correctly', () {
    final page = RoleRouter.dashboardForRole('super_admin');
    expect(page, isA<SuperAdminDashboard>());
  });

  test('super admin spaced role is routed correctly', () {
    final page = RoleRouter.dashboardForRole('super admin');
    expect(page, isA<SuperAdminDashboard>());
  });

  test('pasteur role is routed correctly', () {
    final page = RoleRouter.dashboardForRole('pasteur');
    expect(page, isA<PasteurDashboard>());
  });

  test('admin role is routed correctly', () {
    final page = RoleRouter.dashboardForRole('admin');
    expect(page, isA<AdminDashboard>());
  });

  test('member role is routed correctly', () {
    final page = RoleRouter.dashboardForRole('membre');
    expect(page, isA<MembreDashboard>());
  });

  test('unknown role falls back to member dashboard', () {
    final page = RoleRouter.dashboardForRole('inconnu_total');
    expect(page, isA<MembreDashboard>());
  });
}
