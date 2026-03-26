import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/member.dart';

class LocalMembersStore {
  static const String _kMembersPrefix = 'members_'; // members_<churchCode>
  static const String _kIndexPrefix = 'members_index_'; // members_index_<churchCode>
  static const String _kCurrentChurchKey = 'current_church_code';

  static String _safe(String? s) => (s ?? '').trim();
  static String _norm(String? s) => _safe(s).toLowerCase();

  static String _membersKey(String churchCode) => '$_kMembersPrefix${_safe(churchCode)}';
  static String _indexKey(String churchCode) => '$_kIndexPrefix${_safe(churchCode)}';

  static String newId() {
    final r = Random();
    final n = 100000 + r.nextInt(900000);
    final t = DateTime.now().millisecondsSinceEpoch;
    return 'm_${t}_$n';
  }

  static Future<String> _resolveChurchCode({String? explicit}) async {
    final e = _safe(explicit);
    if (e.isNotEmpty) return e;
    final prefs = await SharedPreferences.getInstance();
    return _safe(prefs.getString(_kCurrentChurchKey));
  }

  static Future<void> setCurrentChurchCode(String churchCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentChurchKey, _safe(churchCode));
  }

  static Future<List<Map<String, dynamic>>> _readMaps(
    SharedPreferences prefs,
    String churchCode,
  ) async {
    final key = _membersKey(churchCode);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> _writeMaps(
    SharedPreferences prefs,
    String churchCode,
    List<Map<String, dynamic>> list,
  ) async {
    final key = _membersKey(churchCode);
    await prefs.setString(key, jsonEncode(list));
  }

  static Future<List<Member>> loadByChurch(String churchCode) async {
    final cc = await _resolveChurchCode(explicit: churchCode);
    if (_safe(cc).isEmpty) return <Member>[];

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);

    final out = <Member>[];
    for (final m in maps) {
      try {
        out.add(Member.fromMap(m));
      } catch (_) {}
    }
    return out;
  }

  static Future<void> upsert(Member member, {String? churchCode}) async {
    var cc = _safe(churchCode);
    if (cc.isEmpty) {
      cc = _safe(member.churchCode);
      if (cc.isEmpty) cc = await _resolveChurchCode();
    }
    if (_safe(cc).isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);

    final jm = member.toMap();
    final id = _safe(jm['id']?.toString());
    if (id.isEmpty) return;

    final idx = maps.indexWhere((x) => _safe(x['id']?.toString()) == id);
    if (idx >= 0) {
      maps[idx] = jm;
    } else {
      maps.add(jm);
    }

    await _writeMaps(prefs, cc, maps);
    await rebuildIndex(cc);
  }

  static Future<void> removeById(String id, {String? churchCode}) async {
    final cc = await _resolveChurchCode(explicit: churchCode);
    if (_safe(cc).isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);
    maps.removeWhere((x) => _safe(x['id']?.toString()) == _safe(id));

    await _writeMaps(prefs, cc, maps);
    await rebuildIndex(cc);
  }

  /// Voisins = par neighborhood (si rempli) sinon fallback quartier.
  static Future<List<Member>> neighborsOf(Member me, {String? churchCode}) async {
    var cc = _safe(churchCode);
    if (cc.isEmpty) cc = _safe(me.churchCode);
    cc = await _resolveChurchCode(explicit: cc);
    if (_safe(cc).isEmpty) return <Member>[];

    String neigh = _norm(me.neighborhood);
    if (neigh.isEmpty) neigh = _norm(me.quartier);
    if (neigh.isEmpty) return <Member>[];

    final ids = await loadNeighborhoodIndex(cc, neigh);
    if (ids.isEmpty) return <Member>[];

    final all = await loadByChurch(cc);
    return all.where((m) => ids.contains(_safe(m.id))).toList();
  }

  static Future<void> rebuildIndex(String churchCode) async {
    final cc = await _resolveChurchCode(explicit: churchCode);
    if (_safe(cc).isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final maps = await _readMaps(prefs, cc);

    final index = <String, List<String>>{};
    for (final x in maps) {
      final id = _safe(x['id']?.toString());
      if (id.isEmpty) continue;

      final neighborhood = _norm(x['neighborhood']?.toString());
      final quartier = _norm(x['quartier']?.toString());

      // priorité: neighborhood sinon quartier
      final key = neighborhood.isNotEmpty ? neighborhood : quartier;
      if (key.isEmpty) continue;

      index.putIfAbsent(key, () => <String>[]);
      index[key]!.add(id);
    }

    await prefs.setString(_indexKey(cc), jsonEncode(index));
  }

  static Future<List<String>> loadNeighborhoodIndex(String churchCode, String neighborhood) async {
    final cc = await _resolveChurchCode(explicit: churchCode);
    if (_safe(cc).isEmpty) return <String>[];

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey(cc));
    if (raw == null || raw.trim().isEmpty) return <String>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String>[];
      final map = Map<String, dynamic>.from(decoded);

      final n = _norm(neighborhood);
      final v = map[n];
      if (v is! List) return <String>[];

      return v.map((e) => _safe(e.toString())).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return <String>[];
    }
  }
}
