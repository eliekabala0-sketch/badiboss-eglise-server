import 'package:flutter/material.dart';

class AnnoncesPage extends StatelessWidget {
  final String token;
  final String codeEglise;

  const AnnoncesPage({
    super.key,
    required this.token,
    required this.codeEglise,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Annonces")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Code église: $codeEglise"),
            const SizedBox(height: 12),
            const Text(
                "📌 Ici : liste annonces, création, suppression, push (plus tard)."),
          ],
        ),
      ),
    );
  }
}
