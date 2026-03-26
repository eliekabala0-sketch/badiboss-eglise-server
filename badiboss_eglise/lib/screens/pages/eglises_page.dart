import 'package:flutter/material.dart';

enum EglisesPageMode { admin, pasteur }

class EglisesPage extends StatelessWidget {
  final EglisesPageMode mode;
  final String phone;
  final String? codeEglise;

  const EglisesPage({
    super.key,
    required this.mode,
    required this.phone,
    this.codeEglise,
  });

  @override
  Widget build(BuildContext context) {
    final title = mode == EglisesPageMode.admin ? 'Admin' : 'Pasteur';

    return Scaffold(
      appBar: AppBar(
        title: Text('Eglises - $title'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Téléphone: $phone'),
            const SizedBox(height: 6),
            Text('Code Église: ${codeEglise ?? "-"}'),
            const Divider(height: 24),
            Text(
              mode == EglisesPageMode.admin
                  ? 'Mode Admin (bloc 2 stable).'
                  : 'Mode Pasteur (bloc 2 stable).',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'On a annulé temporairement le bloc “irréguliers / tâches” pour revenir à une base qui compile.\n'
              'On réactive ensuite bloc par bloc.',
            ),
          ],
        ),
      ),
    );
  }
}
