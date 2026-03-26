import 'package:flutter/foundation.dart';

/// Incrémenté après ajout / validation membre pour forcer un reload des listes (IndexedStack).
final class MemberListRefresh {
  MemberListRefresh._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void bump() {
    tick.value++;
  }
}
