/// Normalisation téléphone RDC (+243) — même logique que l’ajout membre.
String normalizePhoneRdCongo(String v) {
  var s = v.trim().replaceAll(RegExp(r'[^0-9]'), '');
  if (s.startsWith('0')) {
    s = '243${s.substring(1)}';
  } else if (!s.startsWith('243')) {
    s = '243$s';
  }
  if (s.length > 12) {
    s = s.substring(0, 12);
  }
  return s;
}

bool phonesMatchRdCongo(String input, String stored) {
  if (input.trim().isEmpty || stored.trim().isEmpty) return false;
  return normalizePhoneRdCongo(input) == normalizePhoneRdCongo(stored);
}
