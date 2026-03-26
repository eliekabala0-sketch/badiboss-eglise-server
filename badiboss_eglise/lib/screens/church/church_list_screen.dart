import 'package:flutter/material.dart';

class ChurchListScreen extends StatelessWidget {
  const ChurchListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Églises")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Gestion des églises",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text("• Créer une église"),
            Text("• Activer / désactiver"),
            Text("• Assigner un admin"),
            SizedBox(height: 20),
            Text(
              "API à brancher à l’étape suivante",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
