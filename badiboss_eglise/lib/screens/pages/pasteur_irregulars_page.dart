import 'package:flutter/material.dart';
import '../../models/member.dart';
import '../../services/church_api.dart';
import '../../services/member_directory_service.dart';

class PasteurIrregularsPage extends StatefulWidget {
  final String codeEglise;

  const PasteurIrregularsPage({super.key, required this.codeEglise});

  @override
  State<PasteurIrregularsPage> createState() => _PasteurIrregularsPageState();
}

class _IrregularItem {
  final String id;
  final String memberName;
  final String phone;
  String shepherd; // berger assigné
  String status; // "irregulier" | "en_suivi" | "redevenu_actif"
  String nextFollowUp; // date/heure libre
  List<String> actions;
  final DateTime createdAt;

  _IrregularItem({
    required this.id,
    required this.memberName,
    required this.phone,
    required this.shepherd,
    required this.status,
    required this.nextFollowUp,
    required this.actions,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'memberName': memberName,
        'phone': phone,
        'shepherd': shepherd,
        'status': status,
        'nextFollowUp': nextFollowUp,
        'actions': actions,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static _IrregularItem fromMap(Map<String, dynamic> m) => _IrregularItem(
        id: (m['id'] ?? '').toString(),
        memberName: (m['memberName'] ?? '').toString(),
        phone: (m['phone'] ?? '').toString(),
        shepherd: (m['shepherd'] ?? '').toString(),
        status: (m['status'] ?? 'irregulier').toString(),
        nextFollowUp: (m['nextFollowUp'] ?? '').toString(),
        actions: (m['actions'] is List) ? (m['actions'] as List).map((e) => e.toString()).toList() : <String>[],
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['createdAt'] ?? 0) as int),
      );
}

