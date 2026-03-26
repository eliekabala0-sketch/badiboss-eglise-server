class MemberInfo {
  final String id;
  final String nom;
  final String telephone;

  // Champs optionnels (au cas où)
  final String? sexe;

  const MemberInfo({
    required this.id,
    required this.nom,
    required this.telephone,
    this.sexe,
  });
}
