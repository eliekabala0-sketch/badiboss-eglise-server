import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';

import 'auth/ui/access_management_route.dart';
import 'auth/ui/role_management_route.dart';

import 'screens/modules/finance_page.dart';
import 'screens/modules/secretariat_page.dart';
import 'screens/modules/announcements_page.dart';
import 'screens/modules/messages_page.dart';
import 'screens/modules/subscription_page.dart';
import 'screens/member_groups_page.dart';
import 'screens/notifications_page.dart';

import 'presence/ui/activities_page.dart';
import 'presence/ui/presence_mark_page.dart';
import 'presence/ui/presence_history_page.dart';
import 'presence/ui/presence_export_page.dart';

import 'reports/ui/reports_page.dart';
import 'reports/ui/reports_export_page.dart';

import 'screens/tabs/tab_members.dart';

import 'theme/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
      ],
      child: const BadibossEgliseApp(),
    ),
  );
}

class BadibossEgliseApp extends StatelessWidget {
  const BadibossEgliseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Badiboss Église',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
      routes: {
        '/members': (_) => const TabMembers(),
        '/members/edit': (_) => const TabMembers(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/members' || settings.name == '/members/edit') {
          return MaterialPageRoute(builder: (_) => const TabMembers());
        }

        if (settings.name == AccessManagementRoute.name) {
          return AccessManagementRoute.route(settings);
        }
        if (settings.name == RoleManagementRoute.name) {
          return RoleManagementRoute.route(settings);
        }

        if (settings.name == FinancePage.routeName) {
          return MaterialPageRoute(builder: (_) => const FinancePage());
        }
        if (settings.name == SecretariatPage.routeName) {
          return MaterialPageRoute(builder: (_) => const SecretariatPage());
        }
        if (settings.name == AnnouncementsPage.routeName) {
          return MaterialPageRoute(builder: (_) => const AnnouncementsPage());
        }
        if (settings.name == MessagesPage.routeName) {
          return MaterialPageRoute(builder: (_) => const MessagesPage());
        }
        if (settings.name == SubscriptionPage.routeName) {
          return MaterialPageRoute(builder: (_) => const SubscriptionPage());
        }
        if (settings.name == MemberGroupsPage.routeName) {
          return MaterialPageRoute(builder: (_) => const MemberGroupsPage());
        }
        if (settings.name == NotificationsPage.routeName) {
          return MaterialPageRoute(builder: (_) => const NotificationsPage());
        }

        if (settings.name == ActivitiesPage.routeName) {
          return MaterialPageRoute(builder: (_) => const ActivitiesPage());
        }
        if (settings.name == PresenceMarkPage.routeName) {
          return MaterialPageRoute(builder: (_) => const PresenceMarkPage());
        }
        if (settings.name == PresenceHistoryPage.routeName) {
          return MaterialPageRoute(builder: (_) => const PresenceHistoryPage());
        }
        if (settings.name == PresenceExportPage.routeName) {
          return MaterialPageRoute(builder: (_) => const PresenceExportPage());
        }

        if (settings.name == ReportsPage.routeName) {
          return MaterialPageRoute(builder: (_) => const ReportsPage());
        }
        if (settings.name == ReportsExportPage.routeName) {
          return MaterialPageRoute(builder: (_) => const ReportsExportPage());
        }

        return null;
      },
    );
  }
}