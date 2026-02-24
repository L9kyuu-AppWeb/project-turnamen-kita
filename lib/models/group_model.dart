class GroupModel {
  final int? id;
  final int leagueId;
  final String name;

  GroupModel({
    this.id,
    required this.leagueId,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'league_id': leagueId,
      'name': name,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      id: map['id'] as int?,
      leagueId: map['league_id'] as int,
      name: map['name'] as String,
    );
  }
}
