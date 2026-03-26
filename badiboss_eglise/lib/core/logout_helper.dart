import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/stores/session_store.dart';
import '../screens/login_screen.dart';

final class LogoutHelper {
  const LogoutHelper._();

  static Future<void> logoutNow(BuildContext context) async {
    await const SessionStore().clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_phone');
    await prefs.remove('auth_role');
    await prefs.remove('auth_church_code');
    await prefs.remove('current_church_code');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
