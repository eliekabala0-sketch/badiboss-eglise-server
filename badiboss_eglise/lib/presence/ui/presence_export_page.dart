import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../stores/activities_store.dart';
import '../stores/presence_store.dart';
import '../../services/export_file_service.dart';

final class PresenceExportPage extends StatefulWidget {
  const PresenceExportPage({super.key});

  static const String routeName = '/presence/export';

  @override
  State<PresenceExportPage> createState() => _PresenceExportPageState();
}

final class _PresenceExportPageState extends State<PresenceExportPage> {
  AppSession? _session;
  String _status = '';
  bool _loading = false;

  final _superAdminChurchCtrl = TextEditingController();

  List<Activity> _activities = <Activity>[];
  Activity? _selected;

  String _csv = '';
  int _statTotal = 0;
  int _statMembers = 0;
  int _statGuests = 0;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (cc == null) {
      setState(() {
        _activities = <Activity>[];
        _selected = null;
        _csv = '';
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

    List<Activity> acts = <Activity>[];
    try {
      acts = await _fetchEventsFromApi(token: s.token, churchCode: cc);
    } catch (_) {
      acts = await const ActivitiesStore().load(cc);
      _status = 'API indisponible : export local.';
    }
    if (!mounted) return;

    Activity? sel = _selected;
    if (acts.isEmpty) {
      sel = null;
    } else {
      final exists = sel != null && acts.any((x) => x.id == sel!.id);
      sel = exists ? acts.firstWhere((x) => x.id == sel!.id) : acts.first;
    }

    setState(() {
      _activities = acts;
      _selected = sel;
      _status = acts.isEmpty ? 'Aucune activité.' : _status;
      _csv = '';
      _loading = false;
    });
  }

  String _escape(String s) {
    final v = s.replaceAll('"', '""');
    return '"$v"';
  }

  String _buildCsv(List<PresenceEntry> list, Activity a) {
    final lines = <String>[];
    lines.add('# stats_total=$_statTotal stats_members=$_statMembers stats_guests=$_statGuests');
    lines.add('activity_id,activity_title,member_id,member_name,member_phone,marked_at,marked_by');

    for (final p in list) {
      lines.add([
        _escape(a.id),
        _escape(a.title),
        _escape(p.memberId),
        _escape(p.memberName),
        _escape(p.memberPhone),
        _escape(p.markedAt.toIso8601String()),
        _escape(p.markedByPhone),
      ].join(','));
    }
    return lines.join('\n');
  }

  Future<void> _generate() async {
    final cc = _effectiveChurchCode();
    final a = _selected;
    if (cc == null || a == null) {
      setState(() => _status = 'Sélection activité/churchCode manquante.');
      return;
    }

    final s = _session;
    if (s == null) return;

    setState(() {
      _loading = true;
      _status = '';
    });

    List<PresenceEntry> list = <PresenceEntry>[];
    try {
      final eventId = int.parse(a.id);
      final names = await _fetchMemberNames(token: s.token);
      list = await _fetchAttendanceRecordsAsPresence(
        token: s.token,
        churchCode: cc,
        eventId: eventId,
        memberNameByNumber: names,
      );
    } catch (_) {
      list = await const PresenceStore().load(churchCode: cc, activityId: a.id);
    }

    final guests = list.where((p) => p.memberId == 'GUEST').length;
    final members = list.length - guests;
    final csv = _buildCsv(list, a);

    setState(() {
      _statTotal = list.length;
      _statMembers = members;
      _statGuests = guests;
      _csv = csv;
      _status =
          'Export prêt — Total: ${list.length} | Membres: $members | Invités: $guests';
      _loading = false;
    });
  }

  Future<void> _copy() async {
    if (_csv.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _csv));
    setState(() => _status = 'CSV copié dans le presse-papiers.');
  }

  Future<void> _downloadCsv() async {
    if (_csv.trim().isEmpty || _selected == null) return;
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'presence_${_selected!.id}_$ts.csv';
    final result = await ExportFileService.saveTextFile(
      fileName: fileName,
      content: _csv,
      openShareSheet: true,
    );
    if (!mounted) return;
    setState(() {
      _status = 'Fichier exporté: ${result.path}';
    });
  }

  @override
  void dispose() {
    _superAdminChurchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Exporter présences (CSV)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? const Center(child: CircularProgressIndicator())
            : PermissionGate(
                permission: Permissions.exportPresence,
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

                    if (_statTotal > 0 && _selected != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Wrap(
                              spacing: 16,
                              children: [
                                Text('Total: $_statTotal',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('Membres: $_statMembers'),
                                Text('Invités: $_statGuests'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_activities.isNotEmpty)
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
                        onChanged: (a) => setState(() {
                          _selected = a;
                          _csv = '';
                          _statTotal = 0;
                          _statMembers = 0;
                          _statGuests = 0;
                        }),
                      ),

                    const SizedBox(height: 10),
                    if (_loading) const LinearProgressIndicator(),
                    if (_loading) const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _generate,
                            child: const Text('Générer CSV'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _copy,
                            child: const Text('Copier'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _downloadCsv,
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Télécharger'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (_status.trim().isNotEmpty)
                      Text(
                        _status,
                        style: TextStyle(
                          color: _status.startsWith('Export') || _status.startsWith('CSV copié')
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _csv.isEmpty ? 'Aucun export généré.' : _csv,
                            style: const TextStyle(fontSize: 12),
                          ),
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

Future<List<PresenceEntry>> _fetchAttendanceRecordsAsPresence({
  required String token,
  required String churchCode,
  required int eventId,
  required Map<String, String> memberNameByNumber,
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
      out.add(
        PresenceEntry(
          id: 'srv_${m['id'] ?? createdAt}',
          churchCode: churchCode,
          activityId: eventId.toString(),
          memberId: isGuest ? 'GUEST' : memberNumber,
          memberPhone: '',
          memberName: isGuest
              ? '$guestName (invité)'
              : (memberNameByNumber[memberNumber] ?? ''),
          markedByPhone: '',
          markedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
        ),
      );
    }
  }
  out.sort((a, b) => b.markedAt.compareTo(a.markedAt));
  return out;
}
