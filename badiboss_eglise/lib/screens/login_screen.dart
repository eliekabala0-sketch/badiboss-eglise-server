import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/church_api.dart';
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
    final pasteurNameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
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
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone pasteur (connexion)')),
              const SizedBox(height: 8),
              TextField(controller: pasteurNameCtrl, decoration: const InputDecoration(labelText: 'Nom du pasteur')),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe compte pasteur'),
              ),
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
    final phone = phoneCtrl.text.trim();
    final pasteurName = pasteurNameCtrl.text.trim().isEmpty ? 'Pasteur' : pasteurNameCtrl.text.trim();
    final pw = passCtrl.text.trim();
    if (code.isEmpty || name.isEmpty || phone.isEmpty || pw.length < 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code, nom, téléphone et mot de passe (min 4) obligatoires.')),
      );
      return;
    }
    try {
      final existing = await ChurchApi.getPublicJson('/public/churches/list');
      final ch = existing['churches'];
      if (ch is List && ch.any((e) => e is Map && (e['church_code'] ?? '').toString().toUpperCase() == code)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce code église existe déjà.')));
        return;
      }
    } catch (_) {}
    try {
      await ChurchApi.postPublicJson('/public/church/trial_create', {
        'church_code': code,
        'name': name,
        'pasteur_phone': phone,
        'pasteur_full_name': pasteurName,
        'pasteur_password': pw,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec création: $e')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Église créée sur le serveur: $code. Connectez-vous avec le téléphone pasteur.')),
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