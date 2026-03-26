import 'package:flutter/material.dart';

class FinancesPage extends StatefulWidget {
  final String token;
  final String phone;
  final String role;
  final String codeEglise;

  const FinancesPage({
    super.key,
    required this.token,
    required this.phone,
    required this.role,
    required this.codeEglise,
  });

  @override
  State<FinancesPage> createState() => _FinancesPageState();
}

class _FinancesPageState extends State<FinancesPage> {
  final List<Map<String, dynamic>> _ops = [];
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _type = "Offrande";

  double get _total =>
      _ops.fold<double>(0, (p, e) => p + (e["amount"] as double));

  void _add() {
    final raw = _amount.text.trim().replaceAll(",", ".");
    final v = double.tryParse(raw);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Montant invalide.")),
      );
      return;
    }

    setState(() {
      _ops.insert(0, {
        "type": _type,
        "amount": v,
        "note": _note.text.trim(),
        "ts": DateTime.now(),
      });
      _amount.clear();
      _note.clear();
      _type = "Offrande";
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = "Église: ${widget.codeEglise} • ${widget.phone}";

    return Scaffold(
      appBar: AppBar(title: const Text("Finances")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(subtitle,
                style: TextStyle(color: Colors.black.withOpacity(.6))),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(.06)),
              ),
              child: Text(
                "Total enregistré: ${_total.toStringAsFixed(2)}",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(
                          value: "Offrande", child: Text("Offrande")),
                      DropdownMenuItem(value: "Dîme", child: Text("Dîme")),
                      DropdownMenuItem(value: "Don", child: Text("Don")),
                      DropdownMenuItem(value: "Projet", child: Text("Projet")),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? "Offrande"),
                    decoration: const InputDecoration(
                      labelText: "Type",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Montant",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: "Note (optionnel)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text("Enregistrer"),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ops.isEmpty
                  ? const Center(child: Text("Aucune opération enregistrée."))
                  : ListView.separated(
                      itemCount: _ops.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final e = _ops[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(
                              "${e["type"]} • ${(e["amount"] as double).toStringAsFixed(2)}"),
                          subtitle: Text((e["note"] as String).isEmpty
                              ? "-"
                              : e["note"] as String),
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
