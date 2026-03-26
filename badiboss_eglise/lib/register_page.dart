import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Création de compte')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Module création de compte/église : étape restante.\n"
          "- Créer une église (paiement/validation)\n"
          "- Créer un compte membre\n"
          "- Assigner rôle + permissions\n\n"
          "⚠️ Cette page est un stub (placeholder) pour ne pas casser l’analyse.",
        ),
      ),
    );
  }
}
