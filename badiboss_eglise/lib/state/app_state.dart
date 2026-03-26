import 'package:flutter/foundation.dart';
import '../models/member_info.dart';
import '../models/relation_step.dart';

class AppState extends ChangeNotifier {
  // Petit drapeau SAFE (si une page appelle un truc inexistant, elle peut lire ça)
  bool safeMode = true;

  // Evite les erreurs "getter 'l' isn't defined" -> on fournit un getter l (vide)
  // (On supprimera ça plus tard quand on aura identifié la page qui l'appelle.)
  String get l => '';

  // Données temporaires
  final List<MemberInfo> _members = const [];
  final List<Map<String, dynamic>> _relations = const [];

  List<MemberInfo> membersForChurch(String codeEglise) {
    // SAFE: retourner une liste vide pour compiler
    return _members.where((m) => codeEglise.isNotEmpty).toList(growable: false);
  }

  List<Map<String, dynamic>> relationsForChurch(String codeEglise) {
    // SAFE: retourner une liste vide pour compiler
    return _relations.where((r) => codeEglise.isNotEmpty).toList(growable: false);
  }

  // Exemple de fonction SAFE pour éviter "undefined_method" sur certaines pages
  RelationStep parseRelationStep(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'frere':
        return RelationStep.frere;
      case 'soeur':
        return RelationStep.soeur;
      case 'couple':
        return RelationStep.couple;
      case 'suspendu':
        return RelationStep.suspendu;
      default:
        return RelationStep.inconnu;
    }
  }
}
