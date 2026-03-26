import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/presence_entry.dart';

final class PresenceStore {
  const PresenceStore();

  static String _k(String churchCode, String activityId) =>
      'presence_${churchCode.trim()}_${activityId.trim()}';

  Future<List<PresenceEntry>> load({
    required String churchCode,
    required String activityId,
  }) async {
    final cc = churchCode.trim();
    final aid = activityId.trim();
    if (cc.isEmpty || aid.isEmpty) return <PresenceEntry>[];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k(cc, aid));
    if (raw == null || raw.trim().isEmpty) return <PresenceEntry>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PresenceEntry>[];
      final out = <PresenceEntry>[];
      for (final e in decoded) {
        if (e is Map) {
          try {
            out.add(PresenceEntry.fromMap(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }
      out.sort((a, b) => b.markedAt.compareTo(a.markedAt));
      return out;
    } catch (_) {
      return <PresenceEntry>[];
    }
  }

  Future<void> upsert(PresenceEntry p) async {
    final cc = p.churchCode.trim();
    final aid = p.activityId.trim();
    if (cc.isEmpty || aid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = await load(churchCode: cc, activityId: aid);

    // 🔒 1 présence par membre par activité (anti-duplication)
    final idx = list.indexWhere((x) => x.memberId == p.memberId);
    if (idx >= 0) {
      list[idx] = p;
    } else {
      list.add(p);
    }

    final maps = list.map((x) => x.toMap()).toList();
    await prefs.setString(_k(cc, aid), jsonEncode(maps));
  }

  Future<void> removeMember({
    required String churchCode,
    required String activityId,
    required String memberId,
  }) async {
    final cc = churchCode.trim();
    final aid = activityId.trim();
    if (cc.isEmpty || aid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = await load(churchCode: cc, activityId: aid);
    list.removeWhere((x) => x.memberId == memberId);

    final maps = list.map((x) => x.toMap()).toList();
    await prefs.setString(_k(cc, aid), jsonEncode(maps));
  }

  Future<void> clearActivity({
    required String churchCode,
    required String activityId,
  }) async {
    final cc = churchCode.trim();
    final aid = activityId.trim();
    if (cc.isEmpty || aid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_k(cc, aid));
  }
}
