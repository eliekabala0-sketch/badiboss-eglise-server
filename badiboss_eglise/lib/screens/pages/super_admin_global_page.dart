import 'package:flutter/material.dart';

class SuperAdminGlobalPage extends StatelessWidget {
  const SuperAdminGlobalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admin - Vision Globale')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Base Super Admin (stable).\n\n'
          'On remettra ensuite:\n'
          '- entrer/sortir d’église\n'
          '- validation après paiement\n'
          '- stats + rapports imprimables\n'
          'Mais bloc par bloc, sans casser.',
        ),
      ),
    );
  }
}
