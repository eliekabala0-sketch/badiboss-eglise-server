class Member {
  final int id;
  final String nom;
  final String telephone;
  final String statut;
  final String quartier;
  final String role;

  Member({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.statut,
    required this.quartier,
    required this.role,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      nom: json['nom'] ?? '',
      telephone: json['telephone'] ?? '',
      statut: json['statut'] ?? '',
      quartier: json['quartier'] ?? '',
      role: json['role'] ?? 'membre',
    );
  }
}