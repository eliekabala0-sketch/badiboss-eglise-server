import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';
import '../services/local_members_store.dart';

class ImportMembersCsvScreen extends StatefulWidget {
  const ImportMembersCsvScreen({super.key});

  @override
  State<ImportMembersCsvScreen> createState() => _ImportMembersCsvScreenState();
}

class _ImportMembersCsvScreenState extends State<ImportMembersCsvScreen> {
  final _csvCtrl = TextEditingController();
  bool _loading = false;
  String _message = '';

  String _randId() {
    final r = Random();
    final n = 100000 + r.nextInt(900000);
    return "m_$n";
  }

  /// CSV attendu (avec entête):
  /// fullName,phone,sex,maritalStatus,commune,quartier,zone,neighborhood,region,province,addressLine
  ///
  /// Les valeurs manquantes -> ""
  Future<void> _import() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final churchCode = (prefs.getString('auth_church_code') ?? '').trim();
      final role = (prefs.getString('auth_role') ?? '').trim();

      if (churchCode.isEmpty) {
        setState(() {
          _loading = false;
          _message = "churchCode manquant en session.";
        });
        return;
      }

      // Admin/Pasteur/Super_admin autorisés pour importer
      final allowed =
          role == 'admin' || role == 'pasteur' || role == 'super_admin';
      if (!allowed) {
        setState(() {
          _loading = false;
          _message = "Import réservé à admin/pasteur/super_admin.";
        });
        return;
      }

      final raw = _csvCtrl.text.trim();
      if (raw.isEmpty) {
        setState(() {
          _loading = false;
          _message = "Colle le CSV d'abord.";
        });
        return;
      }

      final lines =
          raw.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) {
        setState(() {
          _loading = false;
          _message = "CSV invalide: au moins 1 entête + 1 ligne.";
        });
        return;
      }

      // On lit l'entête mais on n'en dépend pas (position-based)
      // -> pas de variables inutilisées
      // ignore: unused_local_variable
      final _ = lines.first;

      int imported = 0;

      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',').map((e) => e.trim()).toList();
        String getAt(int idx) => idx < cols.length ? cols[idx] : '';

        // position-based
        final fullName = getAt(0);
        final phone = getAt(1);
        final sex = getAt(2);
        final marital = getAt(3);
        final commune = getAt(4);
        final quartier = getAt(5);
        final zone = getAt(6);
        final neighborhood = getAt(7);
        final region = getAt(8);
        final province = getAt(9);
        final addressLine = getAt(10);

        if (fullName.isEmpty || phone.isEmpty) {
          continue; // skip ligne invalide
        }

        final m = Member(
          id: _randId(),
          churchCode: churchCode,
          fullName: fullName,
          phone: phone,
          role: 'member',
          status: MemberStatus.pending, // IMPORT -> à valider
          commune: commune,
          quartier: quartier,
          zone: zone,
          neighborhood: neighborhood,
          region: region,
          province: province,
          addressLine: addressLine,
          sex: sex.toLowerCase().startsWith('f') ? Sex.female : Sex.male,
          maritalStatus: _parseMarital(marital),
          createdBy: role,
          createdAt: DateTime.now(),
        );

        await LocalMembersStore.upsert(m);
        imported++;
      }

      setState(() {
        _loading = false;
        _message = "Import terminé ✅  Lignes importées: $imported\n"
            "NB: statut = pending (validation admin/pasteur).";
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = "Erreur import: $e";
      });
    }
  }

  MaritalStatus _parseMarital(String v) {
    final x = v.trim().toLowerCase();
    if (x.startsWith('mar')) return MaritalStatus.married;
    if (x.startsWith('div')) return MaritalStatus.divorced;
    if (x.startsWith('wid') || x.startsWith('veu')) return MaritalStatus.widowed;
    return MaritalStatus.single;
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import membres (CSV)")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Text(
              "Colle le CSV ici (format: fullName,phone,sex,maritalStatus,commune,quartier,zone,neighborhood,region,province,addressLine)",
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _csvCtrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      "fullName,phone,sex,maritalStatus,commune,quartier,zone,neighborhood,region,province,addressLine\n"
                      "Jean KABALA,0990000001,male,single,Kintambo,Nguma,Zone A,Bloc 2,Ouest,Kinshasa,Av. ...",
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_message.isNotEmpty)
              Text(_message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _import,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: const Text("Importer"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
