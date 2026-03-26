import 'package:flutter/material.dart';

import '../access_control.dart';
import '../models/session.dart';
import '../models/user_role.dart';
import '../permissions.dart';
import '../stores/session_store.dart';
import '../stores/role_policy_store.dart';
import '../models/role_policy.dart';
import '../auth_validators.dart';

final class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

final class _RoleManagementPageState extends State<RoleManagementPage> {
  AppSession? _session;

  final _churchCtrl = TextEditingController();
  final _roleNameCtrl = TextEditingController();

  RolePolicy _policy = RolePolicy.empty();
  Set<String> _selectedPerms = <String>{};
  String _status = '';
  String _mode = 'edit';
  String? _selectedExistingRole;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    const ss = SessionStore();
    final s = await ss.read();
    setState(() {
      _session = s;
      if (s != null && s.churchCode != null) {
        _churchCtrl.text = s.churchCode!;
      }
    });
    await _reloadPolicy();
  }

  bool get _canManageRoles {
    final s = _session;
    if (s == null) return false;
    return s.role == UserRole.superAdmin || s.role == UserRole.pasteur;
  }

  Future<void> _reloadPolicy() async {
    final s = _session;
    if (s == null) return;

    final cc = _resolveChurchCode();
    if (cc == null) return;

    final p = await RolePolicyStore.read(cc);
    setState(() => _policy = p);
  }

  String? _resolveChurchCode() {
    final s = _session;
    if (s == null) return null;

    if (s.role == UserRole.superAdmin) {
      final cc = AuthValidators.normalizeChurchCode(_churchCtrl.text.trim());
      if (!AuthValidators.isValidChurchCode(cc)) return null;
      return cc;
    }

    final cc = s.churchCode;
    if (cc == null || cc.trim().isEmpty) return null;
    return cc.trim();
  }

  Future<void> _saveRole() async {
    final s = _session;
    if (s == null) return;

    if (!_canManageRoles) {
      setState(() => _status = 'Accès refusé: réservé au PASTEUR / SUPER ADMIN.');
      return;
    }

    final cc = _resolveChurchCode();
    if (cc == null) {
      setState(() => _status = 'churchCode invalide.');
      return;
    }

    final roleName = _mode == 'edit'
        ? (_selectedExistingRole ?? '').trim()
        : _roleNameCtrl.text.trim();
    if (roleName.isEmpty) {
      setState(() => _status = 'Nom du rôle obligatoire.');
      return;
    }

    // Protection: ne pas écraser superAdmin
    if (roleName.toLowerCase() == 'superadmin' || roleName.toLowerCase() == 'super_admin') {
      setState(() => _status = 'Interdit: superAdmin est système.');
      return;
    }

    // Enregistre
    final next = _policy.upsertRole(roleName, _selectedPerms);
    await RolePolicyStore.write(cc, next);

    setState(() {
      _policy = next;
      _status = 'Rôle enregistré: $roleName (église $cc)';
    });
  }

  Future<void> _deleteRole(String roleName) async {
    final s = _session;
    if (s == null) return;

    if (!_canManageRoles) {
      setState(() => _status = 'Accès refusé.');
      return;
    }

    final cc = _resolveChurchCode();
    if (cc == null) {
      setState(() => _status = 'churchCode invalide.');
      return;
    }

    final next = _policy.removeRole(roleName);
    await RolePolicyStore.write(cc, next);

    setState(() {
      _policy = next;
      _status = 'Rôle supprimé: $roleName';
      if (_roleNameCtrl.text.trim() == roleName) {
        _roleNameCtrl.clear();
        _selectedPerms = <String>{};
      }
    });
  }

  void _loadRoleToEditor(String roleName) {
    final perms = _policy.permissionsOf(roleName);
    setState(() {
      _roleNameCtrl.text = roleName;
      _selectedExistingRole = roleName;
      _selectedPerms = Set<String>.from(perms);
      _status = 'Edition rôle: $roleName';
    });
  }

  @override
  void dispose() {
    _churchCtrl.dispose();
    _roleNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des rôles (PASTEUR)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Session: ${s.phone} | role=${s.role.toJson()} | roleName=${s.roleName} | church=${s.churchCode ?? "-"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  if (!_canManageRoles)
                    const Text(
                      'Accès refusé: réservé au PASTEUR ou SUPER ADMIN.',
                      style: TextStyle(color: Colors.red),
                    ),

                  // Super admin choisit churchCode
                  if (s.role == UserRole.superAdmin) ...[
                    TextField(
                      controller: _churchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'churchCode (super admin)',
                        hintText: 'Ex: ABC123',
                      ),
                      onChanged: (_) => _reloadPolicy(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'edit', label: Text('Modifier rôle existant')),
                      ButtonSegment(value: 'create', label: Text('Ajouter nouveau rôle')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (v) => setState(() => _mode = v.first),
                  ),
                  const SizedBox(height: 8),
                  if (_mode == 'edit')
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Rôle sélectionné'),
                            child: Text(_selectedExistingRole ?? 'Aucun'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickRoleFromList();
                            if (picked == null) return;
                            _loadRoleToEditor(picked);
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Chercher'),
                        ),
                      ],
                    )
                  else
                    TextField(
                      controller: _roleNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du nouveau rôle (ex: protocole, finance, secretaire)',
                      ),
                    ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView(
                      children: [
                        const Text('Permissions du rôle :'),
                        const SizedBox(height: 8),
                        for (final p in Permissions.all)
                          CheckboxListTile(
                            title: Text(p),
                            value: _selectedPerms.contains(p),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedPerms.add(p);
                                } else {
                                  _selectedPerms.remove(p);
                                }
                              });
                            },
                          ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text('Rôles existants :'),
                        const SizedBox(height: 8),
                        for (final roleName in _policy.rolePermissions.keys.toList()..sort())
                          ListTile(
                            title: Text(roleName),
                            subtitle: Text(_policy.permissionsOf(roleName).join(', ')),
                            onTap: () {
                              setState(() => _mode = 'edit');
                              _loadRoleToEditor(roleName);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteRole(roleName),
                            ),
                          ),
                      ],
                    ),
                  ),

                  ElevatedButton(
                    onPressed: _canManageRoles ? _saveRole : null,
                    child: const Text('Enregistrer le rôle'),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                ],
              ),
      ),
    );
  }

  Future<String?> _pickRoleFromList() async {
    String q = '';
    final all = _policy.rolePermissions.keys.toList()..sort();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final filtered = all.where((r) => r.toLowerCase().contains(q.trim().toLowerCase())).toList();
          return AlertDialog(
            title: const Text('Sélectionner rôle'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nom du rôle'),
                    onChanged: (v) => setLocal(() => q = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun rôle trouvé'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => ListTile(
                              title: Text(filtered[i]),
                              onTap: () => Navigator.pop(ctx, filtered[i]),
                            ),
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
