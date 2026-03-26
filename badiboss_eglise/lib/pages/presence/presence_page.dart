import 'package:flutter/material.dart';

class PresencePage extends StatelessWidget {
  final String token;
  final String codeEglise;

  const PresencePage({
    super.key,
    required this.token,
    required this.codeEglise,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Présence")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Code église: $codeEglise"),
            const SizedBox(height: 12),
            const Text(
                "📌 Ici : marquer présence culte, liste présents/absents (plus tard)."),
          ],
        ),
      ),
    );
  }
}
