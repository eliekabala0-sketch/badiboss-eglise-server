// lib/models/member.dart
import 'dart:convert';

enum Sex { male, female, other }
enum MaritalStatus { single, married, divorced, widowed, other }
enum MemberStatus { pending, active, suspended, banned }

Sex sexFromString(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s == 'm' || s == 'male' || s == 'homme') return Sex.male;
  if (s == 'f' || s == 'female' || s == 'femme') return Sex.female;
  return Sex.other;
}

String sexToString(Sex v) {
  switch (v) {
    case Sex.male:
      return 'male';
    case Sex.female:
      return 'female';
    case Sex.other:
      return 'other';
  }
}

MaritalStatus maritalFromString(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s == 'single' || s == 'celibataire' || s == 'célibataire') return MaritalStatus.single;
  if (s == 'married' || s == 'marié' || s == 'marie') return MaritalStatus.married;
  if (s == 'divorced' || s == 'divorcé' || s == 'divorce') return MaritalStatus.divorced;
  if (s == 'widowed' || s == 'veuf' || s == 'veuve') return MaritalStatus.widowed;
  return MaritalStatus.other;
}

String maritalToString(MaritalStatus v) {
  switch (v) {
    case MaritalStatus.single:
      return 'single';
    case MaritalStatus.married:
      return 'married';
    case MaritalStatus.divorced:
      return 'divorced';
    case MaritalStatus.widowed:
      return 'widowed';
    case MaritalStatus.other:
      return 'other';
  }
}

MemberStatus statusFromString(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s == 'pending') return MemberStatus.pending;
  if (s == 'active') return MemberStatus.active;
  if (s == 'suspended') return MemberStatus.suspended;
  if (s == 'banned') return MemberStatus.banned;
  return MemberStatus.pending;
}

String statusToString(MemberStatus v) {
  switch (v) {
    case MemberStatus.pending:
      return 'pending';
    case MemberStatus.active:
      return 'active';
    case MemberStatus.suspended:
      return 'suspended';
    case MemberStatus.banned:
      return 'banned';
  }
}

class Member {
  final String id;

  // Identité
  final String phone;
  final String fullName;

  // Profil civil
  final Sex sex;
  final MaritalStatus maritalStatus;
  final String birthDateIso;

  // Adresse / voisinage
  final String commune;
  final String quartier;
  final String zone;
  final String addressLine;      // avenue/rue + numéro
  final String neighborhood;     // voisinage direct (optionnel)
  final String region;
  final String province;

  // Contexte
  final String churchCode;
  final String role;             // membre / admin / pasteur / secretaire / protocole / finance ...
  final MemberStatus status;     // pending/active/suspended/banned
  final String regularityTag;    // regular | monitoring | irregular
  final String regularityTrend;  // improving | retrograding | stable
  final double? regularityScore; // 0..100

  // Traçabilité
  final String createdBy;
  final DateTime createdAt;

  const Member({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.sex,
    required this.maritalStatus,
    this.birthDateIso = '',
    required this.commune,
    required this.quartier,
    required this.zone,
    required this.addressLine,
    required this.neighborhood,
    required this.region,
    required this.province,
    required this.churchCode,
    required this.role,
    required this.status,
    this.regularityTag = 'monitoring',
    this.regularityTrend = 'stable',
    this.regularityScore,
    required this.createdBy,
    required this.createdAt,
  });

  Member copyWith({
    String? id,
    String? phone,
    String? fullName,
    Sex? sex,
    MaritalStatus? maritalStatus,
    String? birthDateIso,
    String? commune,
    String? quartier,
    String? zone,
    String? addressLine,
    String? neighborhood,
    String? region,
    String? province,
    String? churchCode,
    String? role,
    MemberStatus? status,
    String? regularityTag,
    String? regularityTrend,
    double? regularityScore,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Member(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      sex: sex ?? this.sex,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      birthDateIso: birthDateIso ?? this.birthDateIso,
      commune: commune ?? this.commune,
      quartier: quartier ?? this.quartier,
      zone: zone ?? this.zone,
      addressLine: addressLine ?? this.addressLine,
      neighborhood: neighborhood ?? this.neighborhood,
      region: region ?? this.region,
      province: province ?? this.province,
      churchCode: churchCode ?? this.churchCode,
      role: role ?? this.role,
      status: status ?? this.status,
      regularityTag: regularityTag ?? this.regularityTag,
      regularityTrend: regularityTrend ?? this.regularityTrend,
      regularityScore: regularityScore ?? this.regularityScore,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone': phone,
      'fullName': fullName,
      'sex': sexToString(sex),
      'maritalStatus': maritalToString(maritalStatus),
      'birthDateIso': birthDateIso,
      'commune': commune,
      'quartier': quartier,
      'zone': zone,
      'addressLine': addressLine,
      'neighborhood': neighborhood,
      'region': region,
      'province': province,
      'churchCode': churchCode,
      'role': role,
      'status': statusToString(status),
      'regularityTag': regularityTag,
      'regularityTrend': regularityTrend,
      'regularityScore': regularityScore,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Member fromMap(Map<String, dynamic> m) {
    return Member(
      id: (m['id'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      fullName: (m['fullName'] ?? '').toString(),
      sex: sexFromString(m['sex']?.toString()),
      maritalStatus: maritalFromString(m['maritalStatus']?.toString()),
      birthDateIso: (m['birthDateIso'] ?? '').toString(),
      commune: (m['commune'] ?? '').toString(),
      quartier: (m['quartier'] ?? '').toString(),
      zone: (m['zone'] ?? '').toString(),
      addressLine: (m['addressLine'] ?? '').toString(),
      neighborhood: (m['neighborhood'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      province: (m['province'] ?? '').toString(),
      churchCode: (m['churchCode'] ?? '').toString(),
      role: (m['role'] ?? 'membre').toString(),
      status: statusFromString(m['status']?.toString()),
      regularityTag: (m['regularityTag'] ?? 'monitoring').toString(),
      regularityTrend: (m['regularityTrend'] ?? 'stable').toString(),
      regularityScore: (m['regularityScore'] as num?)?.toDouble(),
      createdBy: (m['createdBy'] ?? '').toString(),
      createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  String normalize(String v) {
    return v
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ô', 'o')
        .replaceAll('î', 'i')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool matchesQuery(String q) {
    final qq = normalize(q);
    if (qq.isEmpty) return true;

    final blob = normalize([
      fullName,
      phone,
      commune,
      quartier,
      zone,
      addressLine,
      neighborhood,
      region,
      province,
      role,
      statusToString(status),
      regularityTag,
      regularityTrend,
      regularityScore?.toString() ?? '',
      sexToString(sex),
      maritalToString(maritalStatus),
    ].join(' | '));

    return blob.contains(qq);
  }

  String toJson() => jsonEncode(toMap());
  static Member fromJson(String s) => fromMap(jsonDecode(s) as Map<String, dynamic>);
}
