import 'package:flutter/material.dart';
import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';
import '../../services/church_api.dart';

final class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  static const String routeName = '/announcements';

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

final class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final List<_Announcement> _items = [];
  AppSession? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await const SessionStore().read();
    try {
      final dec = await ChurchApi.getJson('/church/feed/list?kind=announcement');
      final list = dec['items'];
      final next = <_Announcement>[];
      if (list is List) {
        for (final e in list) {
          if (e is! Map) continue;
          final m = Map<String, dynamic>.from(e);
          final ts = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
          final iso = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toIso8601String();
          next.add(
            _Announcement(
              text: (m['body'] ?? '').toString(),
              sender: (m['sender_phone'] ?? '').toString(),
              audience: (m['audience'] ?? 'all').toString(),
              createdAtIso: iso,
            ),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _session = s;
        _items
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _session = s);
    }
  }

  Future<void> _add() async {
    final c = TextEditingController();
    String audience = 'all';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nouvelle annonce'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Annonce'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: audience,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Église entière')),
                  DropdownMenuItem(value: 'admins', child: Text('Admins')),
                  DropdownMenuItem(value: 'members', child: Text('Membres')),
                ],
                onChanged: (v) => setLocal(() => audience = v ?? 'all'),
                decoration: const InputDecoration(labelText: 'Cible'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publier')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final v = c.text.trim();
    if (v.isEmpty) return;
    try {
      await ChurchApi.postJson('/church/feed/create', {
        'kind': 'announcement',
        'body': v,
        'audience': audience,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec publication (droits réseau ou permissions).')),
        );
      }
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Communiqués / Annonces')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_session != null)
              Text(
                'Église: ${_session!.churchCode ?? "-"}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Aucune annonce pour le moment.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.campaign_outlined),
                          title: Text(_items[i].text),
                          subtitle: Text(
                            '${_items[i].sender} • cible: ${_items[i].audience} • ${_items[i].createdAtIso.substring(0, 19)}',
                          ),
                        ),
                      ),
                    ),
            ),
            PermissionGate(
              permission: Permissions.manageAnnouncements,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Publier une annonce'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Announcement {
  final String text;
  final String sender;
  final String audience;
  final String createdAtIso;
  const _Announcement({
    required this.text,
    required this.sender,
    required this.audience,
    required this.createdAtIso,
  });
}
