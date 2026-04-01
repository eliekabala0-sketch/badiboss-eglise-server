import 'package:flutter/foundation.dart';

/// À incrémenter quand [SessionStore] est mis à jour (ex. rôle changé côté serveur) pour
/// recharger les onglets de l’[AppShell].
final class SessionRefresh {
  SessionRefresh._();

  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static void bump() {
    tick.value++;
  }
}
