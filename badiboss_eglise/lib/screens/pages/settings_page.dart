import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final String phone;
  final String role;
  final String codeEglise;
  final String token;

  const SettingsPage({
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
        'Paramètres\n(Profil, Église, rôles, sécurité)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
