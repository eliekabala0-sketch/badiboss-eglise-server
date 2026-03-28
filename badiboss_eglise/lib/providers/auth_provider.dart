import 'package:flutter/foundation.dart';

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

  /// Restaure la session persistée (`SessionStore` uniquement).
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final s = await const SessionStore().read();
      _session = s;
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

      _session = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}