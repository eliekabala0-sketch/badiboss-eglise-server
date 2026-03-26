import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/permissions.dart';
import '../../auth/ui/permission_gate.dart';
import '../../services/export_file_service.dart';

final class SecretariatPage extends StatefulWidget {
  const SecretariatPage({super.key});

  static const String routeName = '/secretariat';

  @override
  State<SecretariatPage> createState() => _SecretariatPageState();
}

final class _SecretariatPageState extends State<SecretariatPage> {
  static const _k = 'secretariat_documents_v1';
  final List<_DocItem> _items = [];
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    final docs = raw == null
        ? <_DocItem>[]
        : (jsonDecode(raw) as List).map((e) => _DocItem.fromMap(Map<String, dynamic>.from(e))).toList();
    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(docs);
    });
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(_items.map((e) => e.toMap()).toList()));
  }

  Future<void> _addDoc() async {
    final title = TextEditingController();
    final kind = TextEditingController(text: 'PV');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau document'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
              const SizedBox(height: 8),
              TextField(controller: kind, decoration: const InputDecoration(labelText: 'Type (PV, lettre, note)')),
              const SizedBox(height: 8),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Observation')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    setState(() {
      _items.insert(
        0,
        _DocItem(
          title: title.text.trim(),
          kind: kind.text.trim(),
          note: note.text.trim(),
          createdAtIso: DateTime.now().toIso8601String(),
        ),
      );
    });
    await _save();
  }

  Future<void> _exportDocs() async {
    final csv = <String>[
      'created_at,type,title,note',
      ..._items.map((d) => [
            _q(d.createdAtIso),
            _q(d.kind),
            _q(d.title),
            _q(d.note),
          ].join(',')),
    ].join('\n');
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final result = await ExportFileService.saveTextFile(
      fileName: 'secretariat_documents_$ts.csv',
      content: csv,
      openShareSheet: true,
    );
    if (!mounted) return;
    setState(() => _status = 'Export secrétariat: ${result.path}');
  }

  String _q(String v) => '"${v.replaceAll('"', '""')}"';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secrétariat')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_status, style: const TextStyle(color: Colors.green)),
              ),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Aucun document enregistré.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final d = _items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.folder_open_rounded),
                            title: Text('${d.kind} • ${d.title}'),
                            subtitle: Text('${d.createdAtIso.substring(0, 19)}\n${d.note.isEmpty ? "-" : d.note}'),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
            PermissionGate(
              permission: Permissions.manageSecretariat,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addDoc,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter document'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportDocs,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Exporter'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DocItem {
  final String title;
  final String kind;
  final String note;
  final String createdAtIso;
  const _DocItem({
    required this.title,
    required this.kind,
    required this.note,
    required this.createdAtIso,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'kind': kind,
        'note': note,
        'createdAtIso': createdAtIso,
      };

  static _DocItem fromMap(Map<String, dynamic> m) => _DocItem(
        title: (m['title'] ?? '').toString(),
        kind: (m['kind'] ?? '').toString(),
        note: (m['note'] ?? '').toString(),
        createdAtIso: (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
      );
}
