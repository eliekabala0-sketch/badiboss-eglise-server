import '../models/member.dart';

/// Voisins = même [Member.neighborhood] si renseigné, sinon même [Member.quartier]
/// (logique alignée sur l’ancien index local, appliquée sur une liste serveur).
List<Member> neighborsFor(Member me, List<Member> all) {
  String norm(String? s) => (s ?? '').trim().toLowerCase();
  var key = norm(me.neighborhood);
  if (key.isEmpty) key = norm(me.quartier);
  if (key.isEmpty) return <Member>[];

  final myId = me.id.trim();
  return all.where((m) {
    if (m.id.trim() == myId) return false;
    var nk = norm(m.neighborhood);
    if (nk.isEmpty) nk = norm(m.quartier);
    return nk.isNotEmpty && nk == key;
  }).toList();
}
