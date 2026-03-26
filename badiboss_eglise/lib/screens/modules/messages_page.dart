import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../services/notification_store.dart';
import '../../widgets/scroll_edge_fabs.dart';

final class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  static const String routeName = '/messages';

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

final class _MessagesPageState extends State<MessagesPage> {
  static const _k = 'church_messages_v1';
  final List<_Msg> _items = [];
  AppSession? _session;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await const SessionStore().read();
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    final data = raw == null
        ? <_Msg>[]
        : (jsonDecode(raw) as List).map((e) => _Msg.fromMap(Map<String, dynamic>.from(e))).toList();
    if (!mounted) return;
    setState(() {
      _session = s;
      _items
        ..clear()
        ..addAll(data);
    });
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(_items.map((e) => e.toMap()).toList()));
  }

  Future<void> _send() async {
    final c = TextEditingController();
    String target = 'all';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Nouveau message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: c,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: target,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Toute l\'église')),
                DropdownMenuItem(value: 'admins', child: Text('Admins')),
                DropdownMenuItem(value: 'members', child: Text('Membres')),
              ],
              onChanged: (v) => setLocal(() => target = v ?? 'all'),
              decoration: const InputDecoration(labelText: 'Destinataires'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
        ],
      ),
      ),
    );
    if (ok != true) return;
    final text = c.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.insert(
        0,
        _Msg(
          text: text,
          sender: _session?.phone ?? 'utilisateur',
          target: target,
          createdAtIso: DateTime.now().toIso8601String(),
        ),
      );
    });
    await _save();
    final cc = (_session?.churchCode ?? '').trim();
    if (cc.isNotEmpty) {
      await NotificationStore.push(
        churchCode: cc,
        target: target,
        title: 'Nouveau message',
        body: text,
        sender: _session?.phone ?? 'utilisateur',
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _safeDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return d.toIso8601String().substring(0, 19);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages / Conversation')),
      floatingActionButton: scrollEdgeFabs(_scrollCtrl),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Aucun message.'))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.chat_bubble_outline_rounded),
                            title: Text(m.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${m.sender} • vers: ${m.target} • ${_safeDate(m.createdAtIso)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            PermissionGate(
              permission: Permissions.sendMessages,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Envoyer un message'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Msg {
  final String text;
  final String sender;
  final String target;
  final String createdAtIso;
  const _Msg({required this.text, required this.sender, required this.target, required this.createdAtIso});

  Map<String, dynamic> toMap() => {
        'text': text,
        'sender': sender,
        'target': target,
        'createdAtIso': createdAtIso,
      };

  static _Msg fromMap(Map<String, dynamic> m) => _Msg(
        text: (m['text'] ?? '').toString(),
        sender: (m['sender'] ?? '').toString(),
        target: (m['target'] ?? 'all').toString(),
        createdAtIso: (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
      );
}
