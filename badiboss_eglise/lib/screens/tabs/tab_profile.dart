import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../auth/models/session.dart';
import '../../auth/stores/session_store.dart';
import '../../core/logout_helper.dart';
import '../../core/config.dart';
import '../notifications_page.dart';
import '../../services/notification_store.dart';

final class TabProfile extends StatefulWidget {
  const TabProfile({super.key});

  @override
  State<TabProfile> createState() => _TabProfileState();
}

final class _TabProfileState extends State<TabProfile> {
  AppSession? _session;
  String _status = '';
  int _unread = 0;
  Map<String, dynamic>? _apiUser;
  Map<String, dynamic>? _apiMember;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      const store = SessionStore();
      final s = await store.read();
      if (!mounted) return;
      setState(() {
        _session = s;
        _status = '';
      });
      if (s != null && s.token.trim().isNotEmpty) {
        await _loadApiProfile(s.token.trim());
      }
      if (s != null && (s.churchCode ?? '').trim().isNotEmpty) {
        final gids = await NotificationStore.loadGroupIdsForCurrentUser();
        final c = await NotificationStore.countUnreadFor(
          churchCode: s.churchCode!.trim(),
          role: s.roleName.toLowerCase(),
          phone: s.phone.trim(),
          groupIds: gids,
        );
        if (mounted) setState(() => _unread = c);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _status = 'Session introuvable.';
      });
    }
  }

  Future<void> _loadApiProfile(String token) async {
    try {
      final uri = Uri.parse('${Config.baseUrl}/me/profile');
      final res = await http.get(uri, headers: {
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(Duration(seconds: Config.timeoutSeconds));
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      if (decoded is! Map) return;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() => _status = (decoded['detail'] ?? decoded['message'] ?? 'Erreur profil').toString());
        return;
      }
      setState(() {
        _apiUser = decoded['user'] is Map ? Map<String, dynamic>.from(decoded['user'] as Map) : null;
        _apiMember = decoded['member'] is Map ? Map<String, dynamic>.from(decoded['member'] as Map) : null;
      });
    } catch (e) {
      setState(() => _status = 'Profil API indisponible: $e');
    }
  }

  Future<void> _logout() async {
    await LogoutHelper.logoutNow(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final u = _apiUser;
    final m = _apiMember;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Profil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: (s == null)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Aucune session active.'),
                      if (_status.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Recharger'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Téléphone: ${s.phone}'),
                      const SizedBox(height: 6),
                      if (u != null) ...[
                        Text('Nom: ${(u['full_name'] ?? '-').toString()}'),
                        const SizedBox(height: 6),
                      ],
                      Text('Rôle système: ${s.role.toJson()}'),
                      const SizedBox(height: 6),
                      Text('Rôle réel: ${s.roleName}'),
                      const SizedBox(height: 6),
                      Text('Église: ${s.churchCode ?? "-"}'),
                      const SizedBox(height: 6),
                      Text('Créé: ${DateTime.fromMillisecondsSinceEpoch(s.createdAtEpochMs)}'),
                      if (m != null) ...[
                        const Divider(),
                        Text('Profil membre: ${(m['member_number'] ?? '-').toString()}'),
                        const SizedBox(height: 4),
                        Text('Statut: ${(m['status'] ?? '-').toString()}'),
                        const SizedBox(height: 4),
                        Text('Commune/Quartier: ${(m['commune'] ?? '-')} • ${(m['quarter'] ?? '-')}'),
                        const SizedBox(height: 4),
                        Text('Téléphone membre: ${(m['phone'] ?? '-').toString()}'),
                      ],
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 12),
        ListTile(
          leading: Badge(
            isLabelVisible: _unread > 0,
            label: Text('$_unread'),
            child: const Icon(Icons.notifications_active_rounded),
          ),
          title: const Text('Notifications'),
          subtitle: const Text('Voir les éléments non lus'),
          onTap: () async {
            await Navigator.of(context).pushNamed(NotificationsPage.routeName);
            await _load();
          },
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Déconnexion'),
          ),
        ),
      ],
    );
  }
}