class _PasteurIrregularsPageState extends State<PasteurIrregularsPage> {
  final List<_IrregularItem> _items = <_IrregularItem>[];
  List<Member> _members = <Member>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _members = await const MemberDirectoryService().loadMembersForActiveChurch();
    try {
      final dec = await ChurchApi.getJson('/church/documents/irregulars');
      final pay = dec['payload'];
      if (pay is Map) {
        final raw = pay['items'];
        if (raw is List && raw.isNotEmpty) {
          final data =
              raw.whereType<Map>().map((e) => _IrregularItem.fromMap(Map<String, dynamic>.from(e))).toList();
          if (!mounted) return;
          setState(() {
            _items
              ..clear()
              ..addAll(data);
          });
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    await ChurchApi.postJson('/church/documents/irregulars', {
      'payload': {'items': _items.map((e) => e.toMap()).toList()},
    });
  }

  void _addDialog() {
    final followUpCtrl = TextEditingController();
    Member? selectedMember;
    Member? selectedShepherd;
    String monthly = 'toujours_irregulier';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
        title: const Text("Déclarer un membre irrégulier"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              dense: true,
              title: Text(selectedMember == null ? 'Sélectionner membre irrégulier' : '${selectedMember!.id} • ${selectedMember!.fullName}'),
              subtitle: const Text('Filtrer par nom ou code membre'),
              trailing: const Icon(Icons.search),
              onTap: () async {
                final picked = await _pickMemberFromList();
                if (picked == null) return;
                setLocal(() => selectedMember = picked);
              },
            ),
            ListTile(
              dense: true,
              title: Text(selectedShepherd == null ? 'Sélectionner berger' : '${selectedShepherd!.id} • ${selectedShepherd!.fullName}'),
              subtitle: const Text('Filtrer par nom ou code membre'),
              trailing: const Icon(Icons.search),
              onTap: () async {
                final picked = await _pickMemberFromList();
                if (picked == null) return;
                setLocal(() => selectedShepherd = picked);
              },
            ),
            DropdownButtonFormField<String>(
              value: monthly,
              items: const [
                DropdownMenuItem(value: 'toujours_irregulier', child: Text('Toujours irrégulier')),
                DropdownMenuItem(value: 'en_amelioration', child: Text('En amélioration')),
                DropdownMenuItem(value: 'regulier', child: Text('Régulier')),
                DropdownMenuItem(value: 'autre', child: Text('Autre')),
              ],
              onChanged: (v) => setLocal(() => monthly = v ?? monthly),
              decoration: const InputDecoration(labelText: "Évaluation mensuelle"),
            ),
            TextField(
              controller: followUpCtrl,
              decoration: const InputDecoration(labelText: "Prochain suivi (date/heure)"),
            ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              final member = selectedMember;
              final shepherd = selectedShepherd;
              if (member == null || shepherd == null) return;
              setState(() {
                _items.insert(
                  0,
                  _IrregularItem(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    memberName: member.fullName,
                    phone: member.phone,
                    shepherd: '${shepherd.id} • ${shepherd.fullName}',
                    status: "irregulier",
                    nextFollowUp: followUpCtrl.text.trim(),
                    actions: ['Déclaration initiale', 'Évaluation: $monthly'],
                    createdAt: DateTime.now(),
                  ),
                );
              });
              _persist();
              Navigator.pop(context);
            },
            child: const Text("Valider"),
          ),
        ],
      ),
      ),
    );
  }

  void _cycle(_IrregularItem x) {
    setState(() {
      if (x.status == "irregulier")
        x.status = "en_suivi";
      else if (x.status == "en_suivi")
        x.status = "redevenu_actif";
      else
        x.status = "irregulier";
      x.actions.add('Statut -> ${_label(x.status)}');
    });
    _persist();
  }

  String _label(String s) {
    switch (s) {
      case "irregulier":
        return "Irrégulier";
      case "en_suivi":
        return "En suivi";
      case "redevenu_actif":
        return "Redevenu actif";
      default:
        return s;
    }
  }

  Color _color(String s) {
    if (s == "redevenu_actif") return Colors.green;
    if (s == "en_suivi") return Colors.orange;
    return Colors.redAccent;
  }

  void _editShepherd(_IrregularItem x) {
    _pickMemberFromList().then((picked) {
      if (picked == null) return;
      setState(() => x.shepherd = '${picked.id} • ${picked.fullName}');
      x.actions.add('Berger assigné -> ${x.shepherd}');
      _persist();
    });
  }

  void _addAction(_IrregularItem x) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter action de suivi"),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(labelText: "Action / relance / réconfort"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            onPressed: () {
              final v = c.text.trim();
              if (v.isEmpty) return;
              setState(() => x.actions.add(v));
              _persist();
              Navigator.pop(context);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  void _editNextFollowUp(_IrregularItem x) {
    final c = TextEditingController(text: x.nextFollowUp);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Prochain suivi"),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: "Date/heure prochaine relance"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          FilledButton(
            onPressed: () {
              setState(() => x.nextFollowUp = c.text.trim());
              _persist();
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final suivi = _items.where((e) => e.status == "en_suivi").length;

    return Scaffold(
      appBar: AppBar(title: const Text("Pasteur • Irréguliers & Bergers")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("Ajouter"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Chip(label: Text("Total: $total")),
                const SizedBox(width: 8),
                Chip(label: Text("En suivi: $suivi")),
                const Spacer(),
                Text("Église: ${widget.codeEglise}",
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text("Aucun irrégulier déclaré."))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final x = _items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(x.memberName),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (x.phone.isNotEmpty)
                                Chip(label: Text("Tel: ${x.phone}")),
                              Chip(label: Text("Berger: ${x.shepherd}")),
                              if (x.nextFollowUp.isNotEmpty)
                                Chip(label: Text("Suivi: ${x.nextFollowUp}")),
                              Chip(
                                label: Text(_label(x.status)),
                                backgroundColor:
                                    _color(x.status).withOpacity(0.12),
                              ),
                              if (x.actions.isNotEmpty)
                                Chip(label: Text("Actions: ${x.actions.length}")),
                            ],
                          ),
                          onTap: () => _cycle(x),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == "shepherd") _editShepherd(x);
                              if (v == "cycle") _cycle(x);
                              if (v == "action") _addAction(x);
                              if (v == "followup") _editNextFollowUp(x);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: "shepherd",
                                  child: Text("Changer berger")),
                              PopupMenuItem(
                                  value: "cycle",
                                  child: Text("Changer statut")),
                              PopupMenuItem(
                                  value: "followup",
                                  child: Text("Programmer suivi")),
                              PopupMenuItem(
                                  value: "action",
                                  child: Text("Ajouter action")),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

extension on _PasteurIrregularsPageState {
  Future<Member?> _pickMemberFromList() async {
    String q = '';
    final screenH = MediaQuery.of(context).size.height;
    return showDialog<Member>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final filtered = _members.where((m) {
            final qq = q.trim().toLowerCase();
            if (qq.isEmpty) return true;
            return '${m.id} ${m.fullName} ${m.phone}'.toLowerCase().contains(qq);
          }).toList();
          return AlertDialog(
            title: const Text('Sélectionner membre'),
            content: SizedBox(
              width: 460,
              height: screenH * 0.68,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nom, code membre ou téléphone'),
                    onChanged: (v) => setLocal(() => q = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Aucun membre trouvé'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final m = filtered[i];
                              return ListTile(
                                dense: true,
                                title: Text('${m.id} • ${m.fullName}'),
                                subtitle: Text(m.phone),
                                onTap: () => Navigator.pop(ctx, m),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ],
          );
        },
      ),
    );
  }
}
