import 'package:flutter/material.dart';

class SuperAdminReportsPage extends StatelessWidget {
  const SuperAdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Rapports Super Admin (SAFE)\nStats + rapports seront remis après.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
