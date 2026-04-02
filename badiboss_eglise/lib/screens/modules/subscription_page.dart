import 'package:flutter/material.dart';

import '../../auth/models/user_role.dart';
import '../../auth/stores/session_store.dart';
import '../../services/church_api.dart';
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
  bool _loading = true;
  String _serverReminder = '';
  int? _serverDaysLeft;

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
    final s = await const SessionStore().read();
    final cc = (s?.churchCode ?? '').trim();
    if (s == null || s.token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _church = null;
        _status = 'Session requise.';
      });
      return;
    }
    if (cc.isEmpty && s.role != UserRole.superAdmin) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _church = null;
        _status = 'Code église manquant pour cet utilisateur.';
      });
      return;
    }
    try {
      final dec = await ChurchApi.getJson('/church/billing/subscription');
      final pl = dec['plans'];
      if (pl is List && pl.isNotEmpty) {
        _plans = pl
            .whereType<Map>()
            .map((e) => SaaSPlan.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _plans = await SaaSStore.loadPlans();
      }
      if (cc.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _church = null;
          _status = 'Super admin: sélectionnez une église pour voir l’abonnement.';
        });
        return;
      }
      final raw = dec['subscription'];
      final meta = dec['subscription_meta'];
      if (meta is Map) {
        _serverDaysLeft = int.tryParse('${meta['days_left'] ?? ''}');
      } else {
        _serverDaysLeft = null;
      }
      _serverReminder = (dec['reminder'] ?? '').toString().trim();
      if (raw is Map && raw.isNotEmpty) {
        _church = SaaSChurchSubscription.fromMap(Map<String, dynamic>.from(raw));
      } else {
        final now = DateTime.now();
        final plan = _plans.isNotEmpty ? _plans.first : (await SaaSStore.loadPlans()).first;
        _church = SaaSChurchSubscription(
          churchCode: cc,
          churchName: cc,
          status: 'trial',
          planId: plan.id,
          planName: plan.name,
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
        await ChurchApi.postJson('/church/billing/subscription', {
          'subscription': _church!.toMap(),
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Erreur chargement: $e';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
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
    try {
      await ChurchApi.postJson('/church/billing/subscription', {'subscription': c.toMap()});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _status = 'Erreur enregistrement: $e');
    }
  }

  int _daysLeft(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 0;
    return d.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final c = _church;
    String reminder = _serverReminder;
    if (c != null) {
      final d = _serverDaysLeft ?? _daysLeft(c.expiresAtIso);
      if (reminder.isEmpty) {
        if (d <= 0 && !c.contractExempt) {
          reminder = 'Abonnement expiré. Paiement requis ou période de grâce.';
        } else if (d <= 2 && c.reminderEnabled) {
          reminder = 'Rappel: votre abonnement expire dans $d jour(s).';
        }
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement & Paiement')),
      body: c == null
          ? Center(child: Text(_status.isEmpty ? 'Chargement…' : _status))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Église: ${c.churchName} (${c.churchCode})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Plan: ${c.planName}')),
                            Chip(label: Text('État: ${c.status}')),
                            Chip(label: Text('Paiement: ${c.paymentState}')),
                            Chip(label: Text('Jours restants: ${_serverDaysLeft ?? _daysLeft(c.expiresAtIso)}')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Début: ${c.startedAtIso.length >= 10 ? c.startedAtIso.substring(0, 10) : c.startedAtIso}\n'
                          'Expire: ${c.expiresAtIso.length >= 10 ? c.expiresAtIso.substring(0, 10) : c.expiresAtIso}\n'
                          'Grâce: ${c.graceDays}j • Fin grâce: ${c.graceEndsAtIso.length >= 10 ? c.graceEndsAtIso.substring(0, 10) : c.graceEndsAtIso}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.78), height: 1.35),
                        ),
                      ],
                    ),
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
                const SizedBox(height: 14),
                const Text('Choisir un abonnement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
                const SizedBox(height: 14),
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
