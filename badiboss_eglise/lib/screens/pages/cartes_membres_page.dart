import 'package:flutter/material.dart';

class CartesMembresPage extends StatefulWidget {
  final String token;
  final String phone;
  final String role;
  final String codeEglise;

  const CartesMembresPage({
    super.key,
    required this.token,
    required this.phone,
    required this.role,
    required this.codeEglise,
  });

  @override
  State<CartesMembresPage> createState() => _CartesMembresPageState();
}

class _CartesMembresPageState extends State<CartesMembresPage> {
  final TextEditingController _search = TextEditingController();

  // Démo CONCRÈTE (fonctionne déjà). Prochaine étape: brancher à la vraie base.
  final List<Map<String, String>> _members = [
    {
      "code": "MBR001",
      "nom": "Jean K.",
      "quartier": "Matonge",
      "telephone": "0990000000",
      "statut": "Membre",
    },
    {
      "code": "MBR002",
      "nom": "Sarah M.",
      "quartier": "Kintambo",
      "telephone": "0970000000",
      "statut": "Jeune",
    },
  ];

  String _filterStatut = "Tous";

  List<Map<String, String>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _members.where((m) {
      final okText = q.isEmpty ||
          (m["nom"] ?? "").toLowerCase().contains(q) ||
          (m["telephone"] ?? "").toLowerCase().contains(q) ||
          (m["quartier"] ?? "").toLowerCase().contains(q) ||
          (m["code"] ?? "").toLowerCase().contains(q);

      final okStatut =
          _filterStatut == "Tous" || (m["statut"] == _filterStatut);
      return okText && okStatut;
    }).toList();
  }

  Future<void> _addMemberDialog() async {
    final nom = TextEditingController();
    final tel = TextEditingController();
    final quartier = TextEditingController();
    String statut = "Membre";

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter un membre"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nom,
                decoration: const InputDecoration(labelText: "Nom complet"),
              ),
              TextField(
                controller: tel,
                decoration: const InputDecoration(labelText: "Téléphone"),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: quartier,
                decoration: const InputDecoration(labelText: "Quartier"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: statut,
                items: const [
                  DropdownMenuItem(value: "Membre", child: Text("Membre")),
                  DropdownMenuItem(value: "Jeune", child: Text("Jeune")),
                  DropdownMenuItem(value: "Maman", child: Text("Maman")),
                  DropdownMenuItem(value: "Papa", child: Text("Papa")),
                ],
                onChanged: (v) => statut = v ?? "Membre",
                decoration: const InputDecoration(labelText: "Statut"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ajouter")),
        ],
      ),
    );

    if (ok != true) return;

    if (nom.text.trim().isEmpty || tel.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nom et téléphone sont obligatoires.")),
      );
      return;
    }

    setState(() {
      final next = (_members.length + 1).toString().padLeft(3, "0");
      _members.insert(0, {
        "code": "MBR$next",
        "nom": nom.text.trim(),
        "telephone": tel.text.trim(),
        "quartier": quartier.text.trim().isEmpty ? "-" : quartier.text.trim(),
        "statut": statut,
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = "Église: ${widget.codeEglise} • Connecté: ${widget.phone}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cartes Membres"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(subtitle,
                style: TextStyle(color: Colors.black.withOpacity(.6))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: "Rechercher (nom, tel, quartier, code)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _addMemberDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text("Ajouter"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Filtre statut : "),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterStatut,
                  items: const [
                    DropdownMenuItem(value: "Tous", child: Text("Tous")),
                    DropdownMenuItem(value: "Membre", child: Text("Membre")),
                    DropdownMenuItem(value: "Jeune", child: Text("Jeune")),
                    DropdownMenuItem(value: "Maman", child: Text("Maman")),
                    DropdownMenuItem(value: "Papa", child: Text("Papa")),
                  ],
                  onChanged: (v) => setState(() => _filterStatut = v ?? "Tous"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(child: Text("Aucun membre trouvé."))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final m = _filtered[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.black.withOpacity(.06)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.qr_code),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${m["nom"]}  •  ${m["statut"]}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text("Code: ${m["code"]}"),
                                    Text("Tél: ${m["telephone"]}"),
                                    Text("Quartier: ${m["quartier"]}"),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: "Voir la carte",
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text("Carte membre: ${m["code"]}")),
                                  );
                                },
                                icon: const Icon(Icons.badge),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
