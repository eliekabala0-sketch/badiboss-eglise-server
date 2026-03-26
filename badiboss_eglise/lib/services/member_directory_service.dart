import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/stores/session_store.dart';
import '../core/config.dart';
import '../models/member.dart';
import 'local_members_store.dart';

final class MemberDirectoryService {
  const MemberDirectoryService();

  Future<List<Member>> loadMembersForActiveChurch() async {
    final prefs = await SharedPreferences.getInstance();
    final session = await const SessionStore().read();
    final fromSession = (session?.churchCode ?? '').trim();
    final fromAuth = (prefs.getString('auth_church_code') ?? '').trim();
    final fromCurrent = (prefs.getString('current_church_code') ?? '').trim();
    final churchCode = fromSession.isNotEmpty
        ? fromSession
        : (fromAuth.isNotEmpty ? fromAuth : fromCurrent);

    if (churchCode.isEmpty) return <Member>[];
    final token = (session?.token ?? '').trim();
    if (token.isNotEmpty) {
      try {
        final apiMembers = await _fetchFromApi(churchCode: churchCode, token: token);
        if (apiMembers.isNotEmpty) {
          for (final m in apiMembers) {
            await LocalMembersStore.upsert(m, churchCode: churchCode);
          }
          return apiMembers;
        }
      } catch (_) {
        // fallback local below
      }
    }
    return LocalMembersStore.loadByChurch(churchCode);
  }

  Future<List<Member>> _fetchFromApi({
    required String churchCode,
    required String token,
  }) async {
    final uri = Uri.parse('${Config.baseUrl}/church/members/list');
    final res = await http.get(
      uri,
      headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(Duration(seconds: Config.timeoutSeconds));
    final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (decoded is! Map) return <Member>[];
    if (res.statusCode < 200 || res.statusCode >= 300) return <Member>[];
    final membersRaw = decoded['members'];
    if (membersRaw is! List) return <Member>[];
    return membersRaw
        .whereType<Map>()
        .map((m) => _memberFromApiMap(Map<String, dynamic>.from(m), churchCode: churchCode))
        .toList();
  }

  Member _memberFromApiMap(Map<String, dynamic> m, {required String churchCode}) {
    final isValidated = (m['is_validated'] ?? 0) == 1;
    final createdAtTs = int.tryParse((m['created_at'] ?? '').toString()) ?? 0;
    final statusRaw = (m['status'] ?? '').toString().trim().toLowerCase();
    final status = statusRaw == 'active'
        ? MemberStatus.active
        : statusRaw == 'suspended'
            ? MemberStatus.suspended
            : statusRaw == 'banned'
                ? MemberStatus.banned
                : (isValidated ? MemberStatus.active : MemberStatus.pending);

    return Member(
      id: (m['member_number'] ?? m['id'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      fullName: (m['full_name'] ?? '').toString(),
      sex: sexFromString(m['sex']?.toString()),
      maritalStatus: maritalFromString(m['marital_status']?.toString()),
      birthDateIso: (m['birth_date'] ?? m['date_of_birth'] ?? '').toString(),
      commune: (m['commune'] ?? '').toString(),
      quartier: (m['quarter'] ?? '').toString(),
      zone: (m['zone'] ?? '').toString(),
      addressLine: (m['address_line'] ?? '').toString(),
      neighborhood: (m['neighborhood'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      province: (m['province'] ?? '').toString(),
      churchCode: churchCode,
      role: (m['role_name'] ?? 'membre').toString(),
      status: status,
      regularityTag: (m['regularity_tag'] ?? 'monitoring').toString(),
      regularityTrend: (m['regularity_trend'] ?? 'stable').toString(),
      regularityScore: (m['regularity_score'] as num?)?.toDouble(),
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtTs * 1000),
    );
  }
}
