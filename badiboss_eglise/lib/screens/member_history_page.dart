import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/stores/session_store.dart';
import '../core/config.dart';
import '../services/notification_store.dart';

final class MemberHistoryPage extends StatefulWidget {
  const MemberHistoryPage({super.key});

  @override
  State<MemberHistoryPage> createState() => _MemberHistoryPageState();
}

final class _MemberHistoryPageState extends State<MemberHistoryPage> {
  bool _loading = true;
  String _status = '';
  final List<String> _items = <String>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '';
      _items.clear();
    });
    try {
      final s = await const SessionStore().read();
      var phone = (s?.phone ?? '').trim();
      final cc = (s?.churchCode ?? '').trim();
      final token = (s?.token ?? '').trim();
      if (phone.isEmpty || cc.isEmpty || token.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'Session membre incomplète.';
        });
        return;
      }

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
      String? myNumber;
      if (ml is List) {
        for (final e in ml) {
          if (e is! Map) continue;
          final row = Map<String, dynamic>.from(e);
          final p = (row['phone'] ?? '').toString().trim();
          if (p == phone) {
            myNumber = (row['member_number'] ?? '').toString();
            break;
          }
        }
      }
      if (myNumber == null || myNumber.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'Profil membre introuvable.';
        });
        return;
      }

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
      if (evl is List) {
        for (final ev in evl) {
          if (ev is! Map) continue;
          final eventId = int.tryParse((ev['id'] ?? '').toString());
          final title = (ev['title'] ?? '').toString();
          if (eventId == null) continue;
          final uriP = Uri.parse('${Config.baseUrl}/church/attendance/list').replace(
            queryParameters: {'event_id': eventId.toString()},
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
          if (decP is! Map || resP.statusCode < 200 || resP.statusCode >= 300) continue;
          final rec = decP['records'];
          if (rec is! List) continue;
          for (final r in rec) {
            if (r is! Map) continue;
            final row = Map<String, dynamic>.from(r);
            final mn = (row['member_number'] ?? '').toString();
            if (mn != myNumber) continue;
            final ts = int.tryParse((row['created_at'] ?? '').toString()) ?? 0;
            final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
            _items.add('Présence: $title • ${dt.toLocal()}');
          }
        }
      }

      final uriF = Uri.parse('${Config.baseUrl}/church/feed/list').replace(
        queryParameters: {'kind': 'message'},
      );
      final resF = await http
          .get(
            uriF,
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      final decF = jsonDecode(resF.body.isEmpty ? '{}' : resF.body);
      if (decF is Map && resF.statusCode >= 200 && resF.statusCode < 300) {
        final fl = decF['items'];
        if (fl is List) {
          for (final e in fl.take(10)) {
            if (e is! Map) continue;
            final row = Map<String, dynamic>.from(e);
            _items.add('Message: ${(row['body'] ?? '').toString()}');
          }
        }
      }

      if (_items.isEmpty) {
        _items.add('Aucun historique disponible pour le moment.');
      }
      final notifs = await NotificationStore.loadAll();
      for (final n in notifs) {
        if (n.churchCode != cc) continue;
        final isTarget = n.target == 'all' ||
            (n.target == 'members') ||
            (n.target == 'phone:$phone');
        if (!isTarget) continue;
        _items.insert(0, 'Notification: ${n.title} • ${n.body} • ${n.sender}');
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Erreur historique: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon historique')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length + (_status.isEmpty ? 0 : 1),
                itemBuilder: (_, i) {
                  if (_status.isNotEmpty && i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_status, style: const TextStyle(color: Colors.red)),
                    );
                  }
                  final index = _status.isEmpty ? i : i - 1;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(_items[index]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
