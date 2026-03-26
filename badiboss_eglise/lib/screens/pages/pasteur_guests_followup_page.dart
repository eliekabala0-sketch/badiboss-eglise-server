import 'package:flutter/material.dart';

class PasteurGuestsFollowupPage extends StatefulWidget {
  final String codeEglise;

  const PasteurGuestsFollowupPage({super.key, required this.codeEglise});

  @override
  State<PasteurGuestsFollowupPage> createState() =>
      _PasteurGuestsFollowupPageState();
}

class _GuestItem {
  final String id;
  final String name;
  final String phone;
  int visits;
  String status; // "invité" | "a_suivre" | "converti_membre"
  DateTime lastVisit;

  _GuestItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.visits,
    required this.status,
    required this.lastVisit,
  });
}

class _PasteurGuestsFollowupPageState extends State<PasteurGuestsFollowupPage> {
  static final Map<String, List<_GuestItem>> _db = {};
  List<_GuestItem> get _items => _db.putIfAbsent(widget.codeEglise, () => []);

  void _addDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nouvel invité"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Nom")),
            TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "Téléphone")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              setState(() {
                _items.insert(
                  0,
                  _GuestItem(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: n,
                    phone: phoneCtrl.text.trim(),
                    visits: 1,
                    status: "invité",
                    lastVisit: DateTime.now(),
                  ),
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  void _addVisit(_GuestItem g) {
    setState(() {
      g.visits += 1;
      g.lastVisit = DateTime.now();
      if (g.visits >= 2 && g.status != "converti_membre") {
        g.status = "a_suivre"; // règle cahier de charge : 2 visites = suivi
      }
    });
  }

  void _convert(_GuestItem g) {
    setState(() {
      g.status = "converti_membre";
    });
  }

  String _label(String s) {
    switch (s) {
      case "invité":
        return "Invité";
      case "a_suivre":
        return "À suivre";
      case "converti_membre":
        return "Converti membre";
      default:
        return s;
    }
  }

  Color _color(String s) {
    if (s == "converti_membre") return Colors.green;
    if (s == "a_suivre") return Colors.orange;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final aSuivre = _items.where((x) => x.status == "a_suivre").length;

    return Scaffold(
      appBar: AppBar(title: const Text("Pasteur • Invités → Membres")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDialog,
        icon: const Icon(Icons.person_add),
        label: const Text("Ajouter"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Chip(label: Text("Invités: $total")),
                const SizedBox(width: 8),
                Chip(label: Text("À suivre: $aSuivre")),
                const Spacer(),
                Text("Église: ${widget.codeEglise}",
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text("Aucun invité enregistré."))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final g = _items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(g.name),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (g.phone.isNotEmpty)
                                Chip(label: Text("Tel: ${g.phone}")),
                              Chip(label: Text("Visites: ${g.visits}")),
                              Chip(
                                label: Text(_label(g.status)),
                                backgroundColor:
                                    _color(g.status).withOpacity(0.12),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == "visit") _addVisit(g);
                              if (v == "convert") _convert(g);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: "visit",
                                  child: Text("Ajouter une visite")),
                              PopupMenuItem(
                                value: "convert",
                                enabled: g.status != "converti_membre",
                                child: const Text("Convertir en membre"),
                              ),
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
