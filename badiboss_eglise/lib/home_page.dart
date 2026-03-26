import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String churchCode;
  final String user;
  final String token;

  const HomePage({
    super.key,
    required this.churchCode,
    required this.user,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Église'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.church, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            Text('Église : $churchCode'),
            Text('Utilisateur : $user'),
            const SizedBox(height: 10),
            const Text(
              'Connexion réussie 🎉',
              style: TextStyle(fontSize: 18, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
