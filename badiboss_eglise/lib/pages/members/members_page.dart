import 'package:flutter/material.dart';

class MembersPage extends StatelessWidget {
  final String token;
  final String codeEglise;

  const MembersPage({
    super.key,
    required this.token,
    required this.codeEglise,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Membres")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Code église: $codeEglise"),
            const SizedBox(height: 12),
            const Text(
                "📌 Ici on mettra : liste membres, filtre quartier/statut, ajout, détails."),
          ],
        ),
      ),
    );
  }
}
