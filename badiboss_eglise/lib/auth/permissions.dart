final class Permissions {
  // Gestion accès (AuthAccount)
  static const String manageAccess = 'manage_access';

  // Gestion rôles + permissions
  static const String manageRoles = 'manage_roles';

  // Membres
  static const String viewMembers = 'view_members';
  static const String editMembers = 'edit_members';

  // Présences / activités
  static const String launchActivity = 'launch_activity';
  static const String markPresence = 'mark_presence';
  static const String viewPresenceHistory = 'view_presence_history';
  static const String exportPresence = 'export_presence';

  // Rapports
  static const String viewReports = 'view_reports';
  static const String exportReports = 'export_reports';

  // Églises (global)
  static const String manageChurches = 'manage_churches';
  static const String banUnban = 'ban_unban';

  // =========================
  // ✅ AJOUTS MÉTIER (VERROUILLÉ)
  // =========================

  // Finance / Trésorerie
  static const String viewFinance = 'view_finance';
  static const String manageFinance = 'manage_finance';
  static const String exportFinance = 'export_finance';

  // Secrétariat (documents, gestion admin interne)
  static const String viewSecretariat = 'view_secretariat';
  static const String manageSecretariat = 'manage_secretariat';

  // Communiqués / Annonces
  static const String viewAnnouncements = 'view_announcements';
  static const String manageAnnouncements = 'manage_announcements';

  // Messagerie membres (optionnel, contrôlé)
  static const String viewMessages = 'view_messages';
  static const String sendMessages = 'send_messages';
  static const String moderateMessages = 'moderate_messages';
  static const String replyMessages = 'reply_messages';
  static const String viewGroups = 'view_groups';
  static const String manageGroups = 'manage_groups';

  static const List<String> all = <String>[
    // existant
    manageAccess,
    manageRoles,
    viewMembers,
    editMembers,
    launchActivity,
    markPresence,
    viewPresenceHistory,
    exportPresence,
    viewReports,
    exportReports,
    manageChurches,
    banUnban,

    // nouveaux
    viewFinance,
    manageFinance,
    exportFinance,
    viewSecretariat,
    manageSecretariat,
    viewAnnouncements,
    manageAnnouncements,
    viewMessages,
    sendMessages,
    moderateMessages,
    replyMessages,
    viewGroups,
    manageGroups,
  ];
}