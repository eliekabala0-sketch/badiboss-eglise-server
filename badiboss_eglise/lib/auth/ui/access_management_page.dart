import 'package:flutter/material.dart';

import '../auth_validators.dart';
import '../models/auth_account.dart';
import '../stores/auth_accounts_store.dart';
import '../models/user_role.dart';
import '../models/session.dart';
import '../stores/session_store.dart';
import '../../services/local_members_store.dart';
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
      if (_members.isEmpty) {
        _members = await LocalMembersStore.loadByChurch(s.churchCode!);
      }
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

    final cc = s.churchCode!; // 🔒 VERROUILLÉ : source unique
    final ph = AuthValidators.normalizePhone(_phoneCtrl.text);
    final pw = _passwordCtrl.text.trim();

    final acc = AuthAccount(
      id: '${cc}_$ph',
      churchCode: cc,
      phone: ph,
      fullName: '',
      roleName: 'membre',
      status: 'active',
      passwordPlain: pw,
      isActive: _isActive,
      isBanned: _isBanned,
      createdAt: DateTime.now(),
    );

    await AuthAccountsStore.upsert(acc);

    setState(() => _status = 'Accès enregistré: $ph / $cc');
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

    final cc = s.churchCode!;
    final ph = _phoneCtrl.text.trim();

    if (!AuthValidators.isValidPhone(ph)) {
      setState(() => _status = 'Téléphone invalide.');
      return;
    }

    final acc = await AuthAccountsStore.findByPhone(
      churchCode: cc,
      phone: ph,
    );

    if (acc == null) {
      setState(() => _status = 'Aucun accès trouvé.');
      return;
    }

    setState(() {
      _passwordCtrl.text = acc.passwordPlain;
      _isActive = acc.isActive;
      _isBanned = acc.isBanned;
      _status = 'Accès chargé.';
    });
  }

  Future<void> _deleteAccess() async {
    if (!_isAuthorizedAdmin) {
      setState(() => _status = 'Accès refusé.');
      return;
    }

    final s = _session;
    if (s == null || s.churchCode == null) {
      setState(() => _status = 'Session invalide.');
      return;
    }

    final cc = s.churchCode!;
    final ph = _phoneCtrl.text.trim();

    await AuthAccountsStore.removeByPhone(
      churchCode: cc,
      phone: ph,
    );

    setState(() => _status = 'Accès supprimé.');
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
                            labelText: 'Mot de passe',
                          ),
                          obscureText: true,
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('Actif'),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                        SwitchListTile(
                          title: const Text('Banni'),
                          value: _isBanned,
                          onChanged: (v) => setState(() => _isBanned = v),
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
                    child: const Text('Supprimer'),
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