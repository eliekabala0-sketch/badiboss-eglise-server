import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

final class SaaSPlan {
  final String id;
  String name;
  int durationDays;
  double priceUsd;
  bool allowFinance;
  bool allowReports;
  bool allowPresence;
  bool allowMembers;

  SaaSPlan({
    required this.id,
    required this.name,
    required this.durationDays,
    required this.priceUsd,
    required this.allowFinance,
    required this.allowReports,
    required this.allowPresence,
    required this.allowMembers,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'durationDays': durationDays,
        'priceUsd': priceUsd,
        'allowFinance': allowFinance,
        'allowReports': allowReports,
        'allowPresence': allowPresence,
        'allowMembers': allowMembers,
      };

  static SaaSPlan fromMap(Map<String, dynamic> m) => SaaSPlan(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? 'Plan').toString(),
        durationDays: (m['durationDays'] ?? 30) as int,
        priceUsd: ((m['priceUsd'] ?? m['priceCdf'] ?? 0) as num).toDouble(),
        allowFinance: (m['allowFinance'] ?? true) == true,
        allowReports: (m['allowReports'] ?? true) == true,
        allowPresence: (m['allowPresence'] ?? true) == true,
        allowMembers: (m['allowMembers'] ?? true) == true,
      );
}

final class SaaSChurchSubscription {
  final String churchCode;
  String churchName;
  String status; // pending|trial|active|expired|suspended|banned
  String planId;
  String planName;
  int trialDays;
  int graceDays;
  bool reminderEnabled;
  bool contractExempt;
  String paymentState; // paid|unpaid|grace|exempted
  String startedAtIso;
  String expiresAtIso;
  String graceEndsAtIso;
  String source; // super_admin|self_service

  SaaSChurchSubscription({
    required this.churchCode,
    required this.churchName,
    required this.status,
    required this.planId,
    required this.planName,
    required this.trialDays,
    required this.graceDays,
    required this.reminderEnabled,
    required this.contractExempt,
    required this.paymentState,
    required this.startedAtIso,
    required this.expiresAtIso,
    required this.graceEndsAtIso,
    required this.source,
  });

  Map<String, dynamic> toMap() => {
        'churchCode': churchCode,
        'churchName': churchName,
        'status': status,
        'planId': planId,
        'planName': planName,
        'trialDays': trialDays,
        'graceDays': graceDays,
        'reminderEnabled': reminderEnabled,
        'contractExempt': contractExempt,
        'paymentState': paymentState,
        'startedAtIso': startedAtIso,
        'expiresAtIso': expiresAtIso,
        'graceEndsAtIso': graceEndsAtIso,
        'source': source,
      };

  static SaaSChurchSubscription fromMap(Map<String, dynamic> m) =>
      SaaSChurchSubscription(
        churchCode: (m['churchCode'] ?? '').toString(),
        churchName: (m['churchName'] ?? '').toString(),
        status: (m['status'] ?? 'pending').toString(),
        planId: (m['planId'] ?? 'plan_basic').toString(),
        planName: (m['planName'] ?? 'Basic').toString(),
        trialDays: (m['trialDays'] ?? 7) as int,
        graceDays: (m['graceDays'] ?? 2) as int,
        reminderEnabled: (m['reminderEnabled'] ?? true) == true,
        contractExempt: (m['contractExempt'] ?? false) == true,
        paymentState: (m['paymentState'] ?? 'unpaid').toString(),
        startedAtIso: (m['startedAtIso'] ?? '').toString(),
        expiresAtIso: (m['expiresAtIso'] ?? '').toString(),
        graceEndsAtIso: (m['graceEndsAtIso'] ?? '').toString(),
        source: (m['source'] ?? 'super_admin').toString(),
      );
}

final class SaaSStore {
  static const _kPlans = 'saas_plans_v1';
  static const _kChurches = 'saas_churches_v1';
  static const _kGlobal = 'saas_global_settings_v1';

  static Future<List<SaaSPlan>> loadPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPlans);
    if (raw == null || raw.trim().isEmpty) {
      final seed = <SaaSPlan>[
        SaaSPlan(
          id: 'plan_basic',
          name: 'Basic',
          durationDays: 30,
          priceUsd: 19,
          allowFinance: true,
          allowReports: true,
          allowPresence: true,
          allowMembers: true,
        ),
        SaaSPlan(
          id: 'plan_pro',
          name: 'Pro',
          durationDays: 90,
          priceUsd: 49,
          allowFinance: true,
          allowReports: true,
          allowPresence: true,
          allowMembers: true,
        ),
      ];
      await savePlans(seed);
      return seed;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => SaaSPlan.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  static Future<void> savePlans(List<SaaSPlan> plans) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlans, jsonEncode(plans.map((e) => e.toMap()).toList()));
  }

  static Future<List<SaaSChurchSubscription>> loadChurches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kChurches);
    if (raw == null || raw.trim().isEmpty) return <SaaSChurchSubscription>[];
    return (jsonDecode(raw) as List)
        .map((e) => SaaSChurchSubscription.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> saveChurches(List<SaaSChurchSubscription> churches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kChurches, jsonEncode(churches.map((e) => e.toMap()).toList()));
  }

  static Future<Map<String, dynamic>> loadGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGlobal);
    if (raw == null || raw.trim().isEmpty) {
      final seed = <String, dynamic>{
        'trialDaysDefault': 7,
        'graceDaysDefault': 2,
        'reminderEnabled': true,
        'trialModules': <String>['members', 'presence', 'reports'],
      };
      await saveGlobal(seed);
      return seed;
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> saveGlobal(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGlobal, jsonEncode(data));
  }
}
