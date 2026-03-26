import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';
import '../services/local_members_store.dart';
import '../presence/stores/activities_store.dart';
import '../presence/stores/presence_store.dart';
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
      final prefs = await SharedPreferences.getInstance();
      final phone = (prefs.getString('auth_phone') ?? '').trim();
      final cc = (prefs.getString('auth_church_code') ?? '').trim();
      if (phone.isEmpty || cc.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'Session membre incomplète.';
        });
        return;
      }

      final members = await LocalMembersStore.loadByChurch(cc);
      Member? me;
      for (final m in members) {
        if (m.phone.trim() == phone) {
          me = m;
          break;
        }
      }
      if (me == null) {
        setState(() {
          _loading = false;
          _status = 'Profil membre introuvable.';
        });
        return;
      }

      final acts = await const ActivitiesStore().load(cc);
      for (final a in acts) {
        final p = await const PresenceStore().load(churchCode: cc, activityId: a.id);
        final found = p.where((x) => x.memberId == me!.id || x.memberPhone == me.phone);
        for (final e in found) {
          _items.add('Présence: ${a.title} • ${e.markedAt.toLocal()}');
        }
      }

      final messagesRaw = prefs.getString('church_messages_v1');
      if (messagesRaw != null && messagesRaw.trim().isNotEmpty) {
        final rows = (jsonDecode(messagesRaw) as List).cast<Map>();
        for (final row in rows.take(10)) {
          final m = Map<String, dynamic>.from(row);
          _items.add('Message: ${(m['text'] ?? '').toString()}');
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
