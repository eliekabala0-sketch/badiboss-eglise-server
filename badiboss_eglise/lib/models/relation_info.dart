import 'app_enums.dart';

class RelationInfo {
  final String id;
  final String memberAId;
  final String memberBId;
  RelationStep step;
  DateTime updatedAt;

  RelationInfo({
    required this.id,
    required this.memberAId,
    required this.memberBId,
    required this.step,
    required this.updatedAt,
  });

  String get memberAID => memberAId; // compat si faute existe
  String get memberBID => memberBId; // compat
}
