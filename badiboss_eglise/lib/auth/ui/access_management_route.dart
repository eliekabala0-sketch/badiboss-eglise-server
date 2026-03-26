import 'package:flutter/material.dart';

import 'access_management_page.dart';

final class AccessManagementRoute {
  static const String name = '/admin/access';

  static Route<void> route(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const AccessManagementPage(),
    );
  }
}
