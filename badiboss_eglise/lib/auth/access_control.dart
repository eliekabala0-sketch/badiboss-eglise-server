import 'models/session.dart';
import 'models/user_role.dart';
import 'permissions.dart';
import 'stores/role_policy_store.dart';

final class AccessControl {
  static Set<String> defaultPermissionsFor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Permissions.all.toSet();
      case UserRole.pasteur:
        return <String>{
          Permissions.manageAccess,
          Permissions.manageRoles,
          Permissions.viewMembers,
          Permissions.editMembers,
          Permissions.launchActivity,
          Permissions.markPresence,
          Permissions.viewPresenceHistory,
          Permissions.exportPresence,
          Permissions.viewReports,
          Permissions.exportReports,
          Permissions.banUnban,
          Permissions.viewFinance,
          Permissions.manageFinance,
          Permissions.exportFinance,
          Permissions.viewGroups,
          Permissions.manageGroups,
        };
      case UserRole.admin:
        return <String>{
          Permissions.manageAccess,
          Permissions.viewMembers,
          Permissions.editMembers,
          Permissions.launchActivity,
          Permissions.markPresence,
          Permissions.viewPresenceHistory,
          Permissions.exportPresence,
          Permissions.viewReports,
          Permissions.exportReports,
          Permissions.viewGroups,
          Permissions.manageGroups,
        };
      case UserRole.membre:
        return <String>{
          Permissions.viewMembers,
          Permissions.viewPresenceHistory,
          Permissions.viewGroups,
        };
    }
  }

  /// VERROUILLÉ:
  /// - superAdmin => tout
  /// - autres => churchCode obligatoire
  /// - rôles personnalisés => policy d'église (fallback sur defaults)
  static Future<bool> has(AppSession session, String permission) async {
    if (session.role == UserRole.superAdmin) return true;

    final cc = session.churchCode;
    if (cc == null || cc.trim().isEmpty) return false;

    final policy = await RolePolicyStore.read(cc);
    final roleName = session.roleName.trim();

    final customPerms = policy.permissionsOf(roleName);
    if (customPerms.isNotEmpty) {
      return customPerms.contains(permission);
    }

    final defaults = defaultPermissionsFor(session.role);
    // VERROUILLÉ: cas "finance" côté backend -> roleName 'finance' -> session.role retombe souvent sur membre.
    // On s'aligne sur le rôle finance responsable si roleName == finance.
    final rn = session.roleName.trim().toLowerCase();
    // Financier = fonction, pas identité exclusive : garde l’accès « membre » (groupes, annonces, messages…).
    final financeDefaults = <String>{
      Permissions.viewFinance,
      Permissions.manageFinance,
      Permissions.exportFinance,
      Permissions.viewMembers,
      Permissions.viewPresenceHistory,
      Permissions.viewGroups,
      Permissions.viewAnnouncements,
      Permissions.viewMessages,
    };
    if (rn == 'finance') {
      return financeDefaults.contains(permission);
    }
    if (rn == 'protocole') {
      final p = <String>{
        Permissions.viewMembers,
        Permissions.markPresence,
        Permissions.viewPresenceHistory,
      };
      return p.contains(permission);
    }
    if (rn == 'secretaire' || rn == 'secrétaire') {
      final p = <String>{
        Permissions.viewMembers,
        Permissions.editMembers,
        Permissions.viewSecretariat,
        Permissions.manageSecretariat,
        Permissions.viewAnnouncements,
        Permissions.manageAnnouncements,
      };
      return p.contains(permission);
    }
    if (rn == 'admin') {
      final p = defaultPermissionsFor(UserRole.admin);
      return p.contains(permission);
    }
    if (rn == 'group_leader' || rn == 'responsable_groupe') {
      final p = <String>{
        Permissions.viewGroups,
        Permissions.manageGroups,
        Permissions.viewMessages,
      };
      return p.contains(permission);
    }

    return defaults.contains(permission);
  }
}
