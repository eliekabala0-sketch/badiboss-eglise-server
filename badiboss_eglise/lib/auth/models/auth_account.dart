import 'dart:convert';

/// 🔒 VERROUILLÉ : Compatibilité totale (ancien + nouveau)
/// - Ancien UI/Service attend: isActive / isBanned / passwordPlain
/// - Nouveau modèle utilise: status + roleName + fullName + id + createdAt + createdBy
class AuthAccount {
  final String id;
  final String churchCode;

  final String phone;
  final String fullName;

  /// Role système (superAdmin/pasteur/admin/membre) OU rôle personnalisé
  final String roleName;

  /// Statut du compte: pending/active/suspended/banned
  final String status;

  /// Créateur (phone du pasteur/admin/superadmin)
  final String createdBy;
  final DateTime createdAt;

  /// 🔒 Ancien champ (compat)
  final String passwordPlain;

  /// ⚠️ IMPORTANT :
  /// - Constructeur NON const (DateTime pas const) => corrige "Invalid constant value"
  /// - Ré-accepte isActive/isBanned pour l’ancien UI sans casser le nouveau modèle
  AuthAccount({
    this.id = '',
    this.churchCode = '',
    required this.phone,
    this.fullName = '',
    String? roleName,
    String? status,
    this.createdBy = '',
    DateTime? createdAt,
    String? passwordPlain,

    // ✅ Compat anciens params (appelés depuis access_management_page.dart)
    bool? isActive,
    bool? isBanned,
  })  : roleName = (roleName ?? 'membre'),
        passwordPlain = (passwordPlain ?? ''),
        createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        status = _resolveStatus(status: status, isActive: isActive, isBanned: isBanned);

  // =========================
  // ✅ COMPAT GETTERS (ancien)
  // =========================
  bool get isActive => status.trim().toLowerCase() == 'active';
  bool get isBanned => status.trim().toLowerCase() == 'banned';

  // =========================
  // ✅ Helpers
  // =========================
  static String _resolveStatus({
    required String? status,
    required bool? isActive,
    required bool? isBanned,
  }) {
    final s = (status ?? '').trim().toLowerCase();
    if (s.isNotEmpty) return s;

    // fallback depuis l’ancien modèle
    if (isBanned == true) return 'banned';
    if (isActive == true) return 'active';
    return 'pending';
  }

  AuthAccount copyWith({
    String? id,
    String? churchCode,
    String? phone,
    String? fullName,
    String? roleName,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    String? passwordPlain,
  }) {
    return AuthAccount(
      id: id ?? this.id,
      churchCode: churchCode ?? this.churchCode,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      roleName: roleName ?? this.roleName,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      passwordPlain: passwordPlain ?? this.passwordPlain,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'churchCode': churchCode,
        'phone': phone,
        'fullName': fullName,
        'roleName': roleName,
        'status': status,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),

        // compat
        'passwordPlain': passwordPlain,
      };

  /// 🔒 fromMap support:
  /// - Nouveau: roleName/status/fullName/id/createdAt/createdBy
  /// - Ancien: role/status/active/banned/passwordPlain...
  static AuthAccount fromMap(Map<String, dynamic> m) {
    final rn = (m['roleName'] ?? m['role'] ?? 'membre').toString();

    // status priorité, sinon fallback depuis bool active/banned
    String st = (m['status'] ?? '').toString();
    if (st.trim().isEmpty) {
      final banned = (m['isBanned'] ?? m['banned'] ?? false) == true;
      final active = (m['isActive'] ?? m['active'] ?? false) == true;
      st = banned
          ? 'banned'
          : (active ? 'active' : 'pending');
    }

    final createdAtRaw = (m['createdAt'] ?? '').toString();
    final createdAt = DateTime.tryParse(createdAtRaw) ??
        DateTime.fromMillisecondsSinceEpoch(
          (m['createdAtEpochMs'] is int) ? (m['createdAtEpochMs'] as int) : 0,
        );

    return AuthAccount(
      id: (m['id'] ?? '').toString(),
      churchCode: (m['churchCode'] ?? '').toString(),
      phone: (m['phone'] ?? '').toString(),
      fullName: (m['fullName'] ?? m['name'] ?? '').toString(),
      roleName: rn,
      status: st,
      createdBy: (m['createdBy'] ?? '').toString(),
      createdAt: createdAt,
      passwordPlain: (m['passwordPlain'] ?? m['password'] ?? '').toString(),
    );
  }

  String toJson() => jsonEncode(toMap());
  static AuthAccount fromJson(String s) =>
      fromMap(jsonDecode(s) as Map<String, dynamic>);
}