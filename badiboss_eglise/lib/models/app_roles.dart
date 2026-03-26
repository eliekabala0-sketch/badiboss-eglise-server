/// Base officielle des rôles & tâches (Badiboss Église)
/// - role : pasteur / admin / protocole / membre / super_admin
/// - adminTask : presence / membres / finances / annonces / general
///
/// IMPORTANT:
/// - Toujours parser avec parseRole/parseAdminTask (évite les erreurs de casse/espaces)
/// - Ne jamais coder des if(role == "...") partout sans passer par ici.

enum AppRole {
  superAdmin,
  pasteur,
  admin,
  protocole,
  membre,
}

enum AdminTask {
  general,
  presence,
  membres,
  finances,
  annonces,
}

AppRole parseRole(String? raw) {
  final r = (raw ?? '').trim().toLowerCase();
  switch (r) {
    case 'super_admin':
    case 'superadmin':
    case 'super admin':
      return AppRole.superAdmin;

    case 'pasteur':
    case 'pastor':
      return AppRole.pasteur;

    case 'admin':
    case 'administrateur':
    case 'administrator':
      return AppRole.admin;

    case 'protocole':
      return AppRole.protocole;

    case 'membre':
    case 'member':
      return AppRole.membre;

    default:
      // Sécurité : si on ne reconnaît pas, on retombe sur membre
      return AppRole.membre;
  }
}

AdminTask parseAdminTask(String? raw) {
  final t = (raw ?? '').trim().toLowerCase();
  switch (t) {
    case 'presence':
    case 'presences':
    case 'attendance':
      return AdminTask.presence;

    case 'membres':
    case 'members':
    case 'membre':
      return AdminTask.membres;

    case 'finance':
    case 'finances':
    case 'offrandes':
    case 'dons':
      return AdminTask.finances;

    case 'annonce':
    case 'annonces':
    case 'communication':
      return AdminTask.annonces;

    case 'general':
    case '':
    default:
      return AdminTask.general;
  }
}

String roleToString(AppRole role) {
  switch (role) {
    case AppRole.superAdmin:
      return 'super_admin';
    case AppRole.pasteur:
      return 'pasteur';
    case AppRole.admin:
      return 'admin';
    case AppRole.protocole:
      return 'protocole';
    case AppRole.membre:
      return 'membre';
  }
}

String adminTaskToString(AdminTask task) {
  switch (task) {
    case AdminTask.general:
      return 'general';
    case AdminTask.presence:
      return 'presence';
    case AdminTask.membres:
      return 'membres';
    case AdminTask.finances:
      return 'finances';
    case AdminTask.annonces:
      return 'annonces';
  }
}
