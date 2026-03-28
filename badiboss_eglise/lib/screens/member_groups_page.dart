import 'package:flutter/material.dart';
import '../auth/access_control.dart';
import '../auth/permissions.dart';
import '../auth/stores/session_store.dart';
import '../models/member.dart';
import '../services/church_api.dart';
import '../services/member_directory_service.dart';
import '../widgets/member_picker_dialog.dart';

final class MemberGroupsPage extends StatefulWidget {
  const MemberGroupsPage({super.key});
  static const routeName = '/member/groups';

  @override
  State<MemberGroupsPage> createState() => _MemberGroupsPageState();
}

final class _MemberGroupsPageState extends State<MemberGroupsPage> {
  List<_Group> _groups = <_Group>[];
  List<_GroupRequest> _requests = <_GroupRequest>[];
  List<Member> _members = <Member>[];
  String _phone = '';
  String _church = '';
  String _roleName = '';
  bool _canManage = false;
  bool _canView = true;
  bool get _canCreateGroup =>
      _roleName == 'pasteur' || _roleName == 'admin' || _roleName == 'super_admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await const SessionStore().read();
    _phone = (s?.phone ?? '').trim();
    _church = (s?.churchCode ?? '').trim();
    if (s != null) {
      _roleName = s.roleName;
      _canManage = await AccessControl.has(s, Permissions.manageGroups);
      _canView = await AccessControl.has(s, Permissions.viewGroups);
    }
    _groups = <_Group>[];
    _requests = <_GroupRequest>[];
    var fromServer = false;
    try {
      final dec = await ChurchApi.getJson('/church/documents/member_groups');
      final pay = dec['payload'];
      if (pay is Map) {
        final g = pay['groups'];
        final r = pay['requests'];
        if (g is List && g.isNotEmpty) {
          fromServer = true;
          _groups = g
              .whereType<Map>()
              .map((e) => _Group.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
        if (r is List) {
          _requests = r
              .whereType<Map>()
              .map((e) => _GroupRequest.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    } catch (_) {}
    if (!fromServer) {
      _groups = <_Group>[
        _Group(id: 'jeunes', name: 'Jeunes', leaderPhone: '', leaderName: '', leaderRoleLabel: '', churchCode: _church, memberIds: <String>[]),
        _Group(id: 'papas', name: 'Papas', leaderPhone: '', leaderName: '', leaderRoleLabel: '', churchCode: _church, memberIds: <String>[]),
        _Group(id: 'mamans', name: 'Mamans', leaderPhone: '', leaderName: '', leaderRoleLabel: '', churchCode: _church, memberIds: <String>[]),
        _Group(id: 'musiciens', name: 'Musiciens', leaderPhone: '', leaderName: '', leaderRoleLabel: '', churchCode: _church, memberIds: <String>[]),
      ];
      try {
        await _persist();
      } catch (_) {}
    }
    _members = await const MemberDirectoryService().loadMembersForActiveChurch();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _persist() async {
    await ChurchApi.postJson('/church/documents/member_groups', {
      'payload': {
        'groups': _groups.map((e) => e.toMap()).toList(),
        'requests': _requests.map((e) => e.toMap()).toList(),
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return const Scaffold(body: Center(child: Text('Accès refusé aux groupes.')));
    }
    final myReq = _requests.where((r) => r.memberPhone == _phone).toList();
    final pending = _requests.where((r) => r.status == 'pending').toList();
    final canSeeValidation = _canManage || pending.any((r) => _canValidateForGroup(r.groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Groupes')),
      floatingActionButton: (_canManage || _canCreateGroup)
          ? FloatingActionButton.extended(
              onPressed: _createGroup,
              icon: const Icon(Icons.group_add_rounded),
              label: const Text('Nouveau groupe'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ..._groups.map((g) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Responsable: ${g.leaderName.isEmpty ? "-" : "${g.leaderName} (${g.leaderRoleLabel})"}'),
                      Text('Membres: ${g.memberIds.length}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () {
                              _requests.insert(
                                0,
                                _GroupRequest(
                                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                                  groupId: g.id,
                                  memberPhone: _phone,
                                  status: 'pending',
                                ),
                              );
                              _persist().then((_) => setState(() {}));
                            },
                            child: const Text('Demander'),
                          ),
                          OutlinedButton(
                            onPressed: () => _openGroupMembers(g),
                            child: const Text('Membres'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          if (_canManage || _canCreateGroup)
            ..._groups.map((g) => ListTile(
                  title: Text('Responsable: ${g.name}'),
                  subtitle: Text(g.leaderName.isEmpty ? 'Aucun responsable' : '${g.leaderName} • ${g.leaderPhone}'),
                  trailing: OutlinedButton(
                    onPressed: () => _assignLeader(g),
                    child: const Text('Définir'),
                  ),
                )),
          const SizedBox(height: 8),
          const Text('Mes demandes', style: TextStyle(fontWeight: FontWeight.w700)),
          ...myReq.map((r) => ListTile(title: Text(r.groupId), subtitle: Text(r.status))),
          if (canSeeValidation) ...[
            const Divider(),
            const Text('Validation responsable', style: TextStyle(fontWeight: FontWeight.w700)),
            ...pending.map((r) => ListTile(
                  title: Text('${r.memberPhone} -> ${r.groupId}'),
                  subtitle: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          if (!_canValidateForGroup(r.groupId)) return;
                          r.status = 'rejected';
                          _persist().then((_) => setState(() {}));
                        },
                        child: const Text('Rejeter'),
                      ),
                      FilledButton(
                        onPressed: () {
                          if (!_canValidateForGroup(r.groupId)) return;
                          r.status = 'approved';
                          _persist().then((_) => setState(() {}));
                        },
                        child: const Text('Valider'),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  bool _canValidateForGroup(String groupId) {
    if (_canManage) return true;
    final g = _firstGroupOrNull(groupId);
    return g != null && g.leaderPhone.trim() == _phone.trim();
  }

  Future<void> _assignLeader(_Group g) async {
    Member? selected = _firstMemberByPhone(g.leaderPhone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Définir responsable (${g.name})'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  dense: true,
                  title: Text(selected == null ? 'Choisir un membre responsable' : '${selected!.id} • ${selected!.fullName}'),
                  subtitle: const Text('Recherche par nom, code membre ou téléphone'),
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final picked = await showMemberPickerDialog(context, members: _members, title: 'Responsable du groupe');
                    if (picked == null) return;
                    setLocal(() => selected = picked);
                  },
                ),
                if (_canManage || _canCreateGroup)
                  TextButton.icon(
                    onPressed: () {
                      final me = _firstMemberByPhone(_phone);
                      if (me != null) {
                        setLocal(() => selected = me);
                      }
                    },
                    icon: const Icon(Icons.person_pin_circle_outlined),
                    label: const Text('Me définir comme responsable'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true || selected == null) return;
    final idx = _groups.indexWhere((x) => x.id == g.id);
    if (idx < 0) return;
    _groups[idx] = _groups[idx].copyWith(
      leaderPhone: selected!.phone,
      leaderName: selected!.fullName,
      leaderRoleLabel: selected!.role,
    );
    await _persist();
    if (mounted) setState(() {});
  }

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    Member? selected;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Créer un nouveau groupe'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du groupe')),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  title: Text(selected == null ? 'Choisir le responsable' : '${selected!.id} • ${selected!.fullName}'),
                  subtitle: const Text('Sélection depuis la liste des membres'),
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final m = await showMemberPickerDialog(context, members: _members, title: 'Responsable du groupe');
                    if (m != null) setLocal(() => selected = m);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_');
    _groups.insert(
      0,
      _Group(
        id: '${id}_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        leaderPhone: selected?.phone ?? '',
        leaderName: selected?.fullName ?? '',
        leaderRoleLabel: selected?.role ?? '',
        churchCode: _church,
        memberIds: <String>[],
      ),
    );
    await _persist();
    if (mounted) setState(() {});
  }

  Future<void> _openGroupMembers(_Group g) async {
    if (_members.isEmpty) {
      _members = await const MemberDirectoryService().loadMembersForActiveChurch();
    }
    final byCategory = <String, List<Member>>{};
    for (final m in _members) {
      final cat = m.role.trim().isEmpty ? 'autres' : m.role.trim().toLowerCase();
      byCategory.putIfAbsent(cat, () => <Member>[]).add(m);
    }
    String selectedCategory = 'all';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final visible = selectedCategory == 'all'
              ? _members
              : (byCategory[selectedCategory] ?? <Member>[]);
          final categoryKeys = byCategory.keys.toList()..sort();
          return AlertDialog(
            title: Text('Membres du groupe: ${g.name}'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Filtrer catégorie / critère'),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Tous')),
                      ...categoryKeys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
                    ],
                    onChanged: (v) => setLocal(() => selectedCategory = v ?? 'all'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 280,
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final m = visible[i];
                        final inGroup = g.memberIds.contains(m.id);
                        return CheckboxListTile(
                          value: inGroup,
                          title: Text('${m.id} • ${m.fullName}'),
                          subtitle: Text('${m.phone} • ${m.role}'),
                          onChanged: (v) {
                            final idx = _groups.indexWhere((x) => x.id == g.id);
                            if (idx < 0) return;
                            final ids = List<String>.from(_groups[idx].memberIds);
                            if (v == true && !ids.contains(m.id)) ids.add(m.id);
                            if (v == false) ids.remove(m.id);
                            _groups[idx] = _groups[idx].copyWith(memberIds: ids);
                            setLocal(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Appliquer')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    await _persist();
    if (mounted) setState(() {});
  }

  _Group? _firstGroupOrNull(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Member? _firstMemberByPhone(String phone) {
    final p = phone.trim();
    for (final m in _members) {
      if (m.phone.trim() == p) return m;
    }
    return null;
  }
}

final class _Group {
  final String id;
  final String name;
  final String leaderPhone;
  final String leaderName;
  final String leaderRoleLabel;
  final String churchCode;
  final List<String> memberIds;
  const _Group({
    required this.id,
    required this.name,
    required this.leaderPhone,
    required this.leaderName,
    required this.leaderRoleLabel,
    required this.churchCode,
    required this.memberIds,
  });
  _Group copyWith({String? leaderPhone, String? leaderName, String? leaderRoleLabel, List<String>? memberIds}) => _Group(
        id: id,
        name: name,
        leaderPhone: leaderPhone ?? this.leaderPhone,
        leaderName: leaderName ?? this.leaderName,
        leaderRoleLabel: leaderRoleLabel ?? this.leaderRoleLabel,
        churchCode: churchCode,
        memberIds: memberIds ?? this.memberIds,
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'leaderPhone': leaderPhone,
        'leaderName': leaderName,
        'leaderRoleLabel': leaderRoleLabel,
        'churchCode': churchCode,
        'memberIds': memberIds,
      };
  static _Group fromMap(Map<String, dynamic> m) => _Group(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        leaderPhone: (m['leaderPhone'] ?? '').toString(),
        leaderName: (m['leaderName'] ?? '').toString(),
        leaderRoleLabel: (m['leaderRoleLabel'] ?? '').toString(),
        churchCode: (m['churchCode'] ?? '').toString(),
        memberIds: ((m['memberIds'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(),
      );
}

final class _GroupRequest {
  final String id;
  final String groupId;
  final String memberPhone;
  String status;
  _GroupRequest({required this.id, required this.groupId, required this.memberPhone, required this.status});
  Map<String, dynamic> toMap() => {'id': id, 'groupId': groupId, 'memberPhone': memberPhone, 'status': status};
  static _GroupRequest fromMap(Map<String, dynamic> m) => _GroupRequest(
        id: (m['id'] ?? '').toString(),
        groupId: (m['groupId'] ?? '').toString(),
        memberPhone: (m['memberPhone'] ?? '').toString(),
        status: (m['status'] ?? 'pending').toString(),
      );
}
