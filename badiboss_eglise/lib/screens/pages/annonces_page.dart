import 'package:flutter/material.dart';

class AnnoncesPage extends StatefulWidget {
  final String token;
  final String phone;
  final String role;
  final String codeEglise;

  const AnnoncesPage({
    super.key,
    required this.token,
    required this.phone,
    required this.role,
    required this.codeEglise,
  });

  @override
  State<AnnoncesPage> createState() => _AnnoncesPageState();
}

class _AnnoncesPageState extends State<AnnoncesPage> {
  final List<Map<String, String>> _annonces = [];
  final TextEditingController _text = TextEditingController();

  String _audience = "Général";

  void _publish() {
    final v = _text.text.trim();
    if (v.isEmpty) return;

    setState(() {
      _annonces.insert(0, {
        "audience": _audience,
        "text": v,
        "ts": DateTime.now().toIso8601String(),
      });
      _text.clear();
      _audience = "Général";
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = "Église: ${widget.codeEglise} • ${widget.phone}";

    return Scaffold(
      appBar: AppBar(title: const Text("Annonces")),
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
                  child: DropdownButtonFormField<String>(
                    value: _audience,
                    items: const [
                      DropdownMenuItem(
                          value: "Général", child: Text("Général")),
                      DropdownMenuItem(value: "Jeunes", child: Text("Jeunes")),
                      DropdownMenuItem(value: "Mamans", child: Text("Mamans")),
                      DropdownMenuItem(value: "Papas", child: Text("Papas")),
                      DropdownMenuItem(
                          value: "Musiciens", child: Text("Musiciens")),
                    ],
                    onChanged: (v) =>
                        setState(() => _audience = v ?? "Général"),
                    decoration: const InputDecoration(
                      labelText: "Audience",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Texte de l’annonce",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _publish,
                icon: const Icon(Icons.send),
                label: const Text("Publier"),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _annonces.isEmpty
                  ? const Center(child: Text("Aucune annonce pour le moment."))
                  : ListView.separated(
                      itemCount: _annonces.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final a = _annonces[i];
                        return ListTile(
                          leading: const Icon(Icons.campaign),
                          title: Text("${a["audience"]}"),
                          subtitle: Text(a["text"] ?? ""),
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
