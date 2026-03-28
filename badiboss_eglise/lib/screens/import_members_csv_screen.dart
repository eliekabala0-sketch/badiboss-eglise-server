import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../auth/stores/session_store.dart';
import '../core/config.dart';

class ImportMembersCsvScreen extends StatefulWidget {
  const ImportMembersCsvScreen({super.key});

  @override
  State<ImportMembersCsvScreen> createState() => _ImportMembersCsvScreenState();
}

class _ImportMembersCsvScreenState extends State<ImportMembersCsvScreen> {
  final _csvCtrl = TextEditingController();
  bool _loading = false;
  String _message = '';

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
      final s = await const SessionStore().read();
      final role = (s?.roleName ?? '').trim();
      final token = (s?.token ?? '').trim();
      if (token.isEmpty) throw StateError('token manquant');

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

        final uri = Uri.parse('${Config.baseUrl}/church/members/create');
        final res = await http
            .post(
              uri,
              headers: {
                'accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'full_name': fullName,
                'phone': phone,
                'sex': sex.toLowerCase().startsWith('f') ? 'female' : 'male',
                'quarter': quartier,
                'category': 'member',
                'presence_status': 'unknown',
                'marital_status': _parseMarital(marital),
                'commune': commune,
                'zone': zone,
                'address_line': addressLine,
                'neighborhood': neighborhood,
                'region': region,
                'province': province,
                'create_account': false,
              }),
            )
            .timeout(Duration(seconds: Config.timeoutSeconds));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw StateError(res.body);
        }
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

  String _parseMarital(String v) {
    final x = v.trim().toLowerCase();
    if (x.startsWith('mar')) return 'married';
    if (x.startsWith('div')) return 'divorced';
    if (x.startsWith('wid') || x.startsWith('veu')) return 'widowed';
    return 'single';
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
