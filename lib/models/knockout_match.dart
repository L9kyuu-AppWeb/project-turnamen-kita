/// Satu pertandingan babak gugur.
///
/// `stage` menentukan tahap:
/// - `1` : Semifinal — kedua tim sudah ditentukan sejak bracket dibuat.
/// - `2` : Final — tim diisi otomatis setelah kedua semifinal selesai.
class KnockoutMatch {
  final int? id;
  final int leagueId;
  final int stage; // 1 = semifinal, 2 = final
  final int? homeTeamId;
  final int? awayTeamId;
  final int scoreHome;
  final int scoreAway;
  final bool isFinished;

  // Data tampilan
  final String? homeTeamName;
  final String? awayTeamName;
  final String? homeTeamSource; // mis. "1A", "2B"
  final String? awayTeamSource;

  const KnockoutMatch({
    this.id,
    required this.leagueId,
    required this.stage,
    this.homeTeamId,
    this.awayTeamId,
    this.scoreHome = 0,
    this.scoreAway = 0,
    this.isFinished = false,
    this.homeTeamName,
    this.awayTeamName,
    this.homeTeamSource,
    this.awayTeamSource,
  });

  factory KnockoutMatch.fromMap(Map<String, dynamic> map) {
    final homeName = map['home_team_name'] as String?;
    final awayName = map['away_team_name'] as String?;
    final homeSrc = map['home_team_source'] as String?;
    final awaySrc = map['away_team_source'] as String?;
    return KnockoutMatch(
      id: map['id'] as int?,
      leagueId: map['league_id'] as int,
      stage: map['stage'] as int,
      homeTeamId: map['home_team_id'] as int?,
      awayTeamId: map['away_team_id'] as int?,
      scoreHome: map['score_home'] as int? ?? 0,
      scoreAway: map['score_away'] as int? ?? 0,
      isFinished: (map['is_finished'] as int? ?? 0) == 1,
      homeTeamName: homeName,
      awayTeamName: awayName,
      homeTeamSource: homeSrc,
      awayTeamSource: awaySrc,
    );
  }

  String get label => stage == 1 ? 'Semifinal' : 'Final';

  /// Nama tim yang tampil: nama asli, atau asal grup kalau belum diketahui.
  String get homeLabel => homeTeamName ?? homeTeamSource ?? '?';
  String get awayLabel => awayTeamName ?? awayTeamSource ?? '?';

  KnockoutMatch copyWith({
    int? id,
    int? leagueId,
    int? stage,
    int? homeTeamId,
    int? awayTeamId,
    int? scoreHome,
    int? scoreAway,
    bool? isFinished,
    String? homeTeamName,
    String? awayTeamName,
    String? homeTeamSource,
    String? awayTeamSource,
  }) {
    return KnockoutMatch(
      id: id ?? this.id,
      leagueId: leagueId ?? this.leagueId,
      stage: stage ?? this.stage,
      homeTeamId: homeTeamId ?? this.homeTeamId,
      awayTeamId: awayTeamId ?? this.awayTeamId,
      scoreHome: scoreHome ?? this.scoreHome,
      scoreAway: scoreAway ?? this.scoreAway,
      isFinished: isFinished ?? this.isFinished,
      homeTeamName: homeTeamName ?? this.homeTeamName,
      awayTeamName: awayTeamName ?? this.awayTeamName,
      homeTeamSource: homeTeamSource ?? this.homeTeamSource,
      awayTeamSource: awayTeamSource ?? this.awayTeamSource,
    );
  }
}

/// Ringkasan status babak gugur untuk sebuah liga.
class KnockoutStatus {
  /// Babak gugur sudah dibuat (ada minimal satu semifinal).
  final bool created;

  /// Semua pertandingan fase grup sudah selesai.
  final bool groupStageFinished;

  /// Semua tim yang lolos sudah diketahui (grup tidak boleh seri di peringkat 1/2).
  final bool qualifiersResolved;

  /// Jumlah tim yang lolos dari grup (mis. 4 untuk semifinal).
  final int qualifiedCount;

  /// Tim yang lolos: nama + asal grup + peringkat.
  final List<QualifiedTeam> qualifiers;

  const KnockoutStatus({
    required this.created,
    required this.groupStageFinished,
    required this.qualifiersResolved,
    required this.qualifiedCount,
    required this.qualifiers,
  });

  static const empty = KnockoutStatus(
    created: false,
    groupStageFinished: false,
    qualifiersResolved: false,
    qualifiedCount: 0,
    qualifiers: [],
  );
}

class QualifiedTeam {
  final int teamId;
  final String teamName;
  final String groupName;
  final int position; // 1 = juara grup, 2 = runner up
  final int points;
  final int goalDifference;

  const QualifiedTeam({
    required this.teamId,
    required this.teamName,
    required this.groupName,
    required this.position,
    required this.points,
    required this.goalDifference,
  });
}