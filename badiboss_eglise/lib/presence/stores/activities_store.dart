import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';

final class ActivitiesStore {
  const ActivitiesStore();

  static String _k(String churchCode) => 'activities_${churchCode.trim()}';

  Future<List<Activity>> load(String churchCode) async {
    final cc = churchCode.trim();
    if (cc.isEmpty) return <Activity>[];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_k(cc));
    if (raw == null || raw.trim().isEmpty) return <Activity>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Activity>[];
      final out = <Activity>[];
      for (final e in decoded) {
        if (e is Map) {
          try {
            out.add(Activity.fromMap(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }
      // tri: plus récent d'abord
      out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return out;
    } catch (_) {
      return <Activity>[];
    }
  }

  Future<void> upsert(Activity a) async {
    final cc = a.churchCode.trim();
    if (cc.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = await load(cc);

    final idx = list.indexWhere((x) => x.id == a.id);
    if (idx >= 0) {
      list[idx] = a;
    } else {
      list.add(a);
    }

    final maps = list.map((x) => x.toMap()).toList();
    await prefs.setString(_k(cc), jsonEncode(maps));
  }

  Future<void> remove(String churchCode, String activityId) async {
    final cc = churchCode.trim();
    if (cc.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = await load(cc);
    list.removeWhere((x) => x.id == activityId);

    final maps = list.map((x) => x.toMap()).toList();
    await prefs.setString(_k(cc), jsonEncode(maps));
  }

  Future<Activity?> findOpen(String churchCode) async {
    final list = await load(churchCode);
    try {
      return list.firstWhere((a) => a.status == ActivityStatus.open);
    } catch (_) {
      return null;
    }
  }
}
