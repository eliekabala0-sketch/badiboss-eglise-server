class Session {
  final String token;
  final String role;
  final String? phone;
  final String? name;

  const Session({
    required this.token,
    required this.role,
    this.phone,
    this.name,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      token: (json['token'] ?? '').toString(),
      role: (json['role'] ?? 'membre').toString(),
      phone: json['phone']?.toString(),
      name: json['name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'role': role,
      'phone': phone,
      'name': name,
    };
  }
}
