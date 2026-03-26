enum UserRole {
  superAdmin,
  admin,
  pasteur,
  protocole,
  finance,
  autre,
}

UserRole userRoleFromString(String role) {
  switch (role.toLowerCase()) {
    case 'super_admin':
      return UserRole.superAdmin;
    case 'admin':
      return UserRole.admin;
    case 'pasteur':
      return UserRole.pasteur;
    case 'protocole':
      return UserRole.protocole;
    case 'finance':
      return UserRole.finance;
    default:
      return UserRole.autre;
  }
}
