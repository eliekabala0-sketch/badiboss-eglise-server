import '../models/user_role.dart';

/// VERROUILLÉ : Pas de duplication du modèle Member.
/// On définit un "profil minimal" d'auth issu de votre Member existant.
abstract interface class MembersRepository {
  /// Retourne null si aucun utilisateur correspondant.
  ///
  /// VERROUILLÉ :
  /// - phone doit être déjà validé
  /// - churchCode obligatoire (sauf super admin qui ne passe pas ici)
  Future<MemberAuthView?> findByPhoneAndChurch({
    required String phone,
    required String churchCode,
  });
}

/// Vue minimale (ne remplace pas Member) pour authentifier sans dupliquer.
final class MemberAuthView {
  final String phone;
  final String churchCode;
  final String passwordHashOrPlain;
  final UserRole role;
  final bool isBanned;
  final bool isActive;

  const MemberAuthView({
    required this.phone,
    required this.churchCode,
    required this.passwordHashOrPlain,
    required this.role,
    required this.isBanned,
    required this.isActive,
  });
}