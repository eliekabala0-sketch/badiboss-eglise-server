import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/saas_store.dart';
import 'member_self_register_screen.dart';

// Session + Router multi-rôle
import '../auth/stores/session_store.dart';
import '../routes/role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _churchCodeCtrl = TextEditingController(text: 'EGLISE001');
  final _phoneCtrl = TextEditingController(text: '0990000000');
  final _passCtrl = TextEditingController(text: '123456');

  @override
  void dispose() {
    _churchCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final auth = context.read<AuthProvider>();

    final churchCode = _churchCodeCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text;

    final ok = await auth.login(
      churchCode: churchCode,
      phone: phone,
      password: password,
    );

    if (!mounted) return;

    if (ok) {
      final session = auth.session ?? await const SessionStore().read();
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session non chargée après connexion. Réessaie.'),
          ),
        );
        return;
      }
      final roleName = session.roleName;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoleRouter.dashboardForRole(roleName),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Connexion échouée.')),
      );
    }
  }

  Future<void> _createChurchSelfService() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Créer votre église (essai)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code église')),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom église')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone contact')),
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
    final code = codeCtrl.text.trim().toUpperCase();
    final name = nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) return;
    final all = await SaaSStore.loadChurches();
    if (all.any((e) => e.churchCode == code)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce code église existe déjà.')));
      return;
    }
    final global = await SaaSStore.loadGlobal();
    final trial = (global['trialDaysDefault'] ?? 7) as int;
    final grace = (global['graceDaysDefault'] ?? 2) as int;
    final now = DateTime.now();
    all.add(
      SaaSChurchSubscription(
        churchCode: code,
        churchName: name,
        status: 'trial',
        planId: 'plan_basic',
        planName: 'Basic',
        trialDays: trial,
        graceDays: grace,
        reminderEnabled: (global['reminderEnabled'] ?? true) == true,
        contractExempt: false,
        paymentState: 'unpaid',
        startedAtIso: now.toIso8601String(),
        expiresAtIso: now.add(Duration(days: trial)).toIso8601String(),
        graceEndsAtIso: now.add(Duration(days: trial + grace)).toIso8601String(),
        source: 'self_service',
      ),
    );
    await SaaSStore.saveChurches(all);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Église créée en essai: $code. En attente de validation super admin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Badiboss Église - Connexion')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _churchCodeCtrl,
            decoration: const InputDecoration(labelText: 'Church Code'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: auth.isLoading ? null : _doLogin,
            child: auth.isLoading
                ? const CircularProgressIndicator()
                : const Text('Connexion'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _createChurchSelfService,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Créer une église (version essai)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemberSelfRegisterScreen()),
              );
            },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Auto-inscription membre (pending)'),
          ),
        ],
      ),
    );
  }
}