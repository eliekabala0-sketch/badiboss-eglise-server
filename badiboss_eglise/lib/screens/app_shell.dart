import 'package:flutter/material.dart';

import '../auth/access_control.dart';
import '../auth/models/session.dart';
import '../auth/permissions.dart';
import '../auth/stores/session_store.dart';
import '../core/logout_helper.dart';

// ✅ IMPORTS DES TABS (existant)
import 'tabs/tab_home.dart';
import 'tabs/tab_members.dart';
import 'tabs/tab_presence.dart';
import 'tabs/tab_reports.dart';
import 'tabs/tab_profile.dart';
import '../services/member_list_refresh.dart';
import '../services/church_api.dart';
import '../services/notification_store.dart';
import '../services/session_refresh.dart';

final class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  AppSession? _session;
  String _status = '';
  int _unread = 0;

  // Tabs dynamiques (pilotées par permissions)
  late List<_ShellTab> _tabs;
  final Map<int, Widget> _mountedTabPages = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    _tabs = <_ShellTab>[];
    SessionRefresh.tick.addListener(_onSessionRefreshTick);
    _loadSession();
  }

  @override
  void dispose() {
    SessionRefresh.tick.removeListener(_onSessionRefreshTick);
    super.dispose();
  }

  void _onSessionRefreshTick() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      const store = SessionStore();
      final s = await store.read();
      if (!mounted) return;
      setState(() {
        _session = s;
        _status = '';
      });
      await _buildTabs();
      await _loadUnread();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _status = 'Session introuvable ou invalide.';
        _tabs = <_ShellTab>[_ShellTab.home()];
        _currentIndex = 0;
      });
    }
  }

  Future<void> _loadUnread() async {
    final s = _session;
    if (s == null || (s.churchCode ?? '').trim().isEmpty || s.token.trim().isEmpty) return;
    try {
      final gids = await NotificationStore.loadGroupIdsForCurrentUser();
      final c = await NotificationStore.countUnreadFor(
        churchCode: s.churchCode!.trim(),
        role: s.roleName.toLowerCase(),
        phone: s.phone.trim(),
        groupIds: gids,
      );
      if (!mounted) return;
      setState(() => _unread = c);
    } on SessionExpiredException {
      if (!mounted) return;
      await LogoutHelper.logoutNow(context);
    }
  }

  Future<void> _buildTabs() async {
    final s = _session;

    // Si pas de session => fallback minimal
    if (s == null) {
      setState(() {
        _tabs = <_ShellTab>[_ShellTab.home()];
        _currentIndex = 0;
      });
      return;
    }

    // Tabs de base
    final built = <_ShellTab>[_ShellTab.home()];

    // Membres (viewMembers)
    if (await AccessControl.has(s, Permissions.viewMembers)) {
      built.add(_ShellTab.members());
    }

    // Présences : on affiche l’onglet si au moins une permission présence existe
    final canPresence = await AccessControl.has(s, Permissions.launchActivity) ||
        await AccessControl.has(s, Permissions.markPresence) ||
        await AccessControl.has(s, Permissions.viewPresenceHistory);

    if (canPresence) {
      built.add(_ShellTab.presence());
    }

    // Rapports
    if (await AccessControl.has(s, Permissions.viewReports)) {
      built.add(_ShellTab.reports());
    }

    // Profil (toujours)
    built.add(_ShellTab.profile());

    setState(() {
      _tabs = built;
      if (_currentIndex >= _tabs.length) _currentIndex = 0;
      _mountedTabPages.removeWhere((k, _) => k >= _tabs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (_tabs.isNotEmpty) {
      _mountedTabPages.putIfAbsent(_currentIndex, () => _tabs[_currentIndex].page);
    }

    return Scaffold(
      body: (_tabs.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: List<Widget>.generate(
                _tabs.length,
                (i) => _mountedTabPages[i] ?? const SizedBox.shrink(),
              ),
            ),
      bottomNavigationBar: (_tabs.length <= 1)
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (i) {
                      setState(() => _currentIndex = i);
                      if (i < _tabs.length && _tabs[i].label == 'Membres') {
                        MemberListRefresh.bump();
                      }
                    },
                    type: BottomNavigationBarType.fixed,
                    items: _tabs
                        .map(
                          (t) => BottomNavigationBarItem(
                            icon: t.label == 'Profil'
                                ? Badge(
                                    isLabelVisible: _unread > 0,
                                    label: Text('$_unread'),
                                    child: Icon(t.icon),
                                  )
                                : Icon(t.icon),
                            label: t.label,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
      persistentFooterButtons: [
        if (s != null)
          Text(
            'Connecté: ${s.phone} • ${s.roleName}',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        if (_status.trim().isNotEmpty)
          Text(
            _status,
            style: const TextStyle(fontSize: 11, color: Colors.red),
          ),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Déconnexion'),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    await LogoutHelper.logoutNow(context);
  }
}

final class _ShellTab {
  final String label;
  final IconData icon;
  final Widget page;

  const _ShellTab({
    required this.label,
    required this.icon,
    required this.page,
  });

  static _ShellTab home() => const _ShellTab(
        label: 'Accueil',
        icon: Icons.home,
        page: TabHome(),
      );

  static _ShellTab members() => const _ShellTab(
        label: 'Membres',
        icon: Icons.group,
        page: TabMembers(),
      );

  static _ShellTab presence() => const _ShellTab(
        label: 'Présences',
        icon: Icons.how_to_reg,
        page: TabPresence(),
      );

  static _ShellTab reports() => const _ShellTab(
        label: 'Rapports',
        icon: Icons.bar_chart,
        page: TabReports(),
      );

  static _ShellTab profile() => const _ShellTab(
        label: 'Profil',
        icon: Icons.person,
        page: TabProfile(),
      );
}