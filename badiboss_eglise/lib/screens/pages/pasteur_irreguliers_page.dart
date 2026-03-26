import 'package:flutter/material.dart';

class PasteurIrreguliersPage extends StatelessWidget {
  const PasteurIrreguliersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Irréguliers (SAFE)\nOn remettra les vrais champs après.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
