class StandingEntry {
  final int teamId;
  final String teamName;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;

  StandingEntry({
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
  });

  factory StandingEntry.fromMap(Map<String, dynamic> map) {
    return StandingEntry(
      teamId: map['team_id'] as int,
      teamName: map['team_name'] as String,
      played: map['played'] as int? ?? 0,
      won: map['won'] as int? ?? 0,
      drawn: map['drawn'] as int? ?? 0,
      lost: map['lost'] as int? ?? 0,
      goalsFor: map['goals_for'] as int? ?? 0,
      goalsAgainst: map['goals_against'] as int? ?? 0,
      goalDifference: map['goal_difference'] as int? ?? 0,
      points: map['points'] as int? ?? 0,
    );
  }
}
