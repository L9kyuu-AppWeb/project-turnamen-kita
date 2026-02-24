class LeagueConfig {
  final int? id;
  final String name;
  final String type; // 'league' or 'group'
  final int ptsWin;
  final int ptsDraw;
  final bool isHomeAway;
  final int numberOfGroups;
  final int teamsPerGroup;

  LeagueConfig({
    this.id,
    required this.name,
    required this.type,
    this.ptsWin = 3,
    this.ptsDraw = 1,
    this.isHomeAway = false,
    this.numberOfGroups = 1,
    this.teamsPerGroup = 4,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'pts_win': ptsWin,
      'pts_draw': ptsDraw,
      'is_home_away': isHomeAway ? 1 : 0,
      'number_of_groups': numberOfGroups,
      'teams_per_group': teamsPerGroup,
    };
  }

  factory LeagueConfig.fromMap(Map<String, dynamic> map) {
    return LeagueConfig(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      ptsWin: map['pts_win'] as int,
      ptsDraw: map['pts_draw'] as int,
      isHomeAway: (map['is_home_away'] as int) == 1,
      numberOfGroups: map['number_of_groups'] as int,
      teamsPerGroup: map['teams_per_group'] as int,
    );
  }

  LeagueConfig copyWith({
    int? id,
    String? name,
    String? type,
    int? ptsWin,
    int? ptsDraw,
    bool? isHomeAway,
    int? numberOfGroups,
    int? teamsPerGroup,
  }) {
    return LeagueConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ptsWin: ptsWin ?? this.ptsWin,
      ptsDraw: ptsDraw ?? this.ptsDraw,
      isHomeAway: isHomeAway ?? this.isHomeAway,
      numberOfGroups: numberOfGroups ?? this.numberOfGroups,
      teamsPerGroup: teamsPerGroup ?? this.teamsPerGroup,
    );
  }
}
