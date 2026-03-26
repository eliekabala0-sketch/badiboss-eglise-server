import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../auth/stores/session_store.dart';
import '../core/config.dart';
import '../models/member.dart';
import '../services/local_members_store.dart';
import '../services/member_list_refresh.dart';

class PendingMembersScreen extends StatefulWidget {
  const PendingMembersScreen({super.key});

  @override
  State<PendingMembersScreen> createState() => _PendingMembersScreenState();
}

class _PendingMembersScreenState extends State<PendingMembersScreen> {
  bool _loading = true;
  String _churchCode = '';
  String _role = '';
  String _token = '';
  List<Member> _pending = [];
  String? _error;

  bool get _canValidate =>
      _role == 'admin' || _role == 'pasteur' || _role == 'super_admin';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _role = (prefs.getString('auth_role') ?? '').trim();
    final s = await const SessionStore().read();
    var cc = (s?.churchCode ?? '').trim();
    if (cc.isEmpty) cc = (prefs.getString('auth_church_code') ?? '').trim();
    _churchCode = cc;
    _token = (s?.token ?? '').trim();
    await _reload();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    final s = await const SessionStore().read();
    var cc = (s?.churchCode ?? '').trim();
    if (cc.isEmpty) cc = (prefs.getString('auth_church_code') ?? '').trim();
    _churchCode = cc;
    _token = (s?.token ?? '').trim();

    if (_churchCode.isEmpty) {
      setState(() {
        _pending = [];
        _loading = false;
      });
      return;
    }

    try {
      final api = await _fetchMembersFromApi(token: _token);
      api.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      setState(() {
        _pending = api;
        _loading = false;
      });
    } catch (_) {
      final all = await LocalMembersStore.loadByChurch(_churchCode);
      final p = all.where((m) => m.status == MemberStatus.pending).toList();
      p.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

      setState(() {
        _pending = p;
        _error = 'API indisponible : données locales affichées.';
        _loading = false;
      });
    }
  }

  Future<void> _approve(Member m) async {
    if (!_canValidate) return;
    try {
      await _validateMemberApi(token: _token, memberNumber: m.id, validated: true);
    } catch (_) {
      // fallback local (ne casse pas l’existant)
      await LocalMembersStore.upsert(m.copyWith(status: MemberStatus.active));
    }
    MemberListRefresh.bump();
    await _reload();
  }

  Future<void> _reject(Member m) async {
    if (!_canValidate) return;
    // choix simple: supprimer la demande (API)
    try {
      await _deleteMemberApi(token: _token, memberNumber: m.id);
    } catch (_) {
      await LocalMembersStore.removeById(m.id);
    }
    await _reload();
  }

  Future<void> _validateMemberApi({
    required String token,
    required String memberNumber,
    required bool validated,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');
    if (memberNumber.trim().isEmpty) throw StateError('memberNumber manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/validate');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'member_number': memberNumber.trim(),
            'validated': validated,
          }),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API')
          .toString();
      throw StateError(detail);
    }
  }

  Future<void> _deleteMemberApi({
    required String token,
    required String memberNumber,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');
    if (memberNumber.trim().isEmpty) throw StateError('memberNumber manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/delete');
    final res = await http
        .post(
          uri,
          headers: {
            'accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'member_number': memberNumber.trim()}),
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API')
          .toString();
      throw StateError(detail);
    }
  }

  Future<List<Member>> _fetchMembersFromApi({
    required String token,
  }) async {
    if (token.trim().isEmpty) throw StateError('token manquant');

    final uri = Uri.parse('${Config.baseUrl}/church/members/list').replace(
      queryParameters: {'pending_only': 'true'},
    );

    final res = await http
        .get(
          uri,
          headers: {
            'accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(Duration(seconds: Config.timeoutSeconds));

    final text = res.body.isEmpty ? '{}' : res.body;
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw StateError('Réponse API invalide');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = (decoded['detail'] ?? decoded['message'] ?? 'Erreur API')
          .toString();
      throw StateError(detail);
    }

    final membersRaw = decoded['members'];
    if (membersRaw is! List) return <Member>[];

    return membersRaw
        .whereType<Map>()
        .map((m) => _memberFromApiMap(
              Map<String, dynamic>.from(m),
              churchCode: _churchCode,
            ))
        .where((m) => m.status == MemberStatus.pending)
        .toList();
  }

  Member _memberFromApiMap(
    Map<String, dynamic> m, {
    required String churchCode,
  }) {
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
      commune: (m['commune'] ?? '').toString(),
      quartier: (m['quarter'] ?? '').toString(),
      zone: (m['zone'] ?? '').toString(),
      addressLine: (m['address_line'] ?? '').toString(),
      neighborhood: (m['neighborhood'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      province: (m['province'] ?? '').toString(),
      churchCode: churchCode,
      role: 'membre',
      status: status,
      createdBy: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtTs * 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Membres à valider"),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _churchCode.isEmpty
              ? const Center(child: Text("churchCode vide."))
              : Column(
                  children: [
                    if ((_error ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    Expanded(
                      child: _pending.isEmpty
                          ? const Center(child: Text("Aucun membre en attente."))
                          : ListView.separated(
                              itemCount: _pending.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final m = _pending[i];
                                final info = "${m.phone}\n"
                                    "${m.commune} • ${m.quartier} • ${m.zone}\n"
                                    "sexe: ${m.sex.name} • état civil: ${m.maritalStatus.name}";
                                return ListTile(
                                  title: Text(m.fullName),
                                  subtitle: Text(info),
                                  isThreeLine: true,
                                  trailing: _canValidate
                                      ? Wrap(
                                          spacing: 8,
                                          children: [
                                            IconButton(
                                              tooltip: "Rejeter",
                                              onPressed: () => _reject(m),
                                              icon: const Icon(Icons.close),
                                            ),
                                            FilledButton(
                                              onPressed: () => _approve(m),
                                              child: const Text("Valider"),
                                            ),
                                          ],
                                        )
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
