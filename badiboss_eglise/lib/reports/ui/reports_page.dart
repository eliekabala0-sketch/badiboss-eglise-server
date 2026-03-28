import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../core/config.dart';
import '../../services/church_service.dart';
import 'reports_export_page.dart';

final class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  static const String routeName = '/reports';

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

final class _ReportsPageState extends State<ReportsPage> {
  AppSession? _session;
  bool _loading = true;
  String _status = '';
  int _members = 0;
  int _activities = 0;
  int _presences = 0;
  int _announcements = 0;

  final _superAdminChurchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await const SessionStore().read();
    if (!mounted) return;
    setState(() => _session = s);
    await _reloadStats();
  }

  Future<void> _reloadStats() async {
    final s = _session;
    final cc = _effectiveChurchCode();
    if (s == null || cc == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final token = s.token.trim();
      if (token.isEmpty) throw StateError('token manquant');

      final uriM = Uri.parse('${Config.baseUrl}/church/members/list');
      final resM = await http
          .get(
            uriM,
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      final decM = jsonDecode(resM.body.isEmpty ? '{}' : resM.body);
      if (decM is! Map || resM.statusCode < 200 || resM.statusCode >= 300) {
        throw StateError('Impossible de charger les membres');
      }
      final ml = decM['members'];
      final memberCount = ml is List ? ml.length : 0;

      final uriE = Uri.parse('${Config.baseUrl}/church/attendance/events/list');
      final resE = await http
          .get(
            uriE,
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      final decE = jsonDecode(resE.body.isEmpty ? '{}' : resE.body);
      if (decE is! Map || resE.statusCode < 200 || resE.statusCode >= 300) {
        throw StateError('Impossible de charger les activités');
      }
      final evl = decE['events'];
      final eventCount = evl is List ? evl.length : 0;

      var presenceTotal = 0;
      if (evl is List) {
        for (final ev in evl) {
          if (ev is! Map) continue;
          final eid = int.tryParse((ev['id'] ?? '').toString());
          if (eid == null) continue;
          final uriP = Uri.parse('${Config.baseUrl}/church/attendance/list').replace(
            queryParameters: {'event_id': eid.toString()},
          );
          final resP = await http
              .get(
                uriP,
                headers: {
                  'accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(Duration(seconds: Config.timeoutSeconds));
          final decP = jsonDecode(resP.body.isEmpty ? '{}' : resP.body);
          if (decP is! Map || resP.statusCode < 200 || resP.statusCode >= 300) {
            continue;
          }
          final rec = decP['records'];
          if (rec is List) presenceTotal += rec.length;
        }
      }

      final uriA = Uri.parse('${Config.baseUrl}/church/feed/list').replace(
        queryParameters: {'kind': 'announcement'},
      );
      final resA = await http
          .get(
            uriA,
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      final decA = jsonDecode(resA.body.isEmpty ? '{}' : resA.body);
      var ann = 0;
      if (decA is Map && resA.statusCode >= 200 && resA.statusCode < 300) {
        final il = decA['items'];
        ann = il is List ? il.length : 0;
      }
      if (!mounted) return;
      setState(() {
        _members = memberCount;
        _activities = eventCount;
        _presences = presenceTotal;
        _announcements = ann;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Erreur stats: $e';
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

  @override
  void dispose() {
    _superAdminChurchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? const Center(child: CircularProgressIndicator())
            : PermissionGate(
                permission: Permissions.viewReports,
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
                        onChanged: (_) => _reloadStats(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_effectiveChurchCode() == null)
                      const Text(
                        'churchCode requis (SUPER ADMIN: saisir).',
                        style: TextStyle(color: Colors.red),
                      ),

                    const SizedBox(height: 12),
                    if (_loading) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    if (_status.isNotEmpty)
                      Text(_status, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statChip('Membres', _members),
                        _statChip('Activités', _activities),
                        _statChip('Présences', _presences),
                        _statChip('Annonces', _announcements),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _reloadStats,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Actualiser les statistiques'),
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(ReportsExportPage.routeName),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exporter rapports'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statChip(String label, int value) {
    return Chip(
      label: Text('$label: $value'),
      avatar: const Icon(Icons.bar_chart_rounded, size: 16),
    );
  }
}
