import 'package:flutter/material.dart';

import '../models/member.dart';

/// Sélecteur de membre : filtre par nom, code membre ou téléphone.
Future<Member?> showMemberPickerDialog(
  BuildContext context, {
  required List<Member> members,
  String title = 'Choisir un membre',
}) {
  return showDialog<Member>(
    context: context,
    builder: (ctx) {
      var q = '';
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final qq = q.trim().toLowerCase();
          final filtered = members.where((m) {
            if (qq.isEmpty) return true;
            final hay = '${m.id} ${m.fullName} ${m.phone}'.toLowerCase();
            return hay.contains(qq);
          }).toList();
          final size = MediaQuery.of(ctx).size;
          final dialogHeight = size.height * 0.72;
          final dialogWidth = size.width < 600 ? size.width * 0.92 : 520.0;
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Nom, code membre ou téléphone',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setLocal(() => q = v),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun membre trouvé'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final m = filtered[i];
                              return ListTile(
                                dense: true,
                                title: Text('${m.id} • ${m.fullName}'),
                                subtitle: Text(m.phone),
                                onTap: () => Navigator.pop(ctx, m),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ],
          );
        },
      );
    },
  );
}
