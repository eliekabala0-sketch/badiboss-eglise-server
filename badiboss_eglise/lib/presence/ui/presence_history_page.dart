import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../core/config.dart';
import '../../services/church_service.dart';
import '../models/activity.dart';
import '../models/presence_entry.dart';

final class PresenceHistoryPage extends StatefulWidget {
  const PresenceHistoryPage({super.key});

  static const String routeName = '/presence/history';

  @override
  State<PresenceHistoryPage> createState() => _PresenceHistoryPageState();
}

final class _PresenceHistoryPageState extends State<PresenceHistoryPage> {
  AppSession? _session;
  String _status = '';
  bool _loading = true;

  final _superAdminChurchCtrl = TextEditingController();

  List<Activity> _activities = <Activity>[];
  Activity? _selected;

  List<PresenceEntry> _items = <PresenceEntry>[];
  final _qCtrl = TextEditingController();
  Map<String, String> _memberNameByNumber = <String, String>{};
  int _totalCount = 0;
  int _membersCount = 0;
  int _guestsCount = 0;
  bool _memberScopedList = false;

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _session == null) return;
      if (!_memberScopedList && _selected == null) return;
      unawaited(_reloadPresence());
    });
  }

  Future<void> _load() async {
    try {
      final s = await const SessionStore().read();
      if (!mounted) return;
      setState(() => _session = s);
      await _reloadActivities();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _status = 'Session introuvable.';
      });
    }
  }

  bool _isMemberSession(AppSession? s) {
    if (s == null) return false;
    final rn = s.roleName.toLowerCase().trim();
    return s.role.toJson() == 'membre' || rn == 'membre' || rn == 'member';
  }

  String? _effectiveChurchCode() {
    final s = _session;
    if (s == null) return null;
    if (s.churchCode != null && s.churchCode!.trim().isNotEmpty) return s.churchCode!.trim();

    final cc = _superAdminChurchCtrl.text.trim();
    if (cc.isNotEmpty) return cc;
    final scoped = ChurchService.getChurchCode().trim();
    if (scoped.isNotEmpty) return scoped;
    return null;
  }

  Future<void> _reloadActivities() async {
    final cc = _effectiveChurchCode();
    final s = _session;
    if (cc == null || s == null) {
      setState(() {
        _activities = <Activity>[];
        _selected = null;
        _items = <PresenceEntry>[];
        _status = 'churchCode requis (SUPER ADMIN: saisir).';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      if (_isMemberSession(s)) {
        _memberScopedList = true;
        await _reloadMyAttendanceOnly(token: s.token, churchCode: cc);
        if (!mounted) return;
        setState(() {
          _activities = <Activity>[];
          _selected = null;
        });
        return;
      }
      _memberScopedList = false;

      final acts = await _fetchEventsFromApi(token: s.token, churchCode: cc);
      final names = await _fetchMemberNames(token: s.token);
      if (!mounted) return;

      setState(() {
        _memberNameByNumber = names;
        _activities = acts;
        _selected = acts.isEmpty ? null : acts.first;
        _status = acts.isEmpty ? 'Aucune activité.' : '';
      });

      await _reloadPresence();
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : e.toString();
      setState(() {
        _activities = <Activity>[];
        _selected = null;
        _items = <PresenceEntry>[];
        _status = 'Erreur serveur: $msg';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadMyAttendanceOnly({
    required String token,
    required String churchCode,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/me/attendance');
    final res = await http
        .get(uri, headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode == 403) {
      throw StateError((decoded['detail'] ?? 'Compte non lié à un membre valide').toString());
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError((decoded['detail'] ?? 'Erreur API').toString());
    }
    final list = decoded['records'];
    final mn = (decoded['member_number'] ?? '').toString().trim();
    final out = <PresenceEntry>[];
    if (list is List) {
      for (final e in list) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final createdAt = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
        final evTitle = (m['event_title'] ?? '').toString().trim();
        final evDate = (m['event_date'] ?? '').toString().trim();
        final label = [evTitle, evDate].where((x) => x.isNotEmpty).join(' • ');
        out.add(
          PresenceEntry(
            id: 'me_${m['id'] ?? createdAt}',
            churchCode: churchCode,
            activityId: (m['event_id'] ?? '').toString(),
            memberId: (m['member_number'] ?? mn).toString(),
            memberPhone: '',
            memberName: label.isEmpty ? 'Activité' : label,
            markedByPhone: '',
            markedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
          ),
        );
      }
    }
    out.sort((a, b) => b.markedAt.compareTo(a.markedAt));
    if (!mounted) return;
    _applyStats(out);
    setState(() {
      _items = out;
      _status = out.isEmpty ? 'Aucune présence enregistrée pour votre compte.' : '';
    });
  }

  Future<void> _reloadPresence() async {
    final cc = _effectiveChurchCode();
    final a = _selected;
    if (_memberScopedList) {
      final s = _session;
      if (s == null || cc == null) return;
      try {
        await _reloadMyAttendanceOnly(token: s.token, churchCode: cc);
      } catch (e) {
        if (!mounted) return;
        final msg = e is StateError ? e.message : e.toString();
        setState(() => _status = 'Erreur serveur: $msg');
      }
      return;
    }
    if (cc == null || a == null) {
      setState(() => _items = <PresenceEntry>[]);
      return;
    }

    final s = _session;
    if (s == null) return;

    try {
      final eventId = int.parse(a.id);
      final list = await _fetchAttendanceRecordsAsPresence(
        token: s.token,
        churchCode: cc,
        eventId: eventId,
      );
      if (!mounted) return;
      _applyStats(list);
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : e.toString();
      setState(() {
        _items = <PresenceEntry>[];
        _status = 'Erreur serveur: $msg';
      });
    }
  }

  void _applyStats(List<PresenceEntry> list) {
    final total = list.length;
    final guests = list.where((p) => p.memberId == 'GUEST').length;
    final members = total - guests;
    _totalCount = total;
    _membersCount = members;
    _guestsCount = guests;
  }

  Future<Map<String, String>> _fetchMemberNames({required String token}) async {
    final uri = Uri.parse('${Config.baseUrl}/church/members/list');
    final res = await http
        .get(uri, headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) throw StateError('Erreur API');
    final list = decoded['members'];
    if (list is! List) return <String, String>{};
    final out = <String, String>{};
    for (final e in list) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final num = (m['member_number'] ?? '').toString();
        if (num.isEmpty) continue;
        out[num] = (m['full_name'] ?? '').toString();
      }
    }
    return out;
  }

  Future<List<Activity>> _fetchEventsFromApi({
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
    if (res.statusCode < 200 || res.statusCode >= 300) throw StateError('Erreur API');
    final list = decoded['events'];
    if (list is! List) return <Activity>[];
    return list.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      final id = (m['id'] ?? 0).toString();
      final title = (m['title'] ?? '').toString();
      final createdAt = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
      final status = activityStatusFromString(m['status']?.toString());
      final closedAtTs = int.tryParse((m['closed_at'] ?? '').toString());
      return Activity(
        id: id,
        churchCode: churchCode,
        title: title,
        type: 'culte',
        status: status,
        createdByPhone: '',
        startedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        closedAt: (closedAtTs == null) ? null : DateTime.fromMillisecondsSinceEpoch(closedAtTs * 1000),
      );
    }).toList();
  }

  Future<List<PresenceEntry>> _fetchAttendanceRecordsAsPresence({
    required String token,
    required String churchCode,
    required int eventId,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/attendance/list').replace(
      queryParameters: {'event_id': eventId.toString()},
    );
    final res = await http
        .get(uri, headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) throw StateError('Erreur API');
    final list = decoded['records'];
    if (list is! List) return <PresenceEntry>[];
    final out = <PresenceEntry>[];
    for (final e in list) {
      if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        final memberNumber = (m['member_number'] ?? '').toString();
        final guestName = (m['guest_name'] ?? '').toString();
        final createdAt = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
        final isGuest = memberNumber.isEmpty && guestName.isNotEmpty;
        final baseName = isGuest ? guestName : (_memberNameByNumber[memberNumber] ?? '');
        final displayName = isGuest ? '$baseName (invité)' : baseName;
        out.add(
          PresenceEntry(
            id: 'srv_${m['id'] ?? createdAt}',
            churchCode: churchCode,
            activityId: eventId.toString(),
            memberId: isGuest ? 'GUEST' : memberNumber,
            memberPhone: '',
            memberName: displayName,
            markedByPhone: '',
            markedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
          ),
        );
      }
    }
    out.sort((a, b) => b.markedAt.compareTo(a.markedAt));
    return out;
  }

  List<PresenceEntry> _filtered() {
    final q = _qCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items.where((p) {
      final blob = [
        p.memberName,
        p.memberPhone,
        p.memberId,
        p.markedByPhone,
      ].join(' | ').toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _superAdminChurchCtrl.dispose();
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final filtered = _filtered(); // ✅ figé (pas recalculé 2x)

    return Scaffold(
      appBar: AppBar(title: const Text('Historique présences')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? const Center(child: CircularProgressIndicator())
            : PermissionGate(
                permission: Permissions.viewPresenceHistory,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Session: ${s.phone} | role=${s.role.toJson()} | church=${s.churchCode ?? "-"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),

                    if (s.churchCode == null) ...[
                      TextField(
                        controller: _superAdminChurchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'churchCode (SUPER ADMIN)',
                        ),
                        onChanged: (_) => _reloadActivities(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 8),
                    if (_memberScopedList && _items.isNotEmpty)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Présences enregistrées: $_totalCount',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (!_memberScopedList && _selected != null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Text('Total: $_totalCount',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Membres: $_membersCount'),
                              Text('Invités: $_guestsCount'),
                            ],
                          ),
                        ),
                      ),

                    if (_memberScopedList)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Vue limitée à vos propres présences (compte membre).',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),

                    if (!_memberScopedList && _activities.isNotEmpty)
                      DropdownButton<Activity>(
                        isExpanded: true,
                        value: _selected,
                        items: _activities
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text('${a.title} • ${a.status.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (a) async {
                          setState(() => _selected = a);
                          await _reloadPresence();
                        },
                      ),
                    if (_loading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],

                    const SizedBox(height: 8),

                    TextField(
                      controller: _qCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Filtre (nom / téléphone)',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 10),

                    if (_status.trim().isNotEmpty)
                      Text(_status, style: const TextStyle(color: Colors.red)),

                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await _reloadActivities();
                        },
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final p = filtered[i];
                            return Card(
                              child: ListTile(
                                title: Text(p.memberName.isEmpty ? p.memberPhone : p.memberName),
                                subtitle: Text('Tel: ${p.memberPhone} • ${p.markedAt}'),
                                trailing: Text('Par ${p.markedByPhone}', style: const TextStyle(fontSize: 12)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
