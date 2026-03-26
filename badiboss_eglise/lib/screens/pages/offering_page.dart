import 'package:flutter/material.dart';

class OfferingPage extends StatelessWidget {
  final String phone;
  final String role;
  final String codeEglise;
  final String token;

  const OfferingPage({
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
        'Page Offrandes / Dons\n(à connecter à l’API + Mobile Money)',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
