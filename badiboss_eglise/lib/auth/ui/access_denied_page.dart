import 'package:flutter/material.dart';

class AccessDeniedPage extends StatelessWidget {
  final String? message;

  const AccessDeniedPage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final msg = (message == null || message!.trim().isEmpty)
        ? "Accès refusé : permission insuffisante."
        : message!.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accès refusé'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 64),
              const SizedBox(height: 16),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}