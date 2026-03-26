import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class AppNotification {
  final String id;
  final String churchCode;
  final String target; // all|admins|members|group:<id>|phone:<phone>
  final String title;
  final String body;
  final String sender;
  final String createdAtIso;
  List<String> readByPhones;

  AppNotification({
    required this.id,
    required this.churchCode,
    required this.target,
    required this.title,
    required this.body,
    required this.sender,
    required this.createdAtIso,
    required this.readByPhones,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'churchCode': churchCode,
        'target': target,
        'title': title,
        'body': body,
        'sender': sender,
        'createdAtIso': createdAtIso,
        'readByPhones': readByPhones,
      };

  static AppNotification fromMap(Map<String, dynamic> m) => AppNotification(
        id: (m['id'] ?? '').toString(),
        churchCode: (m['churchCode'] ?? '').toString(),
        target: (m['target'] ?? 'all').toString(),
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        sender: (m['sender'] ?? '').toString(),
        createdAtIso: (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
        readByPhones: (m['readByPhones'] is List)
            ? (m['readByPhones'] as List).map((e) => e.toString()).toList()
            : <String>[],
      );
}

final class NotificationStore {
  static const _k = 'app_notifications_v1';

  static Future<List<AppNotification>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw == null || raw.trim().isEmpty) return <AppNotification>[];
    return (jsonDecode(raw) as List)
        .map((e) => AppNotification.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> saveAll(List<AppNotification> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode(list.map((e) => e.toMap()).toList()));
  }

  static Future<void> push({
    required String churchCode,
    required String target,
    required String title,
    required String body,
    required String sender,
  }) async {
    final all = await loadAll();
    all.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        churchCode: churchCode,
        target: target,
        title: title,
        body: body,
        sender: sender,
        createdAtIso: DateTime.now().toIso8601String(),
        readByPhones: <String>[],
      ),
    );
    await saveAll(all);
  }

  static bool isTargetFor({
    required AppNotification n,
    required String churchCode,
    required String role,
    required String phone,
    required List<String> groupIds,
  }) {
    if (n.churchCode != churchCode) return false;
    if (n.target == 'all') return true;
    if (n.target == 'members') return role == 'member' || role == 'membre';
    if (n.target == 'admins') return role == 'admin' || role == 'pasteur' || role == 'super_admin';
    if (n.target.startsWith('phone:')) return n.target.substring(6) == phone;
    if (n.target.startsWith('group:')) return groupIds.contains(n.target.substring(6));
    return false;
  }

  static Future<int> countUnreadFor({
    required String churchCode,
    required String role,
    required String phone,
    required List<String> groupIds,
  }) async {
    final all = await loadAll();
    return all.where((n) {
      if (!isTargetFor(
        n: n,
        churchCode: churchCode,
        role: role,
        phone: phone,
        groupIds: groupIds,
      )) {
        return false;
      }
      return !n.readByPhones.contains(phone);
    }).length;
  }

  static Future<void> markAsReadFor({
    required String notificationId,
    required String phone,
  }) async {
    final all = await loadAll();
    final idx = all.indexWhere((n) => n.id == notificationId);
    if (idx < 0) return;
    if (!all[idx].readByPhones.contains(phone)) {
      all[idx].readByPhones.add(phone);
      await saveAll(all);
    }
  }
}
