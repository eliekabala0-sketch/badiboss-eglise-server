import 'dart:convert';

enum ActivityStatus { open, closed }

ActivityStatus activityStatusFromString(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s == 'closed') return ActivityStatus.closed;
  return ActivityStatus.open;
}

String activityStatusToString(ActivityStatus v) {
  switch (v) {
    case ActivityStatus.open:
      return 'open';
    case ActivityStatus.closed:
      return 'closed';
  }
}

final class Activity {
  final String id;
  final String churchCode;

  final String title; // ex: Culte du dimanche
  final String type;  // ex: culte, réunion, évangélisation...

  final ActivityStatus status;

  final String createdByPhone;
  final DateTime startedAt;
  final DateTime? closedAt;

  const Activity({
    required this.id,
    required this.churchCode,
    required this.title,
    required this.type,
    required this.status,
    required this.createdByPhone,
    required this.startedAt,
    required this.closedAt,
  });

  Activity copyWith({
    String? id,
    String? churchCode,
    String? title,
    String? type,
    ActivityStatus? status,
    String? createdByPhone,
    DateTime? startedAt,
    DateTime? closedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      churchCode: churchCode ?? this.churchCode,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      createdByPhone: createdByPhone ?? this.createdByPhone,
      startedAt: startedAt ?? this.startedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'churchCode': churchCode,
        'title': title,
        'type': type,
        'status': activityStatusToString(status),
        'createdByPhone': createdByPhone,
        'startedAt': startedAt.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toMap());

  static Activity fromMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString().trim();
    final cc = (m['churchCode'] ?? '').toString().trim();
    final title = (m['title'] ?? '').toString();
    final type = (m['type'] ?? '').toString();
    final status = activityStatusFromString(m['status']?.toString());
    final createdBy = (m['createdByPhone'] ?? '').toString();
    final startedAt = DateTime.tryParse((m['startedAt'] ?? '').toString()) ?? DateTime.now();
    final closedAtRaw = (m['closedAt'] ?? '').toString();
    final closedAt = closedAtRaw.trim().isEmpty ? null : DateTime.tryParse(closedAtRaw);

    if (id.isEmpty) throw StateError('Activity invalide: id vide');
    if (cc.isEmpty) throw StateError('Activity invalide: churchCode vide');

    return Activity(
      id: id,
      churchCode: cc,
      title: title,
      type: type,
      status: status,
      createdByPhone: createdBy,
      startedAt: startedAt,
      closedAt: closedAt,
    );
  }

  static Activity fromJsonString(String s) {
    final decoded = jsonDecode(s);
    if (decoded is! Map) throw StateError('Activity invalide: JSON non-map');
    return fromMap(Map<String, dynamic>.from(decoded));
  }
}
