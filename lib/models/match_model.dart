class MatchModel {
  final int? id;
  final int groupId;
  final int round;
  final int homeTeamId;
  final int awayTeamId;
  final int scoreHome;
  final int scoreAway;
  final bool isFinished;

  // Transient fields for display (not stored in DB)
  final String? homeTeamName;
  final String? awayTeamName;

  MatchModel({
    this.id,
    required this.groupId,
    required this.round,
    required this.homeTeamId,
    required this.awayTeamId,
    this.scoreHome = 0,
    this.scoreAway = 0,
    this.isFinished = false,
    this.homeTeamName,
    this.awayTeamName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'round': round,
      'home_team_id': homeTeamId,
      'away_team_id': awayTeamId,
      'score_home': scoreHome,
      'score_away': scoreAway,
      'is_finished': isFinished ? 1 : 0,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] as int?,
      groupId: map['group_id'] as int,
      round: map['round'] as int,
      homeTeamId: map['home_team_id'] as int,
      awayTeamId: map['away_team_id'] as int,
      scoreHome: map['score_home'] as int,
      scoreAway: map['score_away'] as int,
      isFinished: (map['is_finished'] as int) == 1,
      homeTeamName: map['home_team_name'] as String?,
      awayTeamName: map['away_team_name'] as String?,
    );
  }

  MatchModel copyWith({
    int? id,
    int? groupId,
    int? round,
    int? homeTeamId,
    int? awayTeamId,
    int? scoreHome,
    int? scoreAway,
    bool? isFinished,
    String? homeTeamName,
    String? awayTeamName,
  }) {
    return MatchModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      round: round ?? this.round,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      scoreHome: scoreHome ?? this.scoreHome,
      scoreAway: scoreAway ?? this.scoreAway,
      isFinished: isFinished ?? this.isFinished,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
    );
  }
}
