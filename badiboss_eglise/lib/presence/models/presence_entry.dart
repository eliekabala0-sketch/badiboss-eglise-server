import 'dart:convert';

final class PresenceEntry {
  final String id;
  final String churchCode;

  final String activityId;

  final String memberId;
  final String memberPhone;
  final String memberName;

  final String markedByPhone;
  final DateTime markedAt;

  const PresenceEntry({
    required this.id,
    required this.churchCode,
    required this.activityId,
    required this.memberId,
    required this.memberPhone,
    required this.memberName,
    required this.markedByPhone,
    required this.markedAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'churchCode': churchCode,
        'activityId': activityId,
        'memberId': memberId,
        'memberPhone': memberPhone,
        'memberName': memberName,
        'markedByPhone': markedByPhone,
        'markedAt': markedAt.toIso8601String(),
      };

  String toJsonString() => jsonEncode(toMap());

  static PresenceEntry fromMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString().trim();
    final cc = (m['churchCode'] ?? '').toString().trim();
    final activityId = (m['activityId'] ?? '').toString().trim();

    final memberId = (m['memberId'] ?? '').toString();
    final memberPhone = (m['memberPhone'] ?? '').toString();
    final memberName = (m['memberName'] ?? '').toString();

    final markedBy = (m['markedByPhone'] ?? '').toString();
    final markedAt = DateTime.tryParse((m['markedAt'] ?? '').toString()) ?? DateTime.now();

    if (id.isEmpty) throw StateError('Presence invalide: id vide');
    if (cc.isEmpty) throw StateError('Presence invalide: churchCode vide');
    if (activityId.isEmpty) throw StateError('Presence invalide: activityId vide');

    return PresenceEntry(
      id: id,
      churchCode: cc,
      activityId: activityId,
      memberId: memberId,
      memberPhone: memberPhone,
      memberName: memberName,
      markedByPhone: markedBy,
      markedAt: markedAt,
    );
  }

  static PresenceEntry fromJsonString(String s) {
    final decoded = jsonDecode(s);
    if (decoded is! Map) throw StateError('Presence invalide: JSON non-map');
    return fromMap(Map<String, dynamic>.from(decoded));
  }
}
