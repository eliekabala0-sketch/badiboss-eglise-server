import 'package:badiboss_eglise/screens/dashboard/admin_dashboard.dart';
import 'package:badiboss_eglise/screens/dashboard/membre_dashboard.dart';
import 'package:badiboss_eglise/screens/dashboard/pasteur_dashboard.dart';
import 'package:badiboss_eglise/screens/dashboard/super_admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpDashboard(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: child,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('super admin dashboard renders with logout action', (tester) async {
    await _pumpDashboard(tester, const SuperAdminDashboard());
    expect(find.textContaining('Super Admin'), findsWidgets);
    expect(find.byIcon(Icons.logout_rounded), findsAtLeastNWidgets(1));
  });

  testWidgets('pasteur dashboard renders with pastoral cards', (tester) async {
    await _pumpDashboard(tester, const PasteurDashboard());
    expect(find.textContaining('Pasteur'), findsWidgets);
    expect(find.text('Relations pastorales'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('admin dashboard renders with admin hero', (tester) async {
    await _pumpDashboard(tester, const AdminDashboard());
    expect(find.textContaining('Admin'), findsWidgets);
    expect(find.text('Pilotage administration'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('member dashboard renders with member space entries', (tester) async {
    await _pumpDashboard(tester, const MembreDashboard());
    expect(find.textContaining('Membre'), findsWidgets);
    expect(find.text('Mon espace membre'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });
}
