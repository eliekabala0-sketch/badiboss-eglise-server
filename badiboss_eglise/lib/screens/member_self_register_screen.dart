import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/member.dart';
import '../auth/stores/session_store.dart';
import '../core/config.dart';
import '../core/phone_rd_congo.dart';
import '../services/member_list_refresh.dart';
import '../services/saas_store.dart';

class MemberSelfRegisterScreen extends StatefulWidget {
  const MemberSelfRegisterScreen({super.key});

  @override
  State<MemberSelfRegisterScreen> createState() => _MemberSelfRegisterScreenState();
}

class _MemberSelfRegisterScreenState extends State<MemberSelfRegisterScreen> {
  final _churchCode = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  final _commune = TextEditingController();
  final _quartier = TextEditingController();
  final _zone = TextEditingController();

  Sex _sex = Sex.male;
  MaritalStatus _marital = MaritalStatus.single;
  DateTime? _birthDate;

  bool _loading = false;
  String _message = '';

  String _cleanPhone(String v) => normalizePhoneRdCongo(v);

  String _randId() {
    final r = Random();
    final n = 100000 + r.nextInt(900000);
    return "m_${DateTime.now().millisecondsSinceEpoch}_$n";
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final s = await const SessionStore().read();
      var churchCode = _churchCode.text.trim();
      if (churchCode.isEmpty) {
        churchCode = (s?.churchCode ?? '').trim();
      }

      if (churchCode.isEmpty) {
        setState(() {
          _loading = false;
          _message = "Church code obligatoire : saisissez le code de votre église.";
        });
        return;
      }

      final churches = await SaaSStore.loadChurches();
      if (churches.isNotEmpty) {
        final codeOk = churches.any((c) => c.churchCode.toUpperCase() == churchCode.toUpperCase());
        if (!codeOk) {
          setState(() {
            _loading = false;
            _message = "Church code inconnu : ce code ne correspond à aucune église enregistrée. Vérifiez l'orthographe.";
          });
          return;
        }
      }

      if (_fullName.text.trim().isEmpty) {
        setState(() {
          _loading = false;
          _message = "Le nom complet est obligatoire.";
        });
        return;
      }

      if (_phone.text.trim().isEmpty) {
        setState(() {
          _loading = false;
          _message = "Le téléphone est obligatoire.";
        });
        return;
      }

      final phoneClean = _cleanPhone(_phone.text);
      if (phoneClean.length != 12 || !phoneClean.startsWith('243')) {
        setState(() {
          _loading = false;
          _message = "Numéro RDC invalide : attendu +243 suivi de 9 chiffres (12 chiffres au total après normalisation).";
        });
        return;
      }

      final pw = _password.text.trim();
      if (pw.length < 6) {
        setState(() {
          _loading = false;
          _message = "Mot de passe trop court : minimum 6 caractères.";
        });
        return;
      }

      if (_birthDate == null) {
        setState(() {
          _loading = false;
          _message = "La date de naissance est obligatoire.";
        });
        return;
      }

      if (_commune.text.trim().isEmpty || _quartier.text.trim().isEmpty || _zone.text.trim().isEmpty) {
        setState(() {
          _loading = false;
          _message = "Commune, quartier et zone sont obligatoires.";
        });
        return;
      }

      final m = Member(
        id: _randId(),
        churchCode: churchCode,
        fullName: _fullName.text.trim(),
        phone: phoneClean,
        role: 'member',
        status: MemberStatus.pending, // self-register -> validation obligatoire

        // Adresse minimale (OK)
        commune: _commune.text.trim(),
        quartier: _quartier.text.trim(),
        zone: _zone.text.trim(),

        // Champs conservés pour compatibilité (mais vides)
        neighborhood: '',
        region: '',
        province: '',
        addressLine: '',

        sex: _sex,
        maritalStatus: _marital,
        birthDateIso: _birthDate?.toIso8601String() ?? '',
        createdBy: 'self',
        createdAt: DateTime.now(),
      );

      final uri = Uri.parse('${Config.baseUrl}/public/members/self_register');
      final res = await http
          .post(
            uri,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'church_code': churchCode,
              'full_name': m.fullName,
              'phone': m.phone,
              'sex': sexToString(_sex),
              'quarter': m.quartier,
              'category': 'member',
              'presence_status': 'unknown',
              'marital_status': maritalToString(_marital),
              'birth_date': _birthDate?.toIso8601String().substring(0, 10),
              'commune': m.commune,
              'zone': m.zone,
              'address_line': '',
              'neighborhood': '',
              'region': '',
              'province': '',
              'password': pw,
            }),
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = res.body;
        try {
          final dec = jsonDecode(res.body.isEmpty ? '{}' : res.body);
          if (dec is Map) {
            msg = (dec['detail'] ?? dec['message'] ?? msg).toString();
          }
        } catch (_) {}
        throw StateError(msg);
      }

      MemberListRefresh.bump();
      setState(() {
        _loading = false;
        _message = "Enregistrement envoyé ✅\nStatut: pending (attente validation admin/pasteur).";
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = "Erreur: $e";
      });
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _password.dispose();
    _churchCode.dispose();
    _commune.dispose();
    _quartier.dispose();
    _zone.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) {
    return const InputDecoration(border: OutlineInputBorder()).copyWith(labelText: label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription membre")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _churchCode,
              decoration: _dec("Church code de l'église"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fullName,
              decoration: _dec("Nom complet"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              decoration: _dec("Téléphone"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: _dec("Mot de passe"),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<Sex>(
              value: _sex,
              items: const [
                DropdownMenuItem(value: Sex.male, child: Text("Homme")),
                DropdownMenuItem(value: Sex.female, child: Text("Femme")),
              ],
              onChanged: (v) => setState(() => _sex = v ?? Sex.male),
              decoration: _dec("Sexe"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MaritalStatus>(
              value: _marital,
              items: const [
                DropdownMenuItem(value: MaritalStatus.single, child: Text("Célibataire")),
                DropdownMenuItem(value: MaritalStatus.married, child: Text("Marié(e)")),
                DropdownMenuItem(value: MaritalStatus.divorced, child: Text("Divorcé(e)")),
                DropdownMenuItem(value: MaritalStatus.widowed, child: Text("Veuf/Veuve")),
              ],
              onChanged: (v) => setState(() => _marital = v ?? MaritalStatus.single),
              decoration: _dec("État civil"),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: _dec("Date de naissance"),
                    child: Text(
                      _birthDate == null
                          ? 'Sélectionner'
                          : _birthDate!.toIso8601String().substring(0, 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(now.year - 25),
                      firstDate: DateTime(1940),
                      lastDate: now,
                    );
                    if (picked == null) return;
                    setState(() => _birthDate = picked);
                  },
                  child: const Text("Choisir"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _commune, decoration: _dec("Commune")),
            const SizedBox(height: 10),
            TextField(controller: _quartier, decoration: _dec("Quartier")),
            const SizedBox(height: 10),
            TextField(controller: _zone, decoration: _dec("Zone")),

            const SizedBox(height: 12),
            if (_message.isNotEmpty) Text(_message),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text("Envoyer"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
