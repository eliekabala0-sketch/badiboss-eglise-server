import 'package:flutter/material.dart';

import '../../core/logout_helper.dart';
import '../../services/church_api.dart';
import '../../services/church_service.dart';
import '../../services/saas_store.dart';
import '../app_shell.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  final List<_ChurchItem> _churches = <_ChurchItem>[];
  List<SaaSPlan> _plans = <SaaSPlan>[];
  int _trialDaysDefault = 7;
  int _graceDaysDefault = 2;
  bool _remindersEnabled = true;
  final Set<String> _trialModules = <String>{'members', 'presence', 'reports'};
  String _query = '';
  String _filter = 'all';
  int _page = 0;
  static const int _pageSize = 10;

  String _activeChurch = '';
  String _status = '';
  bool _allowSelfRegistration = true;
  bool _requireValidation = true;
  bool _enableGuestScan = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = ChurchService.getChurchCode().trim();
    try {
      final decCh = await ChurchApi.getJson('/super/churches/list');
      final decSaas = await ChurchApi.getJson('/super/saas/state');
      final global = Map<String, dynamic>.from((decSaas['saas_global'] as Map?) ?? {});
      final td = (global['trialDaysDefault'] is int)
          ? global['trialDaysDefault'] as int
          : int.tryParse('${global['trialDaysDefault'] ?? 7}') ?? 7;
      final gd = (global['graceDaysDefault'] is int)
          ? global['graceDaysDefault'] as int
          : int.tryParse('${global['graceDaysDefault'] ?? 2}') ?? 2;

      final pl = (decSaas['plans'] as List?) ?? [];
      var plans = pl
          .whereType<Map>()
          .map((e) => SaaSPlan.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (plans.isEmpty) {
        plans = <SaaSPlan>[
          SaaSPlan(
            id: 'plan_basic',
            name: 'Basic',
            durationDays: 30,
            priceUsd: 19,
            allowFinance: true,
            allowReports: true,
            allowPresence: true,
            allowMembers: true,
          ),
        ];
      }

      final subs = (decSaas['church_subscriptions'] as List?) ?? [];
      final subsBy = <String, Map<String, dynamic>>{};
      for (final e in subs) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        subsBy[(m['churchCode'] ?? '').toString().toUpperCase()] = m;
      }

      final rows = (decCh['churches'] as List?) ?? [];
      final nextChurches = <_ChurchItem>[];
      final now = DateTime.now();
      for (final r in rows) {
        if (r is! Map) continue;
        final m = Map<String, dynamic>.from(r);
        final code = (m['church_code'] ?? '').toString();
        final name = (m['name'] ?? code).toString();
        final sus = m['is_suspended'] == 1 || m['is_suspended'] == true;
        final sub = subsBy[code.toUpperCase()];
        if (sub != null) {
          nextChurches.add(_ChurchItem.fromSaaS(SaaSChurchSubscription.fromMap(sub)));
        } else {
          final tdays = td > 0 ? td : 7;
          nextChurches.add(
            _ChurchItem(
              code: code,
              name: name,
              status: sus ? 'suspended' : 'trial',
              subscriptionPlan: plans.first.name,
              paymentStatus: 'impayé',
              startedAtIso: now.toIso8601String(),
              expiresAtIso: now.add(Duration(days: tdays)).toIso8601String(),
              graceEndsAtIso: now.add(Duration(days: tdays + gd)).toIso8601String(),
              trialDays: tdays,
              graceDays: gd,
              source: 'server',
              contractExempt: false,
              reminderEnabled: (global['reminderEnabled'] ?? true) == true,
              planId: plans.first.id,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _plans = plans;
        _churches
          ..clear()
          ..addAll(nextChurches);
        _activeChurch = active;
        _allowSelfRegistration = (global['allowSelfRegistration'] ?? true) == true;
        _requireValidation = (global['requireValidation'] ?? true) == true;
        _enableGuestScan = (global['enableGuestScan'] ?? true) == true;
        _trialDaysDefault = td;
        _graceDaysDefault = gd;
        _remindersEnabled = (global['reminderEnabled'] ?? true) == true;
        final mods = (global['trialModules'] as List?)?.map((e) => e.toString()).toSet();
        _trialModules
          ..clear()
          ..addAll(mods ?? <String>{'members', 'presence', 'reports'});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur chargement super: $e');
    }
  }

  Future<void> _save() async {
    await SaaSStore.persistSuperSaasState(
      plans: _plans,
      churchSubscriptions: _churches.map((e) => e.toSaaS()).toList(),
      saasGlobal: {
        'allowSelfRegistration': _allowSelfRegistration,
        'requireValidation': _requireValidation,
        'enableGuestScan': _enableGuestScan,
        'trialDaysDefault': _trialDaysDefault,
        'graceDaysDefault': _graceDaysDefault,
        'reminderEnabled': _remindersEnabled,
        'trialModules': _trialModules.toList(),
      },
    );
  }

  Future<void> _enterChurch(_ChurchItem c) async {
    ChurchService.setChurchCode(c.code);
    if (!mounted) return;
    setState(() {
      _activeChurch = c.code;
      _status = 'Vous êtes entré dans ${c.name} (${c.code}).';
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  Future<void> _exitChurchContext() async {
    ChurchService.clear();
    if (!mounted) return;
    setState(() {
      _activeChurch = '';
      _status = 'Contexte église fermé. Retour multi-églises actif.';
    });
  }

  Future<void> _updateStatus(_ChurchItem c, String status) async {
    setState(() {
      c.status = status;
      _status = 'Statut ${c.code} -> $status';
    });
    await _save();
  }

  Future<void> _openAddChurchDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String planId = _plans.isEmpty ? 'plan_basic' : _plans.first.id;
    final payCtrl = TextEditingController(text: 'impayé');
    final sourceCtrl = TextEditingController(text: 'super_admin');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter une église'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code église')),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom église')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone admin de l\'église')),
              const SizedBox(height: 8),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Mot de passe admin église')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: planId,
                items: _plans
                    .map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.durationDays}j)')))
                    .toList(),
                onChanged: (v) => planId = v ?? planId,
                decoration: const InputDecoration(labelText: 'Abonnement'),
              ),
              const SizedBox(height: 8),
              TextField(controller: payCtrl, decoration: const InputDecoration(labelText: 'Paiement (payé/impayé)')),
              const SizedBox(height: 8),
              TextField(controller: sourceCtrl, decoration: const InputDecoration(labelText: 'Source (super_admin/self_service)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ajouter')),
        ],
      ),
    );
    if (ok != true) return;
    final code = codeCtrl.text.trim().toUpperCase();
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (code.isEmpty || name.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() => _status = 'Code, nom, téléphone et mot de passe pasteur obligatoires.');
      return;
    }
    if (_churches.any((x) => x.code == code)) {
      setState(() => _status = 'Code église déjà existant.');
      return;
    }
    try {
      await ChurchApi.postJson('/super/church/create', {
        'church_code': code,
        'name': name,
        'pasteur_phone': phone,
        'pasteur_full_name': '$name responsable',
        'pasteur_password': pass,
      });
    } catch (e) {
      setState(() => _status = 'Erreur création serveur: $e');
      return;
    }
    await _load();
    if (!mounted) return;
    setState(() => _status = 'Église créée sur le serveur: $code (compte pasteur).');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _churches.where((c) {
      if (_filter != 'all' && c.status != _filter) return false;
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return '${c.code} ${c.name} ${c.subscriptionPlan} ${c.paymentStatus}'.toLowerCase().contains(q);
    }).toList();
    final start = _page * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();
    final hasNext = (start + _pageSize) < filtered.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin — Contrôle global'),
        actions: [
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => LogoutHelper.logoutNow(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddChurchDialog,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Ajouter église'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          _headerCard(),
          const SizedBox(height: 10),
          _settingsCard(),
          const SizedBox(height: 10),
          _plansCard(),
          const SizedBox(height: 10),
          _filtersCard(filtered.length),
          const SizedBox(height: 10),
          _churchesCard(pageItems),
          const SizedBox(height: 10),
          _billingCard(),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                child: const Text('Page précédente'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: hasNext ? () => setState(() => _page++) : null,
                child: const Text('Page suivante'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Panel Super Admin réel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              _activeChurch.isEmpty
                  ? 'Contexte: multi-églises'
                  : 'Contexte actif: $_activeChurch',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _activeChurch.isEmpty ? null : _exitChurchContext,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sortir de l\'église'),
                ),
                OutlinedButton.icon(
                  onPressed: _exitChurchContext,
                  icon: const Icon(Icons.dashboard_rounded),
                  label: const Text('Retour dashboard global'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _status = 'Intégration Badiboss Pay prévue: écran prêt pour branchement API.'),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Badiboss Pay'),
                ),
              ],
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _settingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paramètres importants (sans code)', style: TextStyle(fontWeight: FontWeight.w800)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Autoriser auto-inscription'),
              value: _allowSelfRegistration,
              onChanged: (v) async {
                setState(() => _allowSelfRegistration = v);
                await _save();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exiger validation admin des membres'),
              value: _requireValidation,
              onChanged: (v) async {
                setState(() => _requireValidation = v);
                await _save();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activer scan invités'),
              value: _enableGuestScan,
              onChanged: (v) async {
                setState(() => _enableGuestScan = v);
                await _save();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _trialDaysDefault.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Durée essai (jours)'),
                    onChanged: (v) => _trialDaysDefault = int.tryParse(v.trim()) ?? _trialDaysDefault,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _graceDaysDefault.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Grâce (jours)'),
                    onChanged: (v) => _graceDaysDefault = int.tryParse(v.trim()) ?? _graceDaysDefault,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('members'),
                  selected: _trialModules.contains('members'),
                  onSelected: (v) => setState(() => v ? _trialModules.add('members') : _trialModules.remove('members')),
                ),
                FilterChip(
                  label: const Text('presence'),
                  selected: _trialModules.contains('presence'),
                  onSelected: (v) => setState(() => v ? _trialModules.add('presence') : _trialModules.remove('presence')),
                ),
                FilterChip(
                  label: const Text('reports'),
                  selected: _trialModules.contains('reports'),
                  onSelected: (v) => setState(() => v ? _trialModules.add('reports') : _trialModules.remove('reports')),
                ),
                FilterChip(
                  label: const Text('finance'),
                  selected: _trialModules.contains('finance'),
                  onSelected: (v) => setState(() => v ? _trialModules.add('finance') : _trialModules.remove('finance')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Sauvegarder paramètres SaaS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plansCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Types d’abonnement', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._plans.map(
              (p) => ListTile(
                dense: true,
                title: Text('${p.name} • ${p.durationDays} jours'),
                subtitle: Text('\$${p.priceUsd.toStringAsFixed(2)} USD • modules: ${[
                  if (p.allowMembers) 'members',
                  if (p.allowPresence) 'presence',
                  if (p.allowReports) 'reports',
                  if (p.allowFinance) 'finance',
                ].join(", ")}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editPlan(p),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _addPlan,
                icon: const Icon(Icons.add),
                label: const Text('Nouveau plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard(int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recherche / filtre • $total résultat(s)', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Code, nom, abonnement...',
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in const ['all', 'trial', 'active', 'expired', 'suspended', 'banned', 'pending'])
                  ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() {
                      _filter = f;
                      _page = 0;
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _churchesCard(List<_ChurchItem> pageItems) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Églises', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (pageItems.isEmpty)
              const Text('Aucune église enregistrée.')
            else
              ...pageItems.map(
                (c) => Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text('${c.name} (${c.code})'),
                    subtitle: Text(
                      'Statut: ${_statusLabel(c.status)}\n'
                      'Abonnement: ${c.subscriptionPlan} • Paiement: ${c.paymentStatus}\n'
                      'Expire: ${_dateShort(c.expiresAtIso)} • Restant: ${_daysLeft(c.expiresAtIso)}j • Grâce: ${c.graceDays}j',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'validate') await _updateStatus(c, 'active');
                        if (v == 'suspend') await _updateStatus(c, 'suspended');
                        if (v == 'reactivate') await _updateStatus(c, 'active');
                        if (v == 'ban') await _updateStatus(c, 'banned');
                        if (v == 'unban') await _updateStatus(c, 'active');
                        if (v == 'enter') await _enterChurch(c);
                        if (v == 'billing') await _editBilling(c);
                        if (v == 'reset_access') await _resetChurchAccess(c);
                        if (v == 'exempt') {
                          setState(() => c.contractExempt = !c.contractExempt);
                          await _save();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'validate', child: Text('Valider')),
                        const PopupMenuItem(value: 'suspend', child: Text('Suspendre')),
                        const PopupMenuItem(value: 'reactivate', child: Text('Réactiver')),
                        const PopupMenuItem(value: 'ban', child: Text('Bannir')),
                        const PopupMenuItem(value: 'unban', child: Text('Débannir')),
                        const PopupMenuItem(value: 'enter', child: Text('Entrer dans l\'église')),
                        const PopupMenuItem(value: 'billing', child: Text('Modifier paiement/abonnement')),
                        const PopupMenuItem(value: 'reset_access', child: Text('Réinitialiser identifiants église')),
                        PopupMenuItem(
                          value: 'exempt',
                          child: Text(c.contractExempt ? 'Retirer exception contrat' : 'Autoriser exception contrat'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBilling(_ChurchItem c) async {
    String planId = c.planId;
    final payCtrl = TextEditingController(text: c.paymentStatus);
    final renewalCtrl = TextEditingController(text: c.expiresAtIso);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Paiement / abonnement ${c.code}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: planId,
                items: _plans.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (v) => planId = v ?? planId,
                decoration: const InputDecoration(labelText: 'Type abonnement'),
              ),
              const SizedBox(height: 8),
              TextField(controller: payCtrl, decoration: const InputDecoration(labelText: 'Paiement (payé/impayé)')),
              const SizedBox(height: 8),
              TextField(controller: renewalCtrl, decoration: const InputDecoration(labelText: 'Date expiration ISO')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      final plan = _plans.firstWhere((p) => p.id == planId, orElse: () => _plans.first);
      c.planId = plan.id;
      c.subscriptionPlan = plan.name;
      c.paymentStatusValue = payCtrl.text.trim();
      c.expiresAtIso = renewalCtrl.text.trim();
      c.graceEndsAtIso = _parseIsoOrNow(c.expiresAtIso).add(Duration(days: c.graceDays)).toIso8601String();
      final now = DateTime.now();
      final exp = _parseIsoOrNow(c.expiresAtIso);
      c.status = exp.isBefore(now) && !c.contractExempt ? 'expired' : c.status;
      _status = 'Paiement/abonnement mis à jour pour ${c.code}.';
    });
    await _save();
  }

  Future<void> _resetChurchAccess(_ChurchItem c) async {
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reset identifiants ${c.code}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nouveau téléphone admin')),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (ok != true) return;
    final ph = phoneCtrl.text.trim();
    final pw = passCtrl.text.trim();
    if (ph.isEmpty || pw.isEmpty) return;
    try {
      await ChurchApi.postJson('/super/users/password_reset', {
        'church_code': c.code,
        'phone': ph,
        'new_password': pw,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Erreur réinitialisation: $e');
      return;
    }
    if (!mounted) return;
    setState(() => _status = 'Mot de passe serveur mis à jour pour $ph (${c.code}).');
  }

  Widget _billingCard() {
    final paid = _churches.where((e) => e.paymentStatus.toLowerCase() == 'payé').length;
    final unpaid = _churches.length - paid;
    final trial = _churches.where((e) => e.status == 'trial').length;
    final expired = _churches.where((e) => e.status == 'expired').length;
    final exempt = _churches.where((e) => e.contractExempt).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Abonnements / Paiements', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Total églises: ${_churches.length}'),
            Text('Paiements à jour: $paid'),
            Text('Paiements en retard: $unpaid'),
            Text('En essai: $trial'),
            Text('Expirées: $expired'),
            Text('Exemptées contrat: $exempt'),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'En attente';
      case 'trial':
        return 'Essai';
      case 'expired':
        return 'Expirée';
      case 'suspended':
        return 'Suspendue';
      case 'banned':
        return 'Bannie';
      default:
        return s;
    }
  }

  String _dateShort(String iso) {
    if (iso.trim().isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int _daysLeft(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 0;
    final now = DateTime.now();
    return d.difference(now).inDays;
  }

  DateTime _parseIsoOrNow(String iso) => DateTime.tryParse(iso) ?? DateTime.now();

  Future<void> _addPlan() async {
    final nameCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '30');
    final priceCtrl = TextEditingController(text: '19');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau type d’abonnement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du plan')),
              const SizedBox(height: 8),
              TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (jours)')),
              const SizedBox(height: 8),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix USD')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _plans.add(
        SaaSPlan(
          id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          durationDays: int.tryParse(durationCtrl.text.trim()) ?? 30,
          priceUsd: double.tryParse(priceCtrl.text.trim()) ?? 0,
          allowFinance: true,
          allowReports: true,
          allowPresence: true,
          allowMembers: true,
        ),
      );
    });
    await _save();
  }

  Future<void> _editPlan(SaaSPlan p) async {
    final nameCtrl = TextEditingController(text: p.name);
    final durationCtrl = TextEditingController(text: p.durationDays.toString());
    final priceCtrl = TextEditingController(text: p.priceUsd.toString());
    bool m = p.allowMembers, pr = p.allowPresence, r = p.allowReports, f = p.allowFinance;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Modifier plan ${p.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom plan')),
                const SizedBox(height: 8),
                TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (jours)')),
                const SizedBox(height: 8),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix USD')),
                CheckboxListTile(value: m, onChanged: (v) => setLocal(() => m = v == true), title: const Text('Members')),
                CheckboxListTile(value: pr, onChanged: (v) => setLocal(() => pr = v == true), title: const Text('Presence')),
                CheckboxListTile(value: r, onChanged: (v) => setLocal(() => r = v == true), title: const Text('Reports')),
                CheckboxListTile(value: f, onChanged: (v) => setLocal(() => f = v == true), title: const Text('Finance')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      p.name = nameCtrl.text.trim().isEmpty ? p.name : nameCtrl.text.trim();
      p.durationDays = int.tryParse(durationCtrl.text.trim()) ?? p.durationDays;
      p.priceUsd = double.tryParse(priceCtrl.text.trim()) ?? p.priceUsd;
      p.allowMembers = m;
      p.allowPresence = pr;
      p.allowReports = r;
      p.allowFinance = f;
    });
    await _save();
  }
}

final class _ChurchItem {
  final String code;
  final String name;
  String status;
  String planId;
  String subscriptionPlan;
  String paymentStatus;
  String startedAtIso;
  String expiresAtIso;
  String graceEndsAtIso;
  int trialDays;
  int graceDays;
  String source;
  bool contractExempt;
  bool reminderEnabled;

  _ChurchItem({
    required this.code,
    required this.name,
    required this.status,
    this.planId = 'plan_basic',
    required this.subscriptionPlan,
    required this.paymentStatus,
    required this.startedAtIso,
    required this.expiresAtIso,
    required this.graceEndsAtIso,
    required this.trialDays,
    required this.graceDays,
    required this.source,
    required this.contractExempt,
    required this.reminderEnabled,
  });

  set subscriptionPlanValue(String v) => subscriptionPlan = v.isEmpty ? subscriptionPlan : v;
  set paymentStatusValue(String v) => paymentStatus = v.isEmpty ? paymentStatus : v;
  set nextRenewalValue(String v) => expiresAtIso = v;

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'status': status,
        'planId': planId,
        'subscriptionPlan': subscriptionPlan,
        'paymentStatus': paymentStatus,
        'startedAtIso': startedAtIso,
        'expiresAtIso': expiresAtIso,
        'graceEndsAtIso': graceEndsAtIso,
        'trialDays': trialDays,
        'graceDays': graceDays,
        'source': source,
        'contractExempt': contractExempt,
        'reminderEnabled': reminderEnabled,
      };

  static _ChurchItem fromMap(Map<String, dynamic> m) => _ChurchItem(
        code: (m['code'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        status: (m['status'] ?? 'pending').toString(),
        planId: (m['planId'] ?? 'plan_basic').toString(),
        subscriptionPlan: (m['subscriptionPlan'] ?? 'Pro').toString(),
        paymentStatus: (m['paymentStatus'] ?? 'impayé').toString(),
        startedAtIso: (m['startedAtIso'] ?? '').toString(),
        expiresAtIso: (m['expiresAtIso'] ?? '').toString(),
        graceEndsAtIso: (m['graceEndsAtIso'] ?? '').toString(),
        trialDays: (m['trialDays'] ?? 7) as int,
        graceDays: (m['graceDays'] ?? 2) as int,
        source: (m['source'] ?? 'super_admin').toString(),
        contractExempt: (m['contractExempt'] ?? false) == true,
        reminderEnabled: (m['reminderEnabled'] ?? true) == true,
      );

  SaaSChurchSubscription toSaaS() => SaaSChurchSubscription(
        churchCode: code,
        churchName: name,
        status: status,
        planId: planId,
        planName: subscriptionPlan,
        trialDays: trialDays,
        graceDays: graceDays,
        reminderEnabled: reminderEnabled,
        contractExempt: contractExempt,
        paymentState: paymentStatus.toLowerCase().contains('pay') ? 'paid' : 'unpaid',
        startedAtIso: startedAtIso,
        expiresAtIso: expiresAtIso,
        graceEndsAtIso: graceEndsAtIso,
        source: source,
      );

  static _ChurchItem fromSaaS(SaaSChurchSubscription s) => _ChurchItem(
        code: s.churchCode,
        name: s.churchName,
        status: s.status,
        planId: s.planId,
        subscriptionPlan: s.planName,
        paymentStatus: s.paymentState == 'paid' ? 'payé' : (s.paymentState == 'exempted' ? 'exempté' : 'impayé'),
        startedAtIso: s.startedAtIso,
        expiresAtIso: s.expiresAtIso,
        graceEndsAtIso: s.graceEndsAtIso,
        trialDays: s.trialDays,
        graceDays: s.graceDays,
        source: s.source,
        contractExempt: s.contractExempt,
        reminderEnabled: s.reminderEnabled,
      );
}