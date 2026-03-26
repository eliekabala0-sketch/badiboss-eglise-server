import 'package:flutter/material.dart';
export '../dashboard_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String? token;
  final String? phone;
  final String? role;
  final String? codeEglise;

  const DashboardScreen({
    super.key,
    this.token,
    this.phone,
    this.role,
    this.codeEglise,
  });

  @override
  Widget build(BuildContext context) {
    final r = role ?? 'unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Role: $r\n'
          'Phone: ${phone ?? ""}\n'
          'CodeEglise: ${codeEglise ?? ""}\n'
          'Token: ${(token ?? "").isEmpty ? "(vide)" : "OK"}',
        ),
      ),
    );
  }
}
