import '../auth/models/user_role.dart';
import '../auth/stores/session_store.dart';
import 'church_api.dart';

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
        durationDays: (m['durationDays'] is int)
            ? m['durationDays'] as int
            : int.tryParse((m['durationDays'] ?? '30').toString()) ?? 30,
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
  String status;
  String planId;
  String planName;
  int trialDays;
  int graceDays;
  bool reminderEnabled;
  bool contractExempt;
  String paymentState;
  String startedAtIso;
  String expiresAtIso;
  String graceEndsAtIso;
  String source;

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
        trialDays: (m['trialDays'] is int)
            ? m['trialDays'] as int
            : int.tryParse((m['trialDays'] ?? '7').toString()) ?? 7,
        graceDays: (m['graceDays'] is int)
            ? m['graceDays'] as int
            : int.tryParse((m['graceDays'] ?? '2').toString()) ?? 2,
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
  static List<SaaSPlan> _defaultPlans() => <SaaSPlan>[
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

  static Future<List<SaaSPlan>> loadPlans() async {
    try {
      final s = await const SessionStore().read();
      if ((s?.token ?? '').trim().isEmpty) return _defaultPlans();
      final dec = await ChurchApi.getJson('/church/billing/subscription');
      final pl = dec['plans'];
      if (pl is List && pl.isNotEmpty) {
        return pl
            .whereType<Map>()
            .map((e) => SaaSPlan.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return _defaultPlans();
  }

  static Future<void> savePlans(List<SaaSPlan> plans) async {
    await persistSuperSaasState(plans: plans);
  }

  /// Églises connues du serveur (SQLite), sans abonnement SaaS détaillé.
  static Future<List<SaaSChurchSubscription>> loadChurches() async {
    try {
      final dec = await ChurchApi.getPublicJson('/public/churches/list');
      final ch = dec['churches'];
      if (ch is! List) return <SaaSChurchSubscription>[];
      return ch.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        final code = (m['church_code'] ?? '').toString();
        final suspended = m['is_suspended'] == 1 || m['is_suspended'] == true;
        final now = DateTime.now();
        return SaaSChurchSubscription(
          churchCode: code,
          churchName: (m['name'] ?? code).toString(),
          status: suspended ? 'suspended' : 'active',
          planId: 'plan_basic',
          planName: 'Basic',
          trialDays: 7,
          graceDays: 2,
          reminderEnabled: true,
          contractExempt: false,
          paymentState: 'unpaid',
          startedAtIso: now.toIso8601String(),
          expiresAtIso: now.add(const Duration(days: 7)).toIso8601String(),
          graceEndsAtIso: now.add(const Duration(days: 9)).toIso8601String(),
          source: 'server',
        );
      }).toList();
    } catch (_) {
      return <SaaSChurchSubscription>[];
    }
  }

  static Future<void> saveChurches(List<SaaSChurchSubscription> churches) async {
    await persistSuperSaasState(churchSubscriptions: churches);
  }

  static Future<Map<String, dynamic>> loadGlobal() async {
    try {
      final s = await const SessionStore().read();
      if ((s?.token ?? '').trim().isEmpty || s!.role != UserRole.superAdmin) {
        return _defaultGlobal();
      }
      final dec = await ChurchApi.getJson('/super/saas/state');
      final g = dec['saas_global'];
      if (g is Map && g.isNotEmpty) {
        return Map<String, dynamic>.from(g);
      }
    } catch (_) {}
    return _defaultGlobal();
  }

  static Map<String, dynamic> _defaultGlobal() => <String, dynamic>{
        'trialDaysDefault': 7,
        'graceDaysDefault': 2,
        'reminderEnabled': true,
        'trialModules': <String>['members', 'presence', 'reports'],
        'allowSelfRegistration': true,
        'requireValidation': true,
        'enableGuestScan': true,
      };

  static Future<void> saveGlobal(Map<String, dynamic> data) async {
    await persistSuperSaasState(saasGlobal: data);
  }

  /// Fusionne avec l’état SaaS serveur (super admin uniquement).
  static Future<void> persistSuperSaasState({
    List<SaaSPlan>? plans,
    List<SaaSChurchSubscription>? churchSubscriptions,
    Map<String, dynamic>? saasGlobal,
  }) async {
    final s = await const SessionStore().read();
    if (s == null || s.role != UserRole.superAdmin || s.token.trim().isEmpty) {
      return;
    }
    if (plans != null && churchSubscriptions != null && saasGlobal != null) {
      await ChurchApi.postJson('/super/saas/state', {
        'plans': plans.map((e) => e.toMap()).toList(),
        'church_subscriptions': churchSubscriptions.map((e) => e.toMap()).toList(),
        'saas_global': saasGlobal,
      });
      return;
    }
    final cur = await ChurchApi.getJson('/super/saas/state');
    final body = <String, dynamic>{
      'plans': plans != null
          ? plans.map((e) => e.toMap()).toList()
          : (cur['plans'] is List ? cur['plans'] : []),
      'church_subscriptions': churchSubscriptions != null
          ? churchSubscriptions.map((e) => e.toMap()).toList()
          : (cur['church_subscriptions'] is List ? cur['church_subscriptions'] : []),
      'saas_global': saasGlobal ??
          (cur['saas_global'] is Map
              ? Map<String, dynamic>.from(cur['saas_global'] as Map)
              : <String, dynamic>{}),
    };
    await ChurchApi.postJson('/super/saas/state', body);
  }
}
