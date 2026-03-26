enum UserRole {
  superAdmin,
  pasteur,
  admin,
  membre;

  static UserRole fromString(String v) {
    final s = v.trim().toLowerCase();
    switch (s) {
      case 'superadmin':
      case 'super_admin':
      case 'super-admin':
        return UserRole.superAdmin;
      case 'pasteur':
        return UserRole.pasteur;
      case 'admin':
        return UserRole.admin;
      case 'membre':
      case 'member':
        return UserRole.membre;
      default:
        throw StateError('Role invalide: $v');
    }
  }

  /// VERROUILLÉ: ne casse jamais si rôle personnalisé.
  /// - Renvoie membre par défaut si non reconnu
  static UserRole safeFromString(String v) {
    try {
      return fromString(v);
    } catch (_) {
      return UserRole.membre;
    }
  }

  String toJson() {
    switch (this) {
      case UserRole.superAdmin:
        return 'superAdmin';
      case UserRole.pasteur:
        return 'pasteur';
      case UserRole.admin:
        return 'admin';
      case UserRole.membre:
        return 'membre';
    }
  }
}
