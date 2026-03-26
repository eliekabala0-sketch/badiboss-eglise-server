import 'package:flutter/material.dart';

class PasteurTasksPage extends StatelessWidget {
  const PasteurTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Tâches Pasteur (SAFE)\nOn réactive les tâches après.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
