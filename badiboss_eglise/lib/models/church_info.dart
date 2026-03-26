import 'app_enums.dart';

class ChurchInfo {
  final String codeEglise;
  final String nom;
  bool validated;
  bool banned;
  SubscriptionPlan plan;
  DateTime? paidUntil;

  ChurchInfo({
    required this.codeEglise,
    required this.nom,
    this.validated = false,
    this.banned = false,
    this.plan = SubscriptionPlan.mensuel,
    this.paidUntil,
  });

  bool get isExpired {
    if (paidUntil == null) return false;
    return DateTime.now().isAfter(paidUntil!);
  }

  String get code => codeEglise; // compat anciennes pages
}
