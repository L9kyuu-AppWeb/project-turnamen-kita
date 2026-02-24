import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/league_config.dart';
import '../models/group_model.dart';
import '../models/team_model.dart';
import '../models/match_model.dart';
import '../models/standing_entry.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('liga_standing.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE leagues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        pts_win INTEGER NOT NULL DEFAULT 3,
        pts_draw INTEGER NOT NULL DEFAULT 1,
        is_home_away INTEGER NOT NULL DEFAULT 0,
        number_of_groups INTEGER NOT NULL DEFAULT 1,
        teams_per_group INTEGER NOT NULL DEFAULT 4
      )
    ''');

    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        league_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE teams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        round INTEGER NOT NULL,
        home_team_id INTEGER NOT NULL,
        away_team_id INTEGER NOT NULL,
        score_home INTEGER NOT NULL DEFAULT 0,
        score_away INTEGER NOT NULL DEFAULT 0,
        is_finished INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
        FOREIGN KEY (home_team_id) REFERENCES teams(id),
        FOREIGN KEY (away_team_id) REFERENCES teams(id)
      )
    ''');
  }

  // ==================== LEAGUE ====================

  Future<int> insertLeague(LeagueConfig league) async {
    final db = await database;
    return await db.insert('leagues', league.toMap()..remove('id'));
  }

  Future<LeagueConfig?> getLeague(int id) async {
    final db = await database;
    final maps = await db.query('leagues', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return LeagueConfig.fromMap(maps.first);
  }

  Future<List<LeagueConfig>> getAllLeagues() async {
    final db = await database;
    final maps = await db.query('leagues', orderBy: 'id DESC');
    return maps.map((m) => LeagueConfig.fromMap(m)).toList();
  }

  Future<void> deleteLeague(int id) async {
    final db = await database;
    // Delete all related data
    final groups = await db.query('groups', where: 'league_id = ?', whereArgs: [id]);
    for (final g in groups) {
      final groupId = g['id'] as int;
      await db.delete('matches', where: 'group_id = ?', whereArgs: [groupId]);
      await db.delete('teams', where: 'group_id = ?', whereArgs: [groupId]);
    }
    await db.delete('groups', where: 'league_id = ?', whereArgs: [id]);
    await db.delete('leagues', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== GROUP ====================

  Future<int> insertGroup(GroupModel group) async {
    final db = await database;
    return await db.insert('groups', group.toMap()..remove('id'));
  }

  Future<List<GroupModel>> getGroupsByLeague(int leagueId) async {
    final db = await database;
    final maps = await db.query('groups', where: 'league_id = ?', whereArgs: [leagueId]);
    return maps.map((m) => GroupModel.fromMap(m)).toList();
  }

  // ==================== TEAM ====================

  Future<int> insertTeam(TeamModel team) async {
    final db = await database;
    return await db.insert('teams', team.toMap()..remove('id'));
  }

  Future<List<TeamModel>> getTeamsByGroup(int groupId) async {
    final db = await database;
    final maps = await db.query('teams', where: 'group_id = ?', whereArgs: [groupId]);
    return maps.map((m) => TeamModel.fromMap(m)).toList();
  }

  // ==================== MATCH ====================

  Future<void> insertMatch(MatchModel match) async {
    final db = await database;
    await db.insert('matches', match.toMap()..remove('id'));
  }

  Future<void> insertMatches(List<MatchModel> matches) async {
    final db = await database;
    final batch = db.batch();
    for (final m in matches) {
      batch.insert('matches', m.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<List<MatchModel>> getMatchesByGroup(int groupId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT m.*, 
             ht.name as home_team_name, 
             at.name as away_team_name
      FROM matches m
      JOIN teams ht ON m.home_team_id = ht.id
      JOIN teams at ON m.away_team_id = at.id
      WHERE m.group_id = ?
      ORDER BY m.round, m.id
    ''', [groupId]);
    return maps.map((m) => MatchModel.fromMap(m)).toList();
  }

  Future<void> updateMatchScore(int matchId, int scoreHome, int scoreAway) async {
    final db = await database;
    await db.update(
      'matches',
      {
        'score_home': scoreHome,
        'score_away': scoreAway,
        'is_finished': 1,
      },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  Future<void> resetMatch(int matchId) async {
    final db = await database;
    await db.update(
      'matches',
      {
        'score_home': 0,
        'score_away': 0,
        'is_finished': 0,
      },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  // ==================== STANDINGS ====================

  Future<List<StandingEntry>> getStandings(int groupId, int ptsWin, int ptsDraw) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT 
        t.id as team_id,
        t.name as team_name,
        COALESCE(stats.played, 0) as played,
        COALESCE(stats.won, 0) as won,
        COALESCE(stats.drawn, 0) as drawn,
        COALESCE(stats.lost, 0) as lost,
        COALESCE(stats.goals_for, 0) as goals_for,
        COALESCE(stats.goals_against, 0) as goals_against,
        COALESCE(stats.goals_for, 0) - COALESCE(stats.goals_against, 0) as goal_difference,
        (COALESCE(stats.won, 0) * ? + COALESCE(stats.drawn, 0) * ?) as points
      FROM teams t
      LEFT JOIN (
        SELECT 
          team_id,
          COUNT(*) as played,
          SUM(CASE WHEN result = 'W' THEN 1 ELSE 0 END) as won,
          SUM(CASE WHEN result = 'D' THEN 1 ELSE 0 END) as drawn,
          SUM(CASE WHEN result = 'L' THEN 1 ELSE 0 END) as lost,
          SUM(gf) as goals_for,
          SUM(ga) as goals_against
        FROM (
          SELECT 
            home_team_id as team_id,
            score_home as gf,
            score_away as ga,
            CASE 
              WHEN score_home > score_away THEN 'W'
              WHEN score_home = score_away THEN 'D'
              ELSE 'L'
            END as result
          FROM matches 
          WHERE group_id = ? AND is_finished = 1
          UNION ALL
          SELECT 
            away_team_id as team_id,
            score_away as gf,
            score_home as ga,
            CASE 
              WHEN score_away > score_home THEN 'W'
              WHEN score_away = score_home THEN 'D'
              ELSE 'L'
            END as result
          FROM matches 
          WHERE group_id = ? AND is_finished = 1
        ) match_results
        GROUP BY team_id
      ) stats ON t.id = stats.team_id
      WHERE t.group_id = ?
      ORDER BY points DESC, goal_difference DESC, goals_for DESC, t.name ASC
    ''', [ptsWin, ptsDraw, groupId, groupId, groupId]);

    return maps.map((m) => StandingEntry.fromMap(m)).toList();
  }

  // ==================== UTILITY ====================

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }

  Future<void> deleteDatabase_() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'liga_standing.db');
    await deleteDatabase(path);
    _database = null;
  }
}
