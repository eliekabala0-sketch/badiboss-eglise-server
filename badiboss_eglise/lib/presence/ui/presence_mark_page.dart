import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../models/member.dart';
import '../../services/local_members_store.dart';
import '../models/activity.dart';
import '../models/presence_entry.dart';
import '../stores/activities_store.dart';
import '../stores/presence_store.dart';
import '../../core/config.dart';
import '../../core/phone_rd_congo.dart';
import '../../services/church_service.dart';
import 'presence_camera_body.dart';

final class PresenceMarkPage extends StatefulWidget {
  const PresenceMarkPage({super.key});

  static const String routeName = '/presence/mark';

  @override
  State<PresenceMarkPage> createState() => _PresenceMarkPageState();
}

final class _PresenceMarkPageState extends State<PresenceMarkPage> {
  AppSession? _session;
  String _status = '';
  bool _loading = false;

  final _superAdminChurchCtrl = TextEditingController();

  Activity? _currentActivity;
  final _phoneCtrl = TextEditingController();
  final _memberCodeCtrl = TextEditingController();
  final _scanCtrl = TextEditingController();
  final _guestNameCtrl = TextEditingController();

  List<Member> _members = <Member>[];
  String _memberQuery = '';
  Member? _selectedMember;

  int _modeIndex = 0; // 0=code, 1=phone, 2=list, 3=scan

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final s = await const SessionStore().read();
      if (!mounted) return;
      setState(() => _session = s);
      await _reload();
      if (mounted) _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _status = 'Session introuvable.';
      });
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _silentReload());
  }

  /// Rafraîchit activité ouverte + liste membres (multi-postes / nouveaux membres).
  Future<void> _silentReload() async {
    if (!mounted || _session == null || _loading) return;
    final cc = _effectiveChurchCode();
    final s = _session;
    if (cc == null || s == null) return;
    try {
      final open = await _fetchOpenEventAsActivity(token: s.token, churchCode: cc);
      final members = await _fetchMembersFromApi(token: s.token, churchCode: cc);
      if (!mounted) return;
      setState(() {
        _currentActivity = open;
        _members = members;
      });
    } catch (_) {}
  }

  String? _effectiveChurchCode() {
    final s = _session;
    if (s == null) return null;
    if (s.churchCode != null && s.churchCode!.trim().isNotEmpty) return s.churchCode!.trim();

    // SUPER ADMIN: doit préciser une église pour travailler sur présences
    final cc = _superAdminChurchCtrl.text.trim();
    if (cc.isNotEmpty) return cc;
    final scoped = ChurchService.getChurchCode().trim();
    if (scoped.isNotEmpty) return scoped;
    return null;
  }

  Future<void> _reload() async {
    final cc = _effectiveChurchCode();
    if (cc == null) {
      setState(() {
        _currentActivity = null;
        _status = 'churchCode requis (SUPER ADMIN: saisir).';
      });
      return;
    }

    final s = _session;
    if (s == null) return;
    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final open = await _fetchOpenEventAsActivity(token: s.token, churchCode: cc);
      final members = await _fetchMembersFromApi(token: s.token, churchCode: cc);
      if (!mounted) return;
      setState(() {
        _currentActivity = open;
        _status = (open == null) ? 'Aucune activité OPEN. Lance une activité d’abord.' : '';
        _members = members;
        _selectedMember = null;
        _loading = false;
      });
    } catch (_) {
      // fallback local
      final open = await const ActivitiesStore().findOpen(cc);
      final members = await LocalMembersStore.loadByChurch(cc);
      if (!mounted) return;
      setState(() {
        _currentActivity = open;
        _status = (open == null)
            ? 'Aucune activité OPEN. Lance une activité d’abord.'
            : 'API indisponible : activité locale utilisée.';
        _members = members;
        _selectedMember = null;
        _loading = false;
      });
    }
  }

  Future<void> _markPresence() async {
    final s = _session;
    final cc = _effectiveChurchCode();
    final a = _currentActivity;

    if (s == null || cc == null) {
      setState(() => _status = 'Session/churchCode manquant.');
      return;
    }
    if (a == null) {
      setState(() => _status = 'Aucune activité OPEN.');
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final eventId = int.tryParse(a.id);
      if (eventId == null) throw StateError('event_id invalide');

      // Résolution membre selon mode (membre)
      final Member? mem = await _resolveMemberForMark(
        token: s.token,
        churchCode: cc,
      );
      if (mem == null) {
        setState(() {
          _loading = false;
          _status = 'Membre introuvable (vérifie code/téléphone).';
        });
        return;
      }

      await _markAttendanceApi(
        token: s.token,
        eventId: eventId,
        memberNumber: mem.id,
        guestName: null,
      );

      _phoneCtrl.clear();
      _memberCodeCtrl.clear();
      _scanCtrl.clear();
      _guestNameCtrl.clear();
      _selectedMember = null;
      setState(() {
        _loading = false;
        _status = 'Présence enregistrée: ${mem.fullName}';
      });
      unawaited(_silentReload());
      return;
    } catch (e) {
      if (e is StateError) {
        setState(() {
          _loading = false;
          _status = e.message;
        });
        return;
      }
    }

    final member = _resolveMemberLocalFallback(cc);
    if (member == null) {
      setState(() {
        _loading = false;
        _status = 'Membre introuvable (fallback local).';
      });
      return;
    }
    final entry = PresenceEntry(
      id: 'pres_${DateTime.now().millisecondsSinceEpoch}',
      churchCode: cc,
      activityId: a.id,
      memberId: member.id,
      memberPhone: member.phone,
      memberName: member.fullName,
      markedByPhone: s.phone,
      markedAt: DateTime.now(),
    );
    await const PresenceStore().upsert(entry);

    _phoneCtrl.clear();
    _memberCodeCtrl.clear();
    _scanCtrl.clear();
    _selectedMember = null;
    setState(() {
      _loading = false;
      _status = 'Présence enregistrée (local): ${member.fullName}';
    });
    unawaited(_silentReload());
  }

  Future<void> _markGuestPresence() async {
    final s = _session;
    final cc = _effectiveChurchCode();
    final a = _currentActivity;
    final name = _guestNameCtrl.text.trim();

    if (s == null || cc == null) {
      setState(() => _status = 'Session/churchCode manquant.');
      return;
    }
    if (a == null) {
      setState(() => _status = 'Aucune activité OPEN.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _status = 'Nom invité requis.');
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final eventId = int.tryParse(a.id);
      if (eventId == null) throw StateError('event_id invalide');

      await _markAttendanceApi(
        token: s.token,
        eventId: eventId,
        memberNumber: null,
        guestName: name,
      );

      _guestNameCtrl.clear();
      setState(() {
        _loading = false;
        _status = 'Présence invité enregistrée: $name';
      });
      unawaited(_silentReload());
    } catch (e) {
      final msg = e is StateError ? e.message : 'Erreur pointage invité.';
      setState(() {
        _loading = false;
        _status = msg;
      });
    }
  }

  Future<Member?> _resolveMemberForMark({
    required String token,
    required String churchCode,
  }) async {
    // API-first: on utilise la liste déjà chargée si dispo; sinon on recharge
    List<Member> members = _members;
    if (members.isEmpty) {
      members = await _fetchMembersFromApi(token: token, churchCode: churchCode);
      if (mounted) setState(() => _members = members);
    }

    if (_modeIndex == 0) {
      final code = _memberCodeCtrl.text.trim();
      if (code.isEmpty) return null;
      return members.where((m) => m.id.trim().toUpperCase() == code.toUpperCase()).cast<Member?>().firstWhere(
            (x) => x != null,
            orElse: () => null,
          );
    }

    if (_modeIndex == 1) {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty) return null;
      for (final m in members) {
        if (phonesMatchRdCongo(phone, m.phone)) return m;
      }
      return null;
    }

    if (_modeIndex == 2) {
      return _selectedMember;
    }

    // scan mode
    final raw = _scanCtrl.text.trim();
    if (raw.isEmpty) return null;
    final parsed = _parseScanPayload(raw);
    if (parsed == null) return null;
    if (parsed.type == _ScanType.memberCode) {
      final code = parsed.value.trim();
      if (code.isEmpty) return null;
      return members.where((m) => m.id.trim().toUpperCase() == code.toUpperCase()).cast<Member?>().firstWhere(
            (x) => x != null,
            orElse: () => null,
          );
    }
    if (parsed.type == _ScanType.phone) {
      final phone = parsed.value.trim();
      if (phone.isEmpty) return null;
      for (final m in members) {
        if (phonesMatchRdCongo(phone, m.phone)) return m;
      }
      return null;
    }
    return null;
  }

  Member? _resolveMemberLocalFallback(String churchCode) {
    final members = _members.isNotEmpty ? _members : <Member>[];

    if (_modeIndex == 0) {
      final code = _memberCodeCtrl.text.trim();
      if (code.isEmpty) return null;
      for (final m in members) {
        if (m.id.trim().toUpperCase() == code.toUpperCase()) return m;
      }
      return null;
    }

    if (_modeIndex == 1) {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty) return null;
      for (final m in members) {
        if (phonesMatchRdCongo(phone, m.phone)) return m;
      }
      return null;
    }

    if (_modeIndex == 2) {
      return _selectedMember;
    }

    final raw = _scanCtrl.text.trim();
    final parsed = _parseScanPayload(raw);
    if (parsed == null) return null;
    for (final m in members) {
      if (parsed.type == _ScanType.memberCode && m.id.trim().toUpperCase() == parsed.value.toUpperCase()) return m;
      if (parsed.type == _ScanType.phone &&
          phonesMatchRdCongo(parsed.value, m.phone)) return m;
    }
    return null;
  }

  List<Member> get _filteredMembers {
    final q = _memberQuery.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members.where((m) {
      final blob = '${m.id} ${m.fullName} ${m.phone} ${m.quartier} ${m.commune} ${m.zone}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  Future<List<Member>> _fetchMembersFromApi({
    required String token,
    required String churchCode,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/members/list');
    final res = await http
        .get(uri, headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
    }
    final list = decoded['members'];
    if (list is! List) return <Member>[];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return Member(
        id: (m['member_number'] ?? m['id'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        fullName: (m['full_name'] ?? '').toString(),
        sex: sexFromString(m['sex']?.toString()),
        maritalStatus: maritalFromString(m['marital_status']?.toString()),
        commune: (m['commune'] ?? '').toString(),
        quartier: (m['quarter'] ?? '').toString(),
        zone: (m['zone'] ?? '').toString(),
        addressLine: (m['address_line'] ?? '').toString(),
        neighborhood: (m['neighborhood'] ?? '').toString(),
        region: (m['region'] ?? '').toString(),
        province: (m['province'] ?? '').toString(),
        churchCode: churchCode,
        role: 'membre',
        status: statusFromString(m['status']?.toString()),
        createdBy: '',
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  Future<Activity?> _fetchOpenEventAsActivity({
    required String token,
    required String churchCode,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/attendance/events/list');
    final res = await http
        .get(uri, headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
    }
    final list = decoded['events'];
    if (list is! List) return null;
    for (final e in list) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (status == 'open') {
          final id = (m['id'] ?? 0).toString();
          final title = (m['title'] ?? 'Activité').toString();
          final createdAt = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
          return Activity(
            id: id,
            churchCode: churchCode,
            title: title,
            type: 'culte',
            status: ActivityStatus.open,
            createdByPhone: '',
            startedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
            closedAt: null,
          );
        }
      }
    }
    return null;
  }

  Future<void> _markAttendanceApi({
    required String token,
    required int eventId,
    String? memberNumber,
    String? guestName,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/attendance/mark');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'event_id': eventId,
            if (memberNumber != null) 'member_number': memberNumber,
            if (guestName != null) 'guest_name': guestName,
            'present': true,
          }),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? decoded['message'] ?? 'Erreur API').toString());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _superAdminChurchCtrl.dispose();
    _phoneCtrl.dispose();
    _memberCodeCtrl.dispose();
    _scanCtrl.dispose();
    _guestNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Pointer présence'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: (s == null)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: _modeIndex == 2
                      ? _buildListModeBody(s)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _buildScrollableMarkContent(s),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: (s == null)
          ? null
          : PermissionGate(
              permission: Permissions.markPresence,
              child: Material(
                elevation: 10,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_status.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: _status.startsWith('Présence')
                                    ? Colors.green.shade800
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        TextField(
                          controller: _guestNameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nom invité (optionnel si membre)',
                            hintText: 'Ex: Jean Dupont',
                            isDense: true,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person_add_alt_1_outlined,
                                size: 20),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _loading ? null : _markPresence,
                                icon: const Icon(Icons.badge_outlined, size: 20),
                                label: const Text('Membre'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _markGuestPresence,
                                icon: const Icon(Icons.person_add_alt_1, size: 20),
                                label: const Text('Invité'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildScrollableMarkContent(AppSession s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${s.phone} • ${s.churchCode ?? "SUPER_ADMIN"}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        if (s.churchCode == null) ...[
          TextField(
            controller: _superAdminChurchCtrl,
            decoration: const InputDecoration(
              labelText: 'Code église',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _reload(),
          ),
          const SizedBox(height: 12),
        ],
        if (_currentActivity != null)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.green.shade200),
            ),
            child: ListTile(
              leading: Icon(Icons.event_available, color: Colors.green.shade700),
              title: Text(_currentActivity!.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Ouverte • ${_currentActivity!.startedAt}'),
            ),
          )
        else
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Aucune activité ouverte'),
              subtitle: Text(
                  _status.isEmpty ? 'Lance une activité depuis Présences.' : _status),
            ),
          ),
        const SizedBox(height: 12),
        const Text('Mode', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Code')),
            ButtonSegment(value: 1, label: Text('Tél.')),
            ButtonSegment(value: 2, label: Text('Liste')),
            ButtonSegment(value: 3, label: Text('Scan')),
          ],
          selected: <int>{_modeIndex},
          onSelectionChanged: (sel) => setState(() {
            _modeIndex = sel.first;
            if (_status.startsWith('Présence')) _status = '';
          }),
        ),
        const SizedBox(height: 12),
        if (_modeIndex == 0)
          TextField(
            controller: _memberCodeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Code membre',
              hintText: 'M001',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
        if (_modeIndex == 1)
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone (09… ou +243…)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        if (_modeIndex == 3)
          Column(
            children: [
              TextField(
                controller: _scanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Scan / collage',
                  hintText: 'MEMBER:M001',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_scanner),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openCameraScanner,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scanner avec caméra'),
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fallback disponible: saisie manuelle dans le champ ci-dessus.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildListModeBody(AppSession s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${s.phone} • ${s.churchCode ?? "SUPER_ADMIN"}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (s.churchCode == null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _superAdminChurchCtrl,
              decoration: const InputDecoration(
                labelText: 'Code église',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _reload(),
            ),
          ],
          const SizedBox(height: 8),
          if (_currentActivity != null)
            Text(_currentActivity!.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Liste membres', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Rechercher',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _memberQuery = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _filteredMembers.length,
                itemBuilder: (context, i) {
                  final m = _filteredMembers[i];
                  final selected = _selectedMember?.id == m.id;
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    selected: selected,
                    title: Text(
                      '${m.id} • ${m.fullName}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(m.phone, style: const TextStyle(fontSize: 12)),
                    trailing:
                        selected ? Icon(Icons.check_circle, color: Colors.green.shade700) : null,
                    onTap: () => setState(() => _selectedMember = m),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Code')),
              ButtonSegment(value: 1, label: Text('Tél.')),
              ButtonSegment(value: 2, label: Text('Liste')),
              ButtonSegment(value: 3, label: Text('Scan')),
            ],
            selected: <int>{_modeIndex},
            onSelectionChanged: (sel) => setState(() {
              _modeIndex = sel.first;
            }),
          ),
        ],
      ),
    );
  }
}

extension on _PresenceMarkPageState {
  Future<void> _openCameraScanner() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _CameraScanPage()),
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    setState(() {
      _scanCtrl.text = value.trim();
      _modeIndex = 3;
      _status = 'QR détecté, prêt pour validation.';
    });
  }
}

final class _CameraScanPage extends StatefulWidget {
  const _CameraScanPage();

  @override
  State<_CameraScanPage> createState() => _CameraScanPageState();
}

final class _CameraScanPageState extends State<_CameraScanPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner caméra')),
      body: PresenceCameraBody(
        onDetected: (code) {
          Navigator.of(context).pop(code);
        },
      ),
    );
  }
}

enum _ScanType { memberCode, phone }

final class _ScanPayload {
  final _ScanType type;
  final String value;
  const _ScanPayload(this.type, this.value);
}

_ScanPayload? _parseScanPayload(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final up = s.toUpperCase();

  if (up.startsWith('MEMBER:') || up.startsWith('CODE:')) {
    final v = s.split(':').skip(1).join(':').trim();
    if (v.isEmpty) return null;
    return _ScanPayload(_ScanType.memberCode, v);
  }
  if (up.startsWith('TEL:') || up.startsWith('PHONE:')) {
    final v = s.split(':').skip(1).join(':').trim();
    if (v.isEmpty) return null;
    return _ScanPayload(_ScanType.phone, v);
  }

  // fallback: si ressemble à M001 => code, sinon => téléphone
  final looksLikeCode = RegExp(r'^[Mm]\d{2,}$').hasMatch(s);
  if (looksLikeCode) return _ScanPayload(_ScanType.memberCode, s);
  final looksLikePhone = RegExp(r'^[+0-9]{6,}$').hasMatch(s);
  if (looksLikePhone) return _ScanPayload(_ScanType.phone, s);

  return null;
}
