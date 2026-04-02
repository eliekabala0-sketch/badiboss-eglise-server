import 'package:flutter/material.dart';

import '../../auth/models/session.dart';
import '../../auth/permissions.dart';
import '../../auth/stores/session_store.dart';
import '../../auth/ui/permission_gate.dart';

import '../../auth/ui/access_management_route.dart';
import '../../auth/ui/role_management_route.dart';

import '../../presence/ui/activities_page.dart';
import '../../presence/ui/presence_history_page.dart';
import '../../presence/ui/presence_export_page.dart';

import '../../reports/ui/reports_page.dart';
import '../../reports/ui/reports_export_page.dart';

import '../../theme/app_colors.dart';
import '../modules/finance_page.dart';
import '../modules/secretariat_page.dart';
import '../modules/announcements_page.dart';
import '../modules/messages_page.dart';
import '../modules/subscription_page.dart';
import '../member_groups_page.dart';
import '../notifications_page.dart';
import '../../services/notification_store.dart';
import '../pages/relations_page.dart';
import '../pages/pasteur_irregulars_page.dart';

class TabHome extends StatefulWidget {
  const TabHome({super.key});

  @override
  State<TabHome> createState() => _TabHomeState();
}

class _TabHomeState extends State<TabHome> {
  AppSession? _session;
  bool _loading = true;
  String _status = '';
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = '';
    });

    try {
      final s = await const SessionStore().read();
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
        if (s == null) _status = 'Session introuvable. Reconnecte-toi.';
      });
      await _loadUnread();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _loading = false;
        _status = 'Erreur session: $e';
      });
    }
  }

  void _go(String route) => Navigator.of(context).pushNamed(route);

  Future<void> _loadUnread() async {
    final s = _session;
    if (s == null || (s.churchCode ?? '').trim().isEmpty || s.token.trim().isEmpty) return;
    final gids = await NotificationStore.loadGroupIdsForCurrentUser();
    final count = await NotificationStore.countUnreadFor(
      churchCode: s.churchCode!.trim(),
      role: s.roleName.toLowerCase(),
      phone: s.phone.trim(),
      groupIds: gids,
    );
    if (!mounted) return;
    setState(() => _unread = count);
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (s == null)
              ? _SessionError(status: _status, onRetry: _load)
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _HomeHeader(session: s, scheme: scheme)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.onSurface.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tableau de bord centralisé: membres, présences, finances et communication.',
                                  style: TextStyle(
                                    color: AppColors.mutedText,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Modules',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildListDelegate([
                          _FeatureCard(
                            title: 'Membres',
                            subtitle: 'Liste et recherche',
                            icon: Icons.groups_rounded,
                            color: scheme.primary,
                            onTap: () => _go('/members'),
                          ),
                          _FeatureCard(
                            title: 'Présences',
                            subtitle: 'Activités',
                            icon: Icons.event_available_rounded,
                            color: AppColors.burgundy,
                            onTap: () => _go(ActivitiesPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Historique',
                            subtitle: 'Présences passées',
                            icon: Icons.history_rounded,
                            color: scheme.primary.withOpacity(0.85),
                            onTap: () => _go(PresenceHistoryPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Exporter',
                            subtitle: 'Présences CSV',
                            icon: Icons.download_rounded,
                            color: AppColors.gold,
                            onTap: () => _go(PresenceExportPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Rapports',
                            subtitle: 'Stats et PDF',
                            icon: Icons.analytics_rounded,
                            color: scheme.primary,
                            onTap: () => _go(ReportsPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Rapports',
                            subtitle: 'Export PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            color: AppColors.burgundy.withOpacity(0.9),
                            onTap: () => _go(ReportsExportPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Annonces',
                            subtitle: 'Communiqués',
                            icon: Icons.campaign_rounded,
                            color: AppColors.gold,
                            onTap: () => _go(AnnouncementsPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Messages',
                            subtitle: 'Conversations',
                            icon: Icons.chat_bubble_rounded,
                            color: scheme.primary,
                            onTap: () => _go(MessagesPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Notifications',
                            subtitle: _unread > 0 ? '$_unread non lues' : 'Aucune non lue',
                            icon: Icons.notifications_active_rounded,
                            color: const Color(0xFF00897B),
                            onTap: () async {
                              await Navigator.of(context).pushNamed(NotificationsPage.routeName);
                              await _loadUnread();
                            },
                          ),
                          _FeatureCard(
                            title: 'Groupes',
                            subtitle: 'Adhésion et suivi',
                            icon: Icons.group_work_rounded,
                            color: const Color(0xFF6D4C41),
                            onTap: () => _go(MemberGroupsPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Finance',
                            subtitle: 'Trésorerie',
                            icon: Icons.account_balance_wallet_rounded,
                            color: const Color(0xFF1B4332),
                            onTap: () => _go(FinancePage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Secrétariat',
                            subtitle: 'Documents / PV',
                            icon: Icons.folder_special_rounded,
                            color: AppColors.burgundy,
                            onTap: () => _go(SecretariatPage.routeName),
                          ),
                          _FeatureCard(
                            title: 'Abonnement',
                            subtitle: 'Paiement / expiration',
                            icon: Icons.workspace_premium_rounded,
                            color: const Color(0xFF3F51B5),
                            onTap: () => _go(SubscriptionPage.routeName),
                          ),
                          if (s.roleName.toLowerCase().contains('pasteur') ||
                              s.roleName.toLowerCase().contains('admin'))
                            _FeatureCard(
                              title: 'Relations',
                              subtitle: 'Fréquentation / fiançailles / mariage',
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFF7A1E2C),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RelationsPage()),
                              ),
                            ),
                          if (s.roleName.toLowerCase().contains('pasteur') ||
                              s.roleName.toLowerCase().contains('admin'))
                            _FeatureCard(
                              title: 'Irréguliers',
                              subtitle: 'Assignation berger & suivi',
                              icon: Icons.volunteer_activism_rounded,
                              color: const Color(0xFF1E3A8A),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PasteurIrregularsPage(
                                    codeEglise: s.churchCode ?? _superAdminChurchFallback(s),
                                  ),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Administration',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          PermissionGate(
                            permission: Permissions.manageAccess,
                            child: _AdminTile(
                              title: 'Gestion des accès',
                              subtitle: 'Activer, bannir, suspendre',
                              icon: Icons.lock_open_rounded,
                              onTap: () => _go(AccessManagementRoute.name),
                            ),
                          ),
                          PermissionGate(
                            permission: Permissions.manageRoles,
                            child: _AdminTile(
                              title: 'Gestion des rôles',
                              subtitle: 'Rôles et permissions',
                              icon: Icons.badge_rounded,
                              onTap: () => _go(RoleManagementRoute.name),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }
}

String _superAdminChurchFallback(AppSession s) {
  return (s.churchCode ?? '').trim().isEmpty ? 'EGLISE001' : s.churchCode!;
}

class _SessionError extends StatelessWidget {
  final String status;
  final VoidCallback onRetry;

  const _SessionError({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded, size: 56, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              status.isEmpty ? 'Session introuvable.' : status,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurface.withOpacity(0.85), height: 1.35),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Recharger'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final AppSession session;
  final ColorScheme scheme;

  const _HomeHeader({required this.session, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final cc = session.churchCode ?? '—';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            scheme.primary.withBlue((scheme.primary.blue + 25).clamp(0, 255)),
            const Color(0xFF1B4332),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/badiboss_logo.jpg',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.church_rounded, size: 40, color: scheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Badiboss Église',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bienvenue',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Église',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cc,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 18, color: Colors.white.withOpacity(0.85)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.phone,
                            style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 18, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text(
                          session.roleName,
                          style: TextStyle(
                            color: AppColors.gold.withOpacity(0.95),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.onSurface.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.north_east_rounded, size: 16, color: color.withOpacity(0.75)),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurface.withOpacity(0.55),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.onSurface.withOpacity(0.06)),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.onSurface.withOpacity(0.55))),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.onSurface.withOpacity(0.35)),
          onTap: onTap,
        ),
      ),
    );
  }
}
