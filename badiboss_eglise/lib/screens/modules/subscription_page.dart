import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/saas_store.dart';

final class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  static const routeName = '/subscription';

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

final class _SubscriptionPageState extends State<SubscriptionPage> {
  List<SaaSPlan> _plans = <SaaSPlan>[];
  SaaSChurchSubscription? _church;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cc = (prefs.getString('auth_church_code') ?? prefs.getString('current_church_code') ?? '').trim();
    _plans = await SaaSStore.loadPlans();
    final churches = await SaaSStore.loadChurches();
    SaaSChurchSubscription? sub;
    for (final c in churches) {
      if (c.churchCode == cc) {
        sub = c;
        break;
      }
    }
    if (sub == null && cc.isNotEmpty) {
      final now = DateTime.now();
      sub = SaaSChurchSubscription(
        churchCode: cc,
        churchName: cc,
        status: 'trial',
        planId: _plans.first.id,
        planName: _plans.first.name,
        trialDays: 7,
        graceDays: 2,
        reminderEnabled: true,
        contractExempt: false,
        paymentState: 'unpaid',
        startedAtIso: now.toIso8601String(),
        expiresAtIso: now.add(const Duration(days: 7)).toIso8601String(),
        graceEndsAtIso: now.add(const Duration(days: 9)).toIso8601String(),
        source: 'self_service',
      );
      churches.add(sub);
      await SaaSStore.saveChurches(churches);
    }
    if (!mounted) return;
    setState(() => _church = sub);
  }

  Future<void> _choosePlan(SaaSPlan plan) async {
    final c = _church;
    if (c == null) return;
    final now = DateTime.now();
    setState(() {
      c.planId = plan.id;
      c.planName = plan.name;
      c.startedAtIso = now.toIso8601String();
      c.expiresAtIso = now.add(Duration(days: plan.durationDays)).toIso8601String();
      c.graceEndsAtIso = now.add(Duration(days: plan.durationDays + c.graceDays)).toIso8601String();
      c.status = 'active';
      c.paymentState = 'unpaid';
      _status = 'Plan sélectionné: ${plan.name}';
    });
    await _persistChurch();
  }

  Future<void> _payNow() async {
    final c = _church;
    if (c == null) return;
    setState(() {
      c.paymentState = 'paid';
      c.status = 'active';
      _status = 'Paiement marqué payé (flux Badiboss Pay prêt à brancher).';
    });
    await _persistChurch();
  }

  Future<void> _renew() async {
    final c = _church;
    if (c == null) return;
    final p = _plans.firstWhere((x) => x.id == c.planId, orElse: () => _plans.first);
    final now = DateTime.now();
    setState(() {
      c.startedAtIso = now.toIso8601String();
      c.expiresAtIso = now.add(Duration(days: p.durationDays)).toIso8601String();
      c.graceEndsAtIso = now.add(Duration(days: p.durationDays + c.graceDays)).toIso8601String();
      c.status = 'active';
      _status = 'Abonnement renouvelé.';
    });
    await _persistChurch();
  }

  Future<void> _persistChurch() async {
    final c = _church;
    if (c == null) return;
    final all = await SaaSStore.loadChurches();
    final idx = all.indexWhere((x) => x.churchCode == c.churchCode);
    if (idx >= 0) {
      all[idx] = c;
    } else {
      all.add(c);
    }
    await SaaSStore.saveChurches(all);
  }

  int _daysLeft(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 0;
    return d.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final c = _church;
    String reminder = '';
    if (c != null) {
      final d = _daysLeft(c.expiresAtIso);
      if (d <= 0 && !c.contractExempt) {
        reminder = 'Abonnement expiré. Paiement requis ou période de grâce.';
      } else if (d <= 7 && c.reminderEnabled) {
        reminder = 'Rappel: votre abonnement expire dans $d jour(s).';
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement & Paiement')),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    title: Text('Église: ${c.churchName} (${c.churchCode})'),
                    subtitle: Text(
                      'Plan: ${c.planName}\n'
                      'État: ${c.status} • Paiement: ${c.paymentState}\n'
                      'Début: ${c.startedAtIso.substring(0, 10)} • Expire: ${c.expiresAtIso.substring(0, 10)}\n'
                      'Grâce: ${c.graceDays}j • Fin grâce: ${c.graceEndsAtIso.substring(0, 10)}\n'
                      'Jours restants: ${_daysLeft(c.expiresAtIso)}',
                    ),
                    isThreeLine: true,
                  ),
                ),
                if (reminder.isNotEmpty)
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active_rounded, color: Colors.orange),
                      title: const Text('Rappel abonnement'),
                      subtitle: Text(reminder),
                    ),
                  ),
                if (_status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Text(_status, style: const TextStyle(color: Colors.green)),
                  ),
                const SizedBox(height: 8),
                const Text('Choisir un abonnement', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._plans.map(
                  (p) => Card(
                    child: ListTile(
                      title: Text('${p.name} • ${p.durationDays} jours'),
                      subtitle: Text('\$${p.priceUsd.toStringAsFixed(2)} USD'),
                      trailing: FilledButton(
                        onPressed: () => _choosePlan(p),
                        child: const Text('Choisir'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _payNow,
                        icon: const Icon(Icons.account_balance_wallet_rounded),
                        label: const Text('Payer (Badiboss Pay)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _renew,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Renouveler'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
