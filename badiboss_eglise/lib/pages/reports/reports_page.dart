import 'package:flutter/material.dart';

class ReportsPage extends StatelessWidget {
  final String token;
  final String codeEglise;

  const ReportsPage({
    super.key,
    required this.token,
    required this.codeEglise,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rapports")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Code église: $codeEglise"),
            const SizedBox(height: 12),
            const Text(
                "📌 Ici : rapport mensuel, graphique, membres réguliers/irréguliers."),
          ],
        ),
      ),
    );
  }
}
