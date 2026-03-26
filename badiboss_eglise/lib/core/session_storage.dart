import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  Future<void> write(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', (data['token'] ?? '').toString());
    await p.setString('role', (data['role'] ?? '').toString());
    await p.setString('accountStatus', (data['accountStatus'] ?? '').toString());
    await p.setString('churchCode', (data['churchCode'] ?? '').toString());
    await p.setString('phone', (data['phone'] ?? '').toString());
  }

  Future<Map<String, String>> read() async {
    final p = await SharedPreferences.getInstance();
    return {
      'token': p.getString('token') ?? '',
      'role': p.getString('role') ?? '',
      'accountStatus': p.getString('accountStatus') ?? '',
      'churchCode': p.getString('churchCode') ?? '',
      'phone': p.getString('phone') ?? '',
    };
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('role');
    await p.remove('accountStatus');
    await p.remove('churchCode');
    await p.remove('phone');
  }
}
