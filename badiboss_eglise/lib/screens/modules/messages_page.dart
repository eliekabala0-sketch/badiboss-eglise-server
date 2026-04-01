import 'package:flutter/material.dart';

import '../../auth/access_control.dart';
import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../core/phone_rd_congo.dart';
import '../../models/member.dart';
import '../../services/church_api.dart';
import '../../services/member_directory_service.dart';
import '../../widgets/member_picker_dialog.dart';
import '../../widgets/scroll_edge_fabs.dart';

final class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  static const String routeName = '/messages';

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

final class _MessagesPageState extends State<MessagesPage> {
  final List<_Msg> _items = [];
  final _scrollCtrl = ScrollController();
  AppSession? _session;
  bool _replyPerm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await const SessionStore().read();
      _session = s;
      if (s != null) {
        _replyPerm = await AccessControl.has(s, Permissions.replyMessages);
      } else {
        _replyPerm = false;
      }
      final dec = await ChurchApi.getJson('/church/feed/list?kind=message');
      final list = dec['items'];
      final next = <_Msg>[];
      if (list is List) {
        for (final e in list) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final ts = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
          final iso = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toIso8601String();
          next.add(
            _Msg(
              id: (m['id'] ?? '').toString(),
              text: (m['body'] ?? '').toString(),
              sender: (m['sender_phone'] ?? '').toString(),
              target: (m['audience'] ?? 'all').toString(),
              createdAtIso: iso,
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.clear());
    }
  }

  bool _canReplyTo(_Msg m, String myNorm) {
    if (!_replyPerm || myNorm.isEmpty) return false;
    if (m.sender.trim().isEmpty) return false;
    if (normalizePhoneRdCongo(m.sender) == myNorm) return false;
    if (m.target.startsWith('phone:')) {
      return normalizePhoneRdCongo(m.target.substring(6)) == myNorm;
    }
    if (m.target == 'members' || m.target == 'all') {
      return true;
    }
    return false;
  }

  Future<void> _reply(_Msg m) async {
    final staffPhone = normalizePhoneRdCongo(m.sender);
    if (staffPhone.length != 12 || !staffPhone.startsWith('243')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de répondre : expéditeur non reconnu.')),
        );
      }
      return;
    }
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Répondre au message'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Votre réponse'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (ok != true) return;
    final text = c.text.trim();
    if (text.isEmpty) return;
    try {
      await ChurchApi.postJson('/church/feed/create', {
        'kind': 'message',
        'body': text,
        'audience': 'phone:$staffPhone',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec envoi: $e')),
        );
      }
      return;
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réponse envoyée.')),
      );
    }
  }

  Future<void> _send() async {
    final c = TextEditingController();
    String targetMode = 'all';
    Member? targetMember;
    List<Member> members = const <Member>[];
    try {
      members = await const MemberDirectoryService().loadMembersForActiveChurch();
    } catch (_) {}
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
                value: targetMode,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Toute l\'église')),
                  DropdownMenuItem(value: 'admins', child: Text('Admins')),
                  DropdownMenuItem(value: 'members', child: Text('Membres (tous)')),
                  DropdownMenuItem(value: 'member_one', child: Text('Membre précis')),
                ],
                onChanged: (v) => setLocal(() {
                  targetMode = v ?? 'all';
                  if (targetMode != 'member_one') targetMember = null;
                }),
                decoration: const InputDecoration(labelText: 'Destinataires'),
              ),
              if (targetMode == 'member_one') ...[
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    targetMember == null
                        ? 'Choisir un membre'
                        : '${targetMember!.id} • ${targetMember!.fullName}',
                  ),
                  subtitle: Text(targetMember == null ? 'Recherche par nom, code, téléphone' : targetMember!.phone),
                  trailing: const Icon(Icons.search),
                  onTap: () async {
                    final picked = await showMemberPickerDialog(context, members: members, title: 'Destinataire membre');
                    if (picked != null) {
                      setLocal(() => targetMember = picked);
                    }
                  },
                ),
              ],
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
    if (targetMode == 'member_one' && targetMember == null) return;
    final target = targetMode == 'member_one' ? 'phone:${normalizePhoneRdCongo(targetMember!.phone)}' : targetMode;
    try {
      await ChurchApi.postJson('/church/feed/create', {
        'kind': 'message',
        'body': text,
        'audience': target,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec envoi (droits réseau ou permissions).')),
        );
      }
      return;
    }
    await _load();
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
    final myNorm = normalizePhoneRdCongo((_session?.phone ?? '').trim());

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
                        final showReply = _canReplyTo(m, myNorm);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.chat_bubble_outline_rounded),
                                  title: Text(m.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    '${m.sender} • vers: ${m.target} • ${_safeDate(m.createdAtIso)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (showReply)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _reply(m),
                                      icon: const Icon(Icons.reply_rounded),
                                      label: const Text('Répondre'),
                                    ),
                                  ),
                              ],
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
  final String id;
  final String text;
  final String sender;
  final String target;
  final String createdAtIso;
  const _Msg({
    required this.id,
    required this.text,
    required this.sender,
    required this.target,
    required this.createdAtIso,
  });
}
