import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('DashboardScreen OK ✅'),
            const SizedBox(height: 12),
            Text('role: ${role ?? "-"}'),
            Text('phone: ${phone ?? "-"}'),
            Text('codeEglise: ${codeEglise ?? "-"}'),
            Text('token: ${token == null ? "-" : "OK"}'),
          ],
        ),
      ),
    );
  }
}
