class TeamModel {
  final int? id;
  final int groupId;
  final String name;

  TeamModel({
    this.id,
    required this.groupId,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
    };
  }

  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map['id'] as int?,
      groupId: map['group_id'] as int,
      name: map['name'] as String,
    );
  }
}
