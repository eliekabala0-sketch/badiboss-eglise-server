import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../models/member.dart';
import '../../auth/stores/session_store.dart';
import '../../core/active_church_scope.dart';
import '../../core/config.dart';
import '../../services/member_list_refresh.dart';
import '../add_member_admin_screen.dart';
import '../import_members_csv_screen.dart';
import '../member_neighbors_screen.dart';
import '../member_self_register_screen.dart';
import '../pending_members_screen.dart';

class TabMembers extends StatefulWidget {
  const TabMembers({super.key});

  @override
  State<TabMembers> createState() => _TabMembersState();
}

class _TabMembersState extends State<TabMembers> {
  bool _loading = true;

  String _churchCode = '';
  String _role = '';
  String _token = '';
  String? _error;

  String _query = '';
  String _regularityFilter = 'all';
  String _trendFilter = 'all';
  List<Member> _items = [];

  bool get _isAdmin =>
      _role == 'admin' || _role == 'pasteur' || _role == 'super_admin';

  bool get _isMember => _role == 'member' || _role == 'membre';

  @override
  void initState() {
    super.initState();
    MemberListRefresh.tick.addListener(_onMembersRefreshTick);
    _init();
  }

  void _onMembersRefreshTick() {
    if (mounted) unawaited(_reload());
  }

  @override
  void dispose() {
    MemberListRefresh.tick.removeListener(_onMembersRefreshTick);
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final s = await const SessionStore().read();
    _role = (s?.roleName ?? '').trim();
    _churchCode = await resolveActiveChurchCode();
    _token = (s?.token ?? '').trim();
    await _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final s = await const SessionStore().read();
    _role = (s?.roleName ?? '').trim();
    _churchCode = await resolveActiveChurchCode();
    _token = (s?.token ?? '').trim();

    if (_churchCode.isEmpty) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    try {
      final api = await _fetchMembersFromApi(
        token: _token,
        pendingOnly: false,
      );

      api.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      setState(() {
        _items = api;
        _loading = false;
      });
    } catch (e) {
      final msg = e is StateError ? e.message : e.toString();
      setState(() {
        _items = [];
        _error = 'Impossible de charger les membres depuis le serveur. $msg';
        _loading = false;
      });
    }
  }

  int get _pendingCount =>
      _items.where((m) => m.status == MemberStatus.pending).length;

