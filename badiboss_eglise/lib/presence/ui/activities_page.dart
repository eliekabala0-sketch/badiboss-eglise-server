import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../models/activity.dart';
import '../../core/config.dart';
import '../../services/church_service.dart';

final class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  static const String routeName = '/activities';

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

final class _ActivitiesPageState extends State<ActivitiesPage> {
  AppSession? _session;
  String _status = '';

  final _superAdminChurchCtrl = TextEditingController();

  final _titleCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'culte');

  List<Activity> _items = <Activity>[];

  /// Résumé présences pour activités OPEN (id événement → texte).
  Map<String, String> _openPresenceSummary = <String, String>{};

  Timer? _statsPoll;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _statsPoll = Timer.periodic(const Duration(seconds: 14), (_) {
      if (!mounted || _session == null) return;
      unawaited(_loadOpenPresenceSummaries());
    });
  }

  Future<void> _loadSession() async {
    try {
      const store = SessionStore();
      final s = await store.read();
      if (!mounted) return;
      setState(() => _session = s);
      await _reload();
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

    // SUPER ADMIN: doit préciser une église pour travailler sur présences
    final cc = _superAdminChurchCtrl.text.trim();
    if (cc.isNotEmpty) return cc;
    final scoped = ChurchService.getChurchCode().trim();
    if (scoped.isNotEmpty) return scoped;
    return null;
  }

  Future<void> _reload() async {
    final cc = _effectiveChurchCode();
    final s = _session;
    if (cc == null || s == null) {
      setState(() {
        _items = <Activity>[];
        _openPresenceSummary = <String, String>{};
        _status = 'churchCode requis pour gérer les activités (SUPER ADMIN: saisir).';
      });
      return;
    }

    try {
      final api = await _fetchEventsFromApi(token: s.token);
      if (!mounted) return;
      setState(() {
        _items = api;
        _status = '';
      });
      await _loadOpenPresenceSummaries();
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : e.toString();
      setState(() {
        _items = <Activity>[];
        _openPresenceSummary = <String, String>{};
        _status = 'Erreur serveur: $msg';
      });
    }
  }

  Future<void> _loadOpenPresenceSummaries() async {
    final s = _session;
    if (s == null || s.token.trim().isEmpty) return;
    final open = _items.where((a) => a.status == ActivityStatus.open).toList();
    if (open.isEmpty) {
      if (mounted) setState(() => _openPresenceSummary = <String, String>{});
      return;
    }
    final next = <String, String>{};
    for (final a in open) {
      try {
        final eventId = int.parse(a.id);
        final uri = Uri.parse('${Config.baseUrl}/church/attendance/list').replace(
          queryParameters: {'event_id': eventId.toString()},
        );
        final res = await http
            .get(
              uri,
              headers: {
                'accept': 'application/json',
                'Authorization': 'Bearer ${s.token}',
              },
            )
            .timeout(Duration(seconds: Config.timeoutSeconds));
        final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
        if (decoded is! Map || res.statusCode < 200 || res.statusCode >= 300) continue;
        final records = decoded['records'];
        if (records is! List) continue;
        var guests = 0;
        var members = 0;
        for (final e in records) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final mn = (m['member_number'] ?? '').toString();
          final gn = (m['guest_name'] ?? '').toString();
          if (mn.isEmpty && gn.isNotEmpty) {
            guests++;
          } else if (mn.isNotEmpty) {
            members++;
          }
        }
        final total = records.length;
        next[a.id] = 'Présences: $total • Membres $members • Invités $guests';
      } catch (_) {}
    }
    if (mounted) setState(() => _openPresenceSummary = next);
  }

  Future<void> _create() async {
    final cc = _effectiveChurchCode();
    final s = _session;
    if (cc == null || s == null) {
      setState(() => _status = 'Impossible: session/churchCode manquant.');
      return;
    }

    final title = _titleCtrl.text.trim();
    final type = _typeCtrl.text.trim();

    if (title.isEmpty) {
      setState(() => _status = 'Titre obligatoire.');
      return;
    }
    if (type.isEmpty) {
      setState(() => _status = 'Type obligatoire.');
      return;
    }

    try {
      await _createEventApi(token: s.token, title: title, eventDate: _today(), eventType: type);
      _titleCtrl.clear();
      await _reload();
    } catch (e) {
      final msg = e is StateError ? e.message : e.toString();
      if (mounted) setState(() => _status = msg);
    }
  }

  Future<void> _close(Activity a) async {
    try {
      final s = _session;
      if (s == null) return;
      await _closeEventApi(token: s.token, eventId: int.parse(a.id), closed: true);
    } catch (e) {
      final msg = e is StateError ? e.message : e.toString();
      if (mounted) setState(() => _status = msg);
      return;
    }
    await _reload();
  }

  Future<void> _reopen(Activity a) async {
    try {
      final s = _session;
      if (s == null) return;
      await _closeEventApi(token: s.token, eventId: int.parse(a.id), closed: false);
    } catch (e) {
      final msg = e is StateError ? e.message : e.toString();
      if (mounted) setState(() => _status = msg);
      return;
    }
    await _reload();
  }

  @override
  void dispose() {
    _statsPoll?.cancel();
    _superAdminChurchCtrl.dispose();
    _titleCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Activités / Cultes')),
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
                  const SizedBox(height: 8),

                  if (s.churchCode == null) ...[
                    TextField(
                      controller: _superAdminChurchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'churchCode (SUPER ADMIN)',
                        hintText: 'Ex: EGLISE001',
                      ),
                      onChanged: (_) => _reload(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const PermissionGate(
                    permission: Permissions.launchActivity,
                    child: _CreateActivityBox(),
                  ),

                  // La box ci-dessus est statique -> on met le vrai formulaire ici (non-const)
                  PermissionGate(
                    permission: Permissions.launchActivity,
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Titre activité',
                            hintText: 'Ex: Culte du dimanche',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _typeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            hintText: 'culte, réunion, ...',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _create,
                            child: const Text('Lancer une activité (OPEN)'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.builder(
                        itemCount: _items.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return (_status.trim().isEmpty)
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      _status,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                          }
                          final a = _items[i - 1];
                          final isOpen = a.status == ActivityStatus.open;
                          final sum = _openPresenceSummary[a.id];
                          final sub = isOpen && sum != null
                              ? '$sum\n${a.type} • OPEN • ${a.startedAt}'
                              : '${a.type} • ${isOpen ? "OPEN" : "CLOSED"} • ${a.startedAt}';

                          return Card(
                            child: ListTile(
                              title: Text(a.title),
                              subtitle: Text(sub),
                              isThreeLine: isOpen && sum != null,
                              trailing: isOpen
                                  ? TextButton(
                                      onPressed: () => _close(a),
                                      child: const Text('Clôturer'),
                                    )
                                  : TextButton(
                                      onPressed: () => _reopen(a),
                                      child: const Text('Ré-ouvrir'),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _today() {
    final d = DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  Activity _activityFromApi(Map<String, dynamic> e) {
    final id = (e['id'] ?? 0).toString();
    final title = (e['title'] ?? '').toString();
    final status = activityStatusFromString(e['status']?.toString());
    final createdAt = int.tryParse((e['created_at'] ?? '').toString()) ?? 0;
    final closedAtTs = int.tryParse((e['closed_at'] ?? '').toString());
    return Activity(
      id: id,
      churchCode: _effectiveChurchCode() ?? '',
      title: title,
      type: 'culte',
      status: status,
      createdByPhone: '',
      startedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      closedAt: (closedAtTs == null) ? null : DateTime.fromMillisecondsSinceEpoch(closedAtTs * 1000),
    );
  }

  Future<List<Activity>> _fetchEventsFromApi({required String token}) async {
    final uri = Uri.parse('${Config.baseUrl}/church/attendance/events/list');
    final res = await http
        .get(uri, headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'})
        .timeout(Duration(seconds: Config.timeoutSeconds));
    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');
    if (res.statusCode < 200 || res.statusCode >= 300) throw StateError((decoded['detail'] ?? 'Erreur API').toString());
    final list = decoded['events'];
    if (list is! List) return <Activity>[];
    return list.whereType<Map>().map((x) => _activityFromApi(Map<String, dynamic>.from(x))).toList();
  }

  Future<void> _createEventApi({
    required String token,
    required String title,
    required String eventDate,
    required String eventType,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/attendance/event/create');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'title': title, 'event_date': eventDate, 'event_type': eventType}),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));
    if (res.statusCode < 200 || res.statusCode >= 300) throw StateError(res.body);
  }

  Future<void> _closeEventApi({
    required String token,
    required int eventId,
    required bool closed,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/attendance/event/close');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'event_id': eventId, 'closed': closed}),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));
    if (res.statusCode < 200 || res.statusCode >= 300) throw StateError(res.body);
  }
}

// Widget placeholder (garde PermissionGate const)
final class _CreateActivityBox extends StatelessWidget {
  const _CreateActivityBox();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
