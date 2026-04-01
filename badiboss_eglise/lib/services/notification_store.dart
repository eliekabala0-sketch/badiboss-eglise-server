import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/stores/session_store.dart';
import '../core/config.dart';
import '../core/phone_rd_congo.dart';
import 'church_api.dart';

final class AppNotification {
  final String id;
  final String churchCode;
  final String target;
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
  static Future<String> _token() async {
    final s = await const SessionStore().read();
    final t = (s?.token ?? '').trim();
    if (t.isEmpty) throw StateError('token manquant');
    return t;
  }

  static Future<List<AppNotification>> loadAll() async {
    final s = await const SessionStore().read();
    final cc = (s?.churchCode ?? '').trim();
    if (cc.isEmpty) return <AppNotification>[];
    try {
      final t = await _token();
      final uri = Uri.parse('${Config.baseUrl}/church/notifications/list');
      final res = await http
          .get(
            uri,
            headers: {
              'accept': 'application/json',
              'Authorization': 'Bearer $t',
            },
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
      final text = res.bodyBytes.isEmpty ? '{}' : utf8.decode(res.bodyBytes);
      final dec = jsonDecode(text);
      if (dec is! Map || res.statusCode < 200 || res.statusCode >= 300) {
        return <AppNotification>[];
      }
      final list = dec['notifications'];
      if (list is! List) return <AppNotification>[];
      return list.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        final ts = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
        final iso = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toIso8601String();
        final reads = m['readByPhones'];
        return AppNotification(
          id: (m['id'] ?? '').toString(),
          churchCode: cc,
          target: (m['target'] ?? 'all').toString(),
          title: (m['title'] ?? '').toString(),
          body: (m['body'] ?? '').toString(),
          sender: (m['sender_phone'] ?? '').toString(),
          createdAtIso: iso,
          readByPhones:
              reads is List ? reads.map((x) => x.toString()).toList() : <String>[],
        );
      }).toList();
    } catch (_) {
      return <AppNotification>[];
    }
  }

  static Future<void> saveAll(List<AppNotification> list) async {}

  static Future<void> push({
    required String churchCode,
    required String target,
    required String title,
    required String body,
    required String sender,
  }) async {}

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
    if (n.target == 'admins') {
      return role == 'admin' || role == 'pasteur' || role == 'super_admin';
    }
    if (n.target.startsWith('phone:')) {
      return normalizePhoneRdCongo(n.target.substring(6)) == normalizePhoneRdCongo(phone);
    }
    if (n.target.startsWith('group:')) return groupIds.contains(n.target.substring(6));
    return false;
  }

  /// IDs de groupes (`member_groups`) dont le membre courant fait partie (via [member_number] profil).
  static Future<List<String>> loadGroupIdsForCurrentUser() async {
    final s = await const SessionStore().read();
    if (s == null || (s.churchCode ?? '').trim().isEmpty) return <String>[];
    var mn = '';
    try {
      final d = await ChurchApi.getJson('/me/profile');
      final u = d['user'];
      if (u is Map) mn = (u['member_number'] ?? '').toString().trim();
    } catch (_) {}
    if (mn.isEmpty) return <String>[];
    try {
      final d = await ChurchApi.getJson('/church/documents/member_groups');
      final pay = d['payload'];
      if (pay is! Map) return <String>[];
      final g = pay['groups'];
      if (g is! List) return <String>[];
      final out = <String>[];
      for (final e in g) {
        if (e is! Map) continue;
        final id = (e['id'] ?? '').toString().trim();
        final mids = e['memberIds'];
        if (id.isEmpty || mids is! List) continue;
        final set = mids.map((x) => x.toString().trim()).where((x) => x.isNotEmpty).toSet();
        if (set.contains(mn)) out.add(id);
      }
      return out;
    } catch (_) {
      return <String>[];
    }
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
      final pnorm = normalizePhoneRdCongo(phone);
      final read = n.readByPhones.any((x) => normalizePhoneRdCongo(x) == pnorm);
      return !read;
    }).length;
  }

  static Future<void> markAsReadFor({
    required String notificationId,
    required String phone,
  }) async {
    try {
      final t = await _token();
      final uri = Uri.parse('${Config.baseUrl}/church/notifications/mark_read');
      await http
          .post(
            uri,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $t',
            },
            body: jsonEncode({'notification_id': notificationId}),
          )
          .timeout(Duration(seconds: Config.timeoutSeconds));
    } catch (_) {}
  }
}