  List<Member> get _filtered {
    final q = _query.trim();
    return _items.where((m) {
      if (_regularityFilter != 'all' && m.regularityTag != _regularityFilter) {
        return false;
      }
      if (_trendFilter != 'all' && m.regularityTrend != _trendFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      // recherche pro: nom + téléphone + code membre (id) + champs étendus
      final blob = [
        m.id,
        m.fullName,
        m.phone,
        m.commune,
        m.quartier,
        m.zone,
        m.addressLine,
        m.neighborhood,
        m.region,
        m.province,
      ].join(' | ').toLowerCase();
      return blob.contains(q.toLowerCase());
    }).toList();
  }

  String _regularityLabel(Member m) {
    if (m.regularityTag == 'regular') return 'Régulier';
    if (m.regularityTag == 'irregular') return 'Irrégulier';
    return 'À surveiller';
  }

  String _trendLabel(Member m) {
    if (m.regularityTrend == 'improving') return 'En amélioration';
    if (m.regularityTrend == 'retrograding') return 'Rétrograde';
    return 'Stable';
  }

  Future<void> _openSelfRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MemberSelfRegisterScreen()),
    );
    await _reload();
  }

  Future<void> _openImportCsv() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ImportMembersCsvScreen()),
    );
    await _reload();
  }

  Future<void> _openAddManual() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMemberAdminScreen()),
    );
    if (res == true) await _reload();
  }

  Future<void> _openPending() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PendingMembersScreen()),
    );
    await _reload();
  }

  Future<void> _openMyNeighbors() async {
    if (!_isMember) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MemberNeighborsScreen()),
    );
  }

  Future<void> _approve(Member m) async {
    if (!_isAdmin) return;
    try {
      await _validateMemberApi(token: _token, memberNumber: m.id, validated: true);
    } catch (e) {
      if (mounted) {
        final msg = e is StateError ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
    await _reload();
  }

  Future<void> _suspend(Member m) async {
    if (!_isAdmin) return;
    try {
      await _setMemberStatusApi(token: _token, memberNumber: m.id, status: 'suspended');
    } catch (e) {
      if (mounted) {
        final msg = e is StateError ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
    await _reload();
  }

  Future<void> _ban(Member m) async {
    if (!_isAdmin) return;
    try {
      await _setMemberStatusApi(token: _token, memberNumber: m.id, status: 'banned');
    } catch (e) {
      if (mounted) {
        final msg = e is StateError ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
    await _reload();
  }

  Future<void> _delete(Member m) async {
    if (!_isAdmin) return;
    try {
      await _deleteMemberApi(token: _token, memberNumber: m.id);
    } catch (e) {
      if (mounted) {
        final msg = e is StateError ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
    await _reload();
  }

  Future<void> _editMember(Member m) async {
    if (!_isAdmin) return;
    final nameCtrl = TextEditingController(text: m.fullName);
    final phoneCtrl = TextEditingController(text: m.phone);
    final communeCtrl = TextEditingController(text: m.commune);
    final quarterCtrl = TextEditingController(text: m.quartier);
    final zoneCtrl = TextEditingController(text: m.zone);
    final addressCtrl = TextEditingController(text: m.addressLine);
    String selectedRole = m.role.trim().isEmpty ? 'membre' : m.role.trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier membre'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone')),
              const SizedBox(height: 8),
              TextField(controller: communeCtrl, decoration: const InputDecoration(labelText: 'Commune')),
              const SizedBox(height: 8),
              TextField(controller: quarterCtrl, decoration: const InputDecoration(labelText: 'Quartier')),
              const SizedBox(height: 8),
              TextField(controller: zoneCtrl, decoration: const InputDecoration(labelText: 'Zone')),
              const SizedBox(height: 8),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'membre', child: Text('Membre')),
                  DropdownMenuItem(value: 'protocole', child: Text('Protocole')),
                  DropdownMenuItem(value: 'secretaire', child: Text('Secrétaire')),
                  DropdownMenuItem(value: 'finance', child: Text('Finance')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => selectedRole = (v ?? 'membre'),
                decoration: const InputDecoration(labelText: 'Rôle / fonction'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (ok != true) return;
    final updated = m.copyWith(
      fullName: nameCtrl.text.trim().isEmpty ? m.fullName : nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? m.phone : phoneCtrl.text.trim(),
      commune: communeCtrl.text.trim(),
      quartier: quarterCtrl.text.trim(),
      zone: zoneCtrl.text.trim(),
      addressLine: addressCtrl.text.trim(),
      role: selectedRole,
    );

    try {
      await _updateMemberApi(token: _token, member: updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre mis à jour.')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    await _reload();
  }

  Future<void> _openMemberDetails(Member m) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 6),
              Text('Code: ${m.id}'),
              Text('Téléphone: ${m.phone}'),
              Text('Commune: ${m.commune}'),
              Text('Quartier: ${m.quartier}'),
              Text('Zone: ${m.zone}'),
              Text('Rôle/Fonction: ${m.role}'),
              const SizedBox(height: 12),
              if (_isAdmin)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _editMember(m);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier ce membre'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _validateMemberApi({
    required String token,
    required String memberNumber,
    required bool validated,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');
    if (memberNumber.trim().isEmpty) throw StateError('memberNumber manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/validate');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'member_number': memberNumber.trim(),
            'validated': validated,
          }),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API')
          .toString();
      throw StateError(detail);
    }
  }

  Future<void> _setMemberStatusApi({
    required String token,
    required String memberNumber,
    required String status,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');
    if (memberNumber.trim().isEmpty) throw StateError('memberNumber manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/status');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'member_number': memberNumber.trim(),
            'status': status,
          }),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString();
      throw StateError(detail);
    }
  }

  Future<void> _deleteMemberApi({
    required String token,
    required String memberNumber,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');
    if (memberNumber.trim().isEmpty) throw StateError('memberNumber manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/delete');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'member_number': memberNumber.trim()}),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString();
      throw StateError(detail);
    }
  }

  Future<void> _updateMemberApi({
    required String token,
    required Member member,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');
    final uri = Uri.parse('${Config.baseUrl}/church/members/update');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'member_number': member.id,
            'full_name': member.fullName,
            'phone': member.phone,
            'commune': member.commune,
            'quarter': member.quartier,
            'zone': member.zone,
            'address_line': member.addressLine,
            'role_name': member.role,
          }),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString();
      throw StateError(detail);
    }
  }

  Future<List<Member>> _fetchMembersFromApi({
    required String token,
    required bool pendingOnly,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/list').replace(
      queryParameters: {
        if (pendingOnly) 'pending_only': 'true',
      },
    );

    final res = await http
        .get(
          uri,
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API')
          .toString();
      throw StateError(detail);
    }

    final membersRaw = decoded['members'];
    if (membersRaw is! List) return <Member>[];

    return membersRaw
        .whereType<Map>()
        .map((m) => _memberFromApiMap(
              Map<String, dynamic>.from(m),
              churchCode: _churchCode,
            ))
        .toList();
  }

  Member _memberFromApiMap(
    Map<String, dynamic> m, {
    required String churchCode,
  }) {
    final isValidated = (m['is_validated'] ?? 0) == 1;
    final createdAtTs = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
    final statusRaw = (m['status'] ?? '').toString().trim().toLowerCase();
    final status = statusRaw == 'active'
        ? MemberStatus.active
        : statusRaw == 'suspended'
            ? MemberStatus.suspended
            : statusRaw == 'banned'
                ? MemberStatus.banned
                : (isValidated ? MemberStatus.active : MemberStatus.pending);

    return Member(
      id: (m['member_number'] ?? m['id'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      fullName: (m['full_name'] ?? '').toString(),
      sex: sexFromString(m['sex']?.toString()),
      maritalStatus: maritalFromString(m['marital_status']?.toString()),
      birthDateIso: (m['birth_date'] ?? m['date_of_birth'] ?? '').toString(),
      commune: (m['commune'] ?? '').toString(),
      quartier: (m['quarter'] ?? '').toString(),
      zone: (m['zone'] ?? '').toString(),
      addressLine: (m['address_line'] ?? '').toString(),
      neighborhood: (m['neighborhood'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      province: (m['province'] ?? '').toString(),
      churchCode: churchCode,
      role: 'membre',
      status: status,
      regularityTag: (m['regularity_tag'] ?? 'monitoring').toString(),
      regularityTrend: (m['regularity_trend'] ?? 'stable').toString(),
      regularityScore: (m['regularity_score'] as num?)?.toDouble(),
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtTs * 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Badge(
                  label: Text("$_pendingCount"),
                  isLabelVisible: _pendingCount > 0,
                  child: IconButton(
                    tooltip: "Membres à valider",
                    onPressed: _openPending,
                    icon: const Icon(Icons.verified_outlined),
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'self') await _openSelfRegister();
              if (v == 'import') await _openImportCsv();
              if (v == 'manual') await _openAddManual();
              if (v == 'pending') await _openPending();
              if (v == 'neighbors') await _openMyNeighbors();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'self',
                child: Text("Inscription (membre)"),
              ),
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'manual',
                  child: Text("Ajout manuel (admin)"),
                ),
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'pending',
                  child: Text("À valider (pending)"),
                ),
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'import',
                  child: Text("Import CSV (admin/pasteur)"),
                ),
              if (_isMember)
                const PopupMenuItem(
                  value: 'neighbors',
                  child: Text("Mes voisins"),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _churchCode.isEmpty
              ? const Center(
                  child: Text("Aucune église sélectionnée (churchCode vide)."))
              : Column(
                  children: [
                    if ((_error ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          hintText: "Rechercher (code, nom, téléphone...)",
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Tous'),
                            selected: _regularityFilter == 'all',
                            onSelected: (_) => setState(() => _regularityFilter = 'all'),
                          ),
                          ChoiceChip(
                            label: const Text('Plus réguliers'),
                            selected: _regularityFilter == 'regular',
                            onSelected: (_) => setState(() => _regularityFilter = 'regular'),
                          ),
                          ChoiceChip(
                            label: const Text('Moins réguliers'),
                            selected: _regularityFilter == 'monitoring',
                            onSelected: (_) => setState(() => _regularityFilter = 'monitoring'),
                          ),
                          ChoiceChip(
                            label: const Text('Irréguliers'),
                            selected: _regularityFilter == 'irregular',
                            onSelected: (_) => setState(() => _regularityFilter = 'irregular'),
                          ),
                          ChoiceChip(
                            label: const Text('En amélioration'),
                            selected: _trendFilter == 'improving',
                            onSelected: (_) => setState(() => _trendFilter = _trendFilter == 'improving' ? 'all' : 'improving'),
                          ),
                          ChoiceChip(
                            label: const Text('Rétrogradent'),
                            selected: _trendFilter == 'retrograding',
                            onSelected: (_) => setState(() => _trendFilter = _trendFilter == 'retrograding' ? 'all' : 'retrograding'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text("Aucun membre."))
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final m = items[i];
                                final title = "${m.id} • ${m.fullName}";
                                final subtitle = "${m.phone}\n"
                                    "${m.commune} • ${m.quartier} • ${m.zone}\n"
                                    "Rôle: ${m.role} • ${_regularityLabel(m)} (${m.regularityScore?.toStringAsFixed(0) ?? "-" }%) • ${_trendLabel(m)}"
                                    "${m.birthDateIso.isNotEmpty ? " • Âge: ${_ageFromIso(m.birthDateIso)}" : ""}";
                                return ListTile(
                                  title: Text(title,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(subtitle),
                                  isThreeLine: true,
                                  onTap: () => _openMemberDetails(m),
                                  trailing: _isAdmin
                                      ? PopupMenuButton<String>(
                                          onSelected: (v) async {
                                            if (v == 'edit') await _editMember(m);
                                            if (v == 'approve') await _approve(m);
                                            if (v == 'suspend') await _suspend(m);
                                            if (v == 'ban') await _ban(m);
                                            if (v == 'delete') await _delete(m);
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text("Modifier"),
                                            ),
                                            if (m.status == MemberStatus.pending)
                                              const PopupMenuItem(
                                                value: 'approve',
                                                child: Text("Valider"),
                                              ),
                                            const PopupMenuItem(
                                              value: 'suspend',
                                              child: Text("Suspendre"),
                                            ),
                                            const PopupMenuItem(
                                              value: 'ban',
                                              child: Text("Bannir"),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text("Supprimer"),
                                            ),
                                          ],
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openAddManual,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("Ajouter"),
            )
          : FloatingActionButton.extended(
              onPressed: _openSelfRegister,
              icon: const Icon(Icons.person_add),
              label: const Text("S'inscrire"),
            ),
    );
  }
}

int _ageFromIso(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return 0;
  final now = DateTime.now();
  var age = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
  return age < 0 ? 0 : age;
}

