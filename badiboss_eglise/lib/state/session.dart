class Session {
  final String token;
  final String role; // super_admin | pasteur | admin | membre
  final String churchCode;
  final String phone;

  const Session({
    required this.token,
    required this.role,
    required this.churchCode,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'role': role,
        'churchCode': churchCode,
        'phone': phone,
      };

  static Session fromJson(Map<String, dynamic> json) {
    return Session(
      token: (json['token'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      churchCode: (json['churchCode'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }
}
