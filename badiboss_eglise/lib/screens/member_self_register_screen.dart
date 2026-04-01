import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/config.dart';
import '../core/phone_rd_congo.dart';
import '../models/member.dart';

class MemberSelfRegisterScreen extends StatefulWidget {
  final String? churchCode;
  const MemberSelfRegisterScreen({super.key, this.churchCode});

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

  @override
  void initState() {
    super.initState();
    final cc = (widget.churchCode ?? '').trim();
    if (cc.isNotEmpty) _churchCode.text = cc;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final churchCode = _churchCode.text.trim();

      if (churchCode.isEmpty) {
        setState(() {
          _loading = false;
          _message = "Church code obligatoire : saisissez le code de votre église.";
        });
        return;
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
              'full_name': _fullName.text.trim(),
              'phone': phoneClean,
              'sex': sexToString(_sex),
              'quarter': _quartier.text.trim(),
              'category': 'member',
              'presence_status': 'unknown',
              'marital_status': maritalToString(_marital),
              'birth_date': _birthDate?.toIso8601String().substring(0, 10),
              'commune': _commune.text.trim(),
              'zone': _zone.text.trim(),
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
