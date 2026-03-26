import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/member.dart';
import '../auth/stores/session_store.dart';
import '../core/config.dart';
import '../core/phone_rd_congo.dart';
import '../services/local_members_store.dart';
import '../services/member_list_refresh.dart';

class AddMemberAdminScreen extends StatefulWidget {
  const AddMemberAdminScreen({super.key});

  @override
  State<AddMemberAdminScreen> createState() => _AddMemberAdminScreenState();
}

class _AddMemberAdminScreenState extends State<AddMemberAdminScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _communeCtrl = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();

  Sex _sex = Sex.male;
  MaritalStatus _marital = MaritalStatus.single;
  DateTime? _birthDate;

  bool _loading = false;
  String _message = '';

  String _cleanPhone(String v) => normalizePhoneRdCongo(v);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final s = await const SessionStore().read();
      var churchCode = (s?.churchCode ?? '').trim();
      if (churchCode.isEmpty) {
        churchCode = (prefs.getString('auth_church_code') ?? '').trim();
      }
      final role = (prefs.getString('auth_role') ?? '').trim();
      final token = (s?.token ?? '').trim();

      final allowed = role == 'admin' || role == 'pasteur' || role == 'super_admin';
      if (!allowed) {
        setState(() {
          _loading = false;
          _message = "Action réservée à admin/pasteur/super_admin.";
        });
        return;
      }

      if (churchCode.isEmpty) {
        setState(() {
          _loading = false;
          _message = "churchCode manquant en session.";
        });
        return;
      }

      try {
        if (token.isEmpty) throw StateError('token manquant');
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
                'full_name': _fullNameCtrl.text.trim(),
                'phone': _cleanPhone(_phoneCtrl.text),
                'sex': sexToString(_sex),
                'quarter': _quartierCtrl.text.trim(),
                'marital_status': maritalToString(_marital),
                'birth_date': _birthDate?.toIso8601String().substring(0, 10),
                'commune': _communeCtrl.text.trim(),
                'zone': _zoneCtrl.text.trim(),
                'address_line': '',
                'neighborhood': '',
                'region': '',
                'province': '',
                'create_account': false,
              }),
            )
            .timeout(Duration(seconds: Config.timeoutSeconds));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw StateError(res.body);
        }
      } catch (_) {
        // fallback local (ne casse pas l’existant)
        final m = Member(
          id: LocalMembersStore.newId(),
          churchCode: churchCode,
          fullName: _fullNameCtrl.text.trim(),
          phone: _cleanPhone(_phoneCtrl.text),
          role: 'member',
          status: MemberStatus.pending, // admin ajoute -> validation

          commune: _communeCtrl.text.trim(),
          quartier: _quartierCtrl.text.trim(),
          zone: _zoneCtrl.text.trim(),

          // champs conservés pour compatibilité (vides)
          neighborhood: '',
          region: '',
          province: '',
          addressLine: '',

          sex: _sex,
          maritalStatus: _marital,
          birthDateIso: _birthDate?.toIso8601String() ?? '',
          createdBy: role,
          createdAt: DateTime.now(),
        );
        await LocalMembersStore.upsert(m);
      }

      setState(() {
        _loading = false;
        _message = "Membre enregistré ✅ (statut: pending, à valider)";
      });

      MemberListRefresh.bump();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _loading = false;
        _message = "Erreur: $e";
      });
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _communeCtrl.dispose();
    _quartierCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajout membre (admin)")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Identité",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _fullNameCtrl,
                          decoration: _dec("Nom complet", hint: "Ex: Jean KABALA", icon: Icons.person),
                          validator: (v) => (v == null || v.trim().length < 3) ? "Nom obligatoire" : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _dec("Téléphone (+243...)", hint: "Ex: 0990000001", icon: Icons.phone),
                          validator: (v) {
                            final p = _cleanPhone(v ?? '');
                            if (p.length != 12 || !p.startsWith('243')) {
                              return "Numéro RDC invalide (+243 + 9 chiffres)";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<Sex>(
                                value: _sex,
                                decoration: _dec("Sexe", icon: Icons.wc_outlined),
                                items: const [
                                  DropdownMenuItem(value: Sex.male, child: Text("Homme")),
                                  DropdownMenuItem(value: Sex.female, child: Text("Femme")),
                                ],
                                onChanged: (v) => setState(() => _sex = v ?? Sex.male),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<MaritalStatus>(
                                value: _marital,
                                decoration: _dec("État civil", icon: Icons.favorite_outline),
                                items: const [
                                  DropdownMenuItem(value: MaritalStatus.single, child: Text("Célibataire")),
                                  DropdownMenuItem(value: MaritalStatus.married, child: Text("Marié(e)")),
                                  DropdownMenuItem(value: MaritalStatus.divorced, child: Text("Divorcé(e)")),
                                  DropdownMenuItem(value: MaritalStatus.widowed, child: Text("Veuf/Veuve")),
                                ],
                                onChanged: (v) => setState(() => _marital = v ?? MaritalStatus.single),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: InputDecorator(
                                decoration: _dec("Date de naissance", icon: Icons.cake_outlined),
                                child: Text(
                                  _birthDate == null
                                      ? 'Sélectionner'
                                      : _birthDate!.toIso8601String().substring(0, 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
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
                              icon: const Icon(Icons.edit_calendar_rounded),
                              label: const Text("Choisir"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Localisation (simple)",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _communeCtrl,
                          decoration: _dec("Commune", hint: "Ex: Kintambo", icon: Icons.location_city),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _quartierCtrl,
                          decoration: _dec("Quartier", hint: "Ex: Nguma", icon: Icons.map_outlined),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _zoneCtrl,
                          decoration: _dec("Zone", hint: "Ex: Zone A", icon: Icons.layers_outlined),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                if (_message.isNotEmpty) Text(_message),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: const Text("Enregistrer (pending)"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
