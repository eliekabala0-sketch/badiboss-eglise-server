import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_service.dart';
import '../auth/models/session.dart';
import '../auth/stores/session_store.dart';

final class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  AppSession? _session;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AppSession? get session => _session;

  final AuthService _auth = const AuthService();

  /// 🔒 A3: Restore session + compat SharedPreferences legacy
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final s = await const SessionStore().read();
      _session = s;

      // ✅ Compat : certains écrans lisent encore auth_* (TabMembers etc.)
      // On écrit uniquement si une session existe.
      if (s != null) {
        await _writeLegacyPrefsFromSession(s);
      }
    } catch (e) {
      // Pas de crash: on force session null
      _session = null;
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String churchCode,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _auth.login(
        churchCode: churchCode.trim(),
        phone: phone.trim(),
        password: password,
      );

      if (res is AuthSuccess) {
        _session = res.session;

        // ✅ Compat legacy (NE PAS CASSER l’existant)
        await _writeLegacyPrefsFromSession(res.session);

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      if (res is AuthFailure) {
        _session = null;
        _isLoading = false;
        _errorMessage = res.message;
        notifyListeners();
        return false;
      }

      _session = null;
      _isLoading = false;
      _errorMessage = 'Connexion échouée.';
      notifyListeners();
      return false;
    } catch (e) {
      _session = null;
      _isLoading = false;
      _errorMessage = 'Erreur: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.logout();
      await _clearLegacyPrefs();

      _session = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// -------------------------
  /// 🔒 Legacy compat helpers
  /// -------------------------

  Future<void> _writeLegacyPrefsFromSession(AppSession s) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔒 Clés legacy utilisées ailleurs
    await prefs.setString('auth_phone', s.phone);
    await prefs.setString('auth_role', s.roleName); // ex: admin/pasteur/membre/protocole/...
    await prefs.setString('auth_church_code', (s.churchCode ?? '').trim());

    // 🔒 Compat LocalMembersStore (il utilise current_church_code)
    // Même si super_admin => churchCode vide, on écrit la valeur brute.
    await prefs.setString('current_church_code', (s.churchCode ?? '').trim());
  }

  Future<void> _clearLegacyPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_phone');
    await prefs.remove('auth_role');
    await prefs.remove('auth_church_code');

    // compat LocalMembersStore
    await prefs.remove('current_church_code');
  }
}