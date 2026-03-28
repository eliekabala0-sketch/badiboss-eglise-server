import 'package:flutter/material.dart';

import '../../core/phone_rd_congo.dart';
import '../../services/church_api.dart';
import '../auth_validators.dart';
import '../models/session.dart';
import '../models/user_role.dart';
import '../stores/session_store.dart';
import '../../services/member_directory_service.dart';
import '../../models/member.dart';

final class AccessManagementPage extends StatefulWidget {
  const AccessManagementPage({super.key});

  @override
  State<AccessManagementPage> createState() => _AccessManagementPageState();
}

final class _AccessManagementPageState extends State<AccessManagementPage> {
  final _formKey = GlobalKey<FormState>();

  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isActive = true;
  bool _isBanned = false;

  String _status = '';
  AppSession? _session;
  List<Member> _members = <Member>[];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    const store = SessionStore();
    final s = await store.read();
    if (s?.churchCode != null && s!.churchCode!.trim().isNotEmpty) {
      _members = await const MemberDirectoryService().loadMembersForActiveChurch();
    }
    setState(() => _session = s);
  }

  bool get _isAuthorizedAdmin {
    final s = _session;
    if (s == null) return false;
    return s.role == UserRole.superAdmin ||
        s.role == UserRole.admin ||
        s.role == UserRole.pasteur;
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Téléphone obligatoire';
    if (!AuthValidators.isValidPhone(s)) return 'Téléphone invalide (9–15 chiffres)';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Mot de passe obligatoire';
    if (!AuthValidators.isValidPassword(s)) return 'Mot de passe min 6';
    return null;
  }

  Future<Map<String, dynamic>?> _userRowByPhone(String phoneInput) async {
    final want = normalizePhoneRdCongo(phoneInput);
    final dec = await ChurchApi.getJson('/church/users/list');
    final users = dec['users'];
    if (users is! List) return null;
    for (final e in users) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final p = (m['phone'] ?? '').toString();
      if (normalizePhoneRdCongo(p) == want) return m;
    }
    return null;
  }

  Future<void> _createOrUpdate() async {
    if (!_isAuthorizedAdmin) {
      setState(() => _status = 'Accès refusé: rôle non autorisé.');
      return;
    }

    final s = _session;
    if (s == null || s.churchCode == null) {
      setState(() => _status = 'Session invalide: churchCode manquant.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final ph = AuthValidators.normalizePhone(_phoneCtrl.text);
    final pw = _passwordCtrl.text.trim();

    try {
      final existing = await _userRowByPhone(ph);
      if (existing != null) {
        final id = int.tryParse((existing['id'] ?? '').toString());
        if (id == null) throw StateError('id utilisateur invalide');
        await ChurchApi.postJson('/church/users/password_reset', {
          'user_id': id,
          'new_password': pw,
        });
        await ChurchApi.postJson('/church/users/disable', {
          'user_id': id,
          'disabled': _isBanned || !_isActive,
        });
        setState(() => _status = 'Compte mis à jour: $ph');
        return;
      }

      await ChurchApi.postJson('/church/users/create', {
        'phone': ph,
        'full_name': '',
        'password': pw,
        'role': 'MEMBRE',
      });
      setState(() => _status = 'Accès créé: $ph');
    } catch (e) {
      setState(() => _status = 'Erreur: $e');
    }
  }

  Future<void> _loadAccess() async {
    if (!_isAuthorizedAdmin) {
      setState(() => _status = 'Accès refusé.');
      return;
    }

    final s = _session;
    if (s == null || s.churchCode == null) {
      setState(() => _status = 'Session invalide.');
      return;
    }

    final ph = _phoneCtrl.text.trim();

    if (!AuthValidators.isValidPhone(ph)) {
      setState(() => _status = 'Téléphone invalide.');
      return;
    }

    try {
      final row = await _userRowByPhone(ph);
      if (row == null) {
        setState(() {
          _passwordCtrl.clear();
          _status = 'Aucun accès trouvé.';
        });
        return;
      }
      final disabled = (row['is_disabled'] == 1 || row['is_disabled'] == true);
      setState(() {
        _passwordCtrl.clear();
        _isActive = !disabled;
        _isBanned = disabled;
        _status = 'Compte chargé (mot de passe non affiché — saisir un nouveau pour réinitialiser).';
      });
    } catch (e) {
      setState(() => _status = 'Erreur chargement: $e');
    }
  }

  Future<void> _deleteAccess() async {
    if (!_isAuthorizedAdmin) {
      setState(() => _status = 'Accès refusé.');
      return;
    }

    final ph = _phoneCtrl.text.trim();
    try {
      final row = await _userRowByPhone(ph);
      if (row == null) {
        setState(() => _status = 'Aucun compte à désactiver.');
        return;
      }
      final id = int.tryParse((row['id'] ?? '').toString());
      if (id == null) throw StateError('id invalide');
      await ChurchApi.postJson('/church/users/disable', {'user_id': id, 'disabled': true});
      setState(() {
        _isBanned = true;
        _isActive = false;
        _status = 'Compte désactivé sur le serveur.';
      });
    } catch (e) {
      setState(() => _status = 'Erreur: $e');
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des accès (ADMIN)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Session: ${s.phone} | role=${s.role.toJson()} | church=${s.churchCode ?? "-"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone',
                          ),
                          validator: _validatePhone,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Sélectionner membre existant'),
                          subtitle: Text(_phoneCtrl.text.trim().isEmpty ? 'Filtrer par code/nom/téléphone' : _phoneCtrl.text.trim()),
                          trailing: const Icon(Icons.search),
                          onTap: () async {
                            final picked = await _pickMember();
                            if (picked == null) return;
                            setState(() => _phoneCtrl.text = picked.phone);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe (création ou réinitialisation)',
                          ),
                          obscureText: true,
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('Actif (non désactivé sur le serveur)'),
                          value: _isActive && !_isBanned,
                          onChanged: (v) => setState(() {
                            _isActive = v;
                            if (v) _isBanned = false;
                          }),
                        ),
                        SwitchListTile(
                          title: const Text('Désactivé / banni (serveur)'),
                          value: _isBanned,
                          onChanged: (v) => setState(() {
                            _isBanned = v;
                            if (v) _isActive = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isAuthorizedAdmin ? _createOrUpdate : null,
                          child: const Text('Enregistrer'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isAuthorizedAdmin ? _loadAccess : null,
                          child: const Text('Charger'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _isAuthorizedAdmin ? _deleteAccess : null,
                    child: const Text('Désactiver sur le serveur'),
                  ),
                  const SizedBox(height: 12),
                  Text(_status),
                ],
              ),
      ),
    );
  }
}

extension on _AccessManagementPageState {
  Future<Member?> _pickMember() async {
    String q = '';
    final screenH = MediaQuery.of(context).size.height;
    return showDialog<Member>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final list = _members.where((m) {
            final qq = q.trim().toLowerCase();
            if (qq.isEmpty) return true;
            return '${m.id} ${m.fullName} ${m.phone}'.toLowerCase().contains(qq);
          }).toList();
          return AlertDialog(
            title: const Text('Sélectionner un membre'),
            content: SizedBox(
              width: 460,
              height: screenH * 0.68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nom / code / téléphone'),
                    onChanged: (v) => setLocal(() => q = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('Aucun membre trouvé'))
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final m = list[i];
                              return ListTile(
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
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
          );
        },
      ),
    );
  }
}
