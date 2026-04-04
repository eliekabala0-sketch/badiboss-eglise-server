import 'package:flutter/material.dart';

import '../../services/church_api.dart';
import '../../services/saas_store.dart';

/// Zone Badiboss Pay : état des abonnements + emplacement API (sans casser le SaaS actuel).
final class SuperAdminPayPage extends StatefulWidget {
  const SuperAdminPayPage({super.key});

  @override
  State<SuperAdminPayPage> createState() => _SuperAdminPayPageState();
}

final class _SuperAdminPayPageState extends State<SuperAdminPayPage> {
  bool _loading = true;
  String _status = '';
  List<Map<String, dynamic>> _subs = [];
  Map<String, dynamic> _global = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '';
    });
    try {
      final dec = await ChurchApi.getJson('/super/saas/state');
      final subs = (dec['church_subscriptions'] as List?) ?? [];
      final gl = (dec['saas_global'] as Map?) ?? {};
      if (!mounted) return;
      setState(() {
        _subs = subs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _global = Map<String, dynamic>.from(gl);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _subs.where((s) {
      final ps = '${s['paymentState'] ?? ''}'.toLowerCase();
      return ps.contains('paid') || ps.contains('payé');
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badiboss Pay'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_status, style: const TextStyle(color: Colors.red)),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Branchement paiement', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                          'Prévu : portail Badiboss Pay (URL publique), webhooks de confirmation, '
                          'mise à jour automatique de paymentState / expiresAtIso dans saas_church_subscriptions. '
                          'Aucun flux financier n’est activé tant que les clés API ne sont pas configurées côté serveur.',
                          style: TextStyle(height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        Text('État global : essai ${(_global['trialDaysDefault'] ?? '—')} j, grâce ${_global['graceDaysDefault'] ?? '—'} j', style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Abonnements (${_subs.length}) — payés détectés : $paid',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._subs.take(30).map(
                      (s) => Card(
                        child: ListTile(
                          title: Text('${s['churchCode'] ?? '—'} • ${s['planName'] ?? s['planId'] ?? '—'}'),
                          subtitle: Text(
                            'Statut: ${s['status'] ?? '—'} • Paiement: ${s['paymentState'] ?? '—'}\n'
                            'Expire: ${s['expiresAtIso'] ?? '—'}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                if (_subs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucune entrée dans church_subscriptions. Les essais sont recalculés depuis la date de création d’église côté serveur.'),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final plans = await SaaSStore.loadPlans();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Plans visibles côté client : ${plans.length} (API /church/billing/subscription).')),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Vérifier les plans publics'),
                ),
              ],
            ),
    );
  }
}
