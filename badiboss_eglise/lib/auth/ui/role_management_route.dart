import 'package:flutter/material.dart';

import 'role_management_page.dart';

final class RoleManagementRoute {
  static const String name = '/admin/roles';

  static Route<void> route(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const RoleManagementPage(),
    );
  }
}
