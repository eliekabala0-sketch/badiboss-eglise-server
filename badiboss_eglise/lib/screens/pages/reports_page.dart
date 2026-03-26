import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  final String phone;
  final String role;
  final String codeEglise;
  final String token;

  const ReportsPage({
    super.key,
    required this.phone,
    required this.role,
    required this.codeEglise,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Page Rapports\n(Présences, finances, membres)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
