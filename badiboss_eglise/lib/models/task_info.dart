class TaskInfo {
  final String id;
  final String titre;
  bool locked;
  String? assignedToUserId;

  TaskInfo({
    required this.id,
    required this.titre,
    this.locked = false,
    this.assignedToUserId,
  });
}
