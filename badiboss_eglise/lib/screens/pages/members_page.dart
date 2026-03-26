import 'package:flutter/material.dart';

class MembersPage extends StatelessWidget {
  final String phone;
  final String role;
  final String codeEglise;
  final String token;

  const MembersPage({
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
        'Page Membres\n(à connecter à l’API)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
