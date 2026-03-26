import 'package:flutter/material.dart';

class PresencesPage extends StatefulWidget {
  final String token;
  final String phone;
  final String role;
  final String codeEglise;

  const PresencesPage({
    super.key,
    required this.token,
    required this.phone,
    required this.role,
    required this.codeEglise,
  });

  @override
  State<PresencesPage> createState() => _PresencesPageState();
}

class _PresencesPageState extends State<PresencesPage> {
  String? _currentActivity; // créée par admin (pas préfigurée)
  final List<String> _presents = [];
  final List<String> _invites = [];

  final TextEditingController _codeOrName = TextEditingController();

  Future<void> _createActivityDialog() async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Lancer un culte / activité"),
        content: TextField(
          controller: title,
          decoration: const InputDecoration(
            labelText: "Nom de l’activité (ex: Culte Dimanche Matin)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Lancer")),
        ],
      ),
    );

    if (ok != true) return;
    if (title.text.trim().isEmpty) return;

    setState(() {
      _currentActivity = title.text.trim();
      _presents.clear();
      _invites.clear();
    });
  }

  void _addPresence({required bool invite}) {
    if (_currentActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("D’abord lancer un culte / activité.")),
      );
      return;
    }

    final v = _codeOrName.text.trim();
    if (v.isEmpty) return;

    setState(() {
      if (invite) {
        // invité ≠ membre (règle cahier) : ici on accepte juste le nom, prochaine étape = contrôle stricte via base
        if (!_invites.contains(v)) _invites.add(v);
      } else {
        if (!_presents.contains(v)) _presents.add(v);
      }
      _codeOrName.clear();
    });
  }

  @override
  void dispose() {
    _codeOrName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = "Église: ${widget.codeEglise} • Admin: ${widget.phone}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Présences"),
        actions: [
          IconButton(
            tooltip: "Lancer une activité",
            onPressed: _createActivityDialog,
            icon: const Icon(Icons.play_circle),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(subtitle,
                style: TextStyle(color: Colors.black.withOpacity(.6))),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(.06)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentActivity == null
                          ? "Aucune activité en cours."
                          : "Activité en cours: $_currentActivity",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createActivityDialog,
                    icon: const Icon(Icons.add),
                    label:
                        Text(_currentActivity == null ? "Lancer" : "Relancer"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeOrName,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge),
                labelText: "Code membre / Nom invité",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addPresence(invite: false),
                    icon: const Icon(Icons.verified),
                    label: const Text("Valider présence membre"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addPresence(invite: true),
                    icon: const Icon(Icons.person_outline),
                    label: const Text("Ajouter invité"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Text("Membres présents: ${_presents.length}",
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._presents.map(
                    (e) => ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(e),
                    ),
                  ),
                  const Divider(),
                  Text("Invités: ${_invites.length}",
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._invites.map(
                    (e) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(e),
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
