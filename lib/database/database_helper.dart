import 'package:sqflite/sqflite.dart';
// ignore: unnecessary_import
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/league_config.dart';
import '../models/group_model.dart';
import '../models/team_model.dart';
import '../models/match_model.dart';
import '../models/standing_entry.dart';
import '../models/knockout_match.dart';

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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
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

    // Versi 2: babak gugur (knockout)
    await _createKnockoutTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createKnockoutTable(db);
    }
  }

  Future<void> _createKnockoutTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS knockout_matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        league_id INTEGER NOT NULL,
        stage INTEGER NOT NULL DEFAULT 1,
        home_team_id INTEGER,
        away_team_id INTEGER,
        score_home INTEGER NOT NULL DEFAULT 0,
        score_away INTEGER NOT NULL DEFAULT 0,
        is_finished INTEGER NOT NULL DEFAULT 0,
        home_team_source TEXT,
        away_team_source TEXT,
        FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE,
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
    await db.delete('knockout_matches', where: 'league_id = ?', whereArgs: [id]);
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

  /// Ringkasan liga untuk daftar di HomeScreen: jumlah grup, jumlah tim,
  /// jumlah pertandingan, dan berapa yang sudah selesai.
  Future<Map<String, int>> getLeagueSummary(int leagueId) async {
    final db = await database;

    final groups = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM groups WHERE league_id = ?',
          [leagueId],
        )) ??
        0;

    final teams = Sqflite.firstIntValue(await db.rawQuery(
          '''
          SELECT COUNT(*) FROM teams t
          JOIN groups g ON t.group_id = g.id
          WHERE g.league_id = ?
          ''',
          [leagueId],
        )) ??
        0;

    final matches = Sqflite.firstIntValue(await db.rawQuery(
          '''
          SELECT COUNT(*) FROM matches m
          JOIN groups g ON m.group_id = g.id
          WHERE g.league_id = ?
          ''',
          [leagueId],
        )) ??
        0;

    final finished = Sqflite.firstIntValue(await db.rawQuery(
          '''
          SELECT COUNT(*) FROM matches m
          JOIN groups g ON m.group_id = g.id
          WHERE g.league_id = ? AND m.is_finished = 1
          ''',
          [leagueId],
        )) ??
        0;

    return {
      'groups': groups,
      'teams': teams,
      'matches': matches,
      'finished': finished,
    };
  }

  /// Duplikasi liga: salin liga + grup + tim + jadwal, tapi skor di-nol-kan
  /// sehingga bisa dipakai sebagai musim baru. Mengembalikan id liga baru.
  Future<int> duplicateLeague(int leagueId, {String? newName}) async {
    final db = await database;

    return db.transaction<int>((txn) async {
      final leagueRows = await txn.query('leagues',
          where: 'id = ?', whereArgs: [leagueId], limit: 1);
      if (leagueRows.isEmpty) {
        throw Exception('Liga tidak ditemukan');
      }

      final src = leagueRows.first;

      final newLeagueId = await txn.insert('leagues', {
        'name': newName ?? '${src['name']} (Salinan)',
        'type': src['type'],
        'pts_win': src['pts_win'],
        'pts_draw': src['pts_draw'],
        'is_home_away': src['is_home_away'],
        'number_of_groups': src['number_of_groups'],
        'teams_per_group': src['teams_per_group'],
      });

      final groupRows =
          await txn.query('groups', where: 'league_id = ?', whereArgs: [leagueId]);

      for (final g in groupRows) {
        final srcGroupId = g['id'] as int;

        final newGroupId = await txn.insert('groups', {
          'league_id': newLeagueId,
          'name': g['name'],
        });

        // Salin tim pada grup ini dan simpan pemetaan id lama -> baru.
        final teamRows = await txn
            .query('teams', where: 'group_id = ?', whereArgs: [srcGroupId]);

        final Map<int, int> teamIdMap = {};
        for (final t in teamRows) {
          final newTeamId = await txn.insert('teams', {
            'group_id': newGroupId,
            'name': t['name'],
          });
          teamIdMap[t['id'] as int] = newTeamId;
        }

        // Salin jadwal dengan skor direset ke 0 - 0.
        final matchRows = await txn
            .query('matches', where: 'group_id = ?', whereArgs: [srcGroupId]);

        for (final m in matchRows) {
          final home = teamIdMap[m['home_team_id'] as int];
          final away = teamIdMap[m['away_team_id'] as int];
          if (home == null || away == null) continue; // tim tidak lengkap

          await txn.insert('matches', {
            'group_id': newGroupId,
            'round': m['round'],
            'home_team_id': home,
            'away_team_id': away,
            'score_home': 0,
            'score_away': 0,
            'is_finished': 0,
          });
        }
      }

      return newLeagueId;
    });
  }

  /// Ubah nama liga.
  Future<void> renameLeague(int leagueId, String newName) async {
    final db = await database;
    await db.update('leagues', {'name': newName},
        where: 'id = ?', whereArgs: [leagueId]);
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

  /// Reset semua skor di satu grup — untuk lanjutan liga / musim baru
  /// tanpa menghapus tim & jadwal.
  ///
  /// Kalau liga ini punya bracket babak gugur, bracket ikut dihapus: kualifikasi
  /// semifinal/final ditentukan dari klasemen akhir semua grup, jadi skor satu
  /// grup yang di-reset membuat bracket lama tidak valid.
  Future<int> resetMatchesByGroup(int groupId) async {
    final db = await database;

    final leagueId = await db.transaction<int?>((txn) async {
      final rows = await txn.query(
        'groups',
        columns: ['league_id'],
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['league_id'] as int;
    });

    final n = await db.update(
      'matches',
      {
        'score_home': 0,
        'score_away': 0,
        'is_finished': 0,
      },
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    if (leagueId != null) {
      await deleteKnockoutMatches(leagueId);
    }
    return n;
  }

  /// Reset semua skor di seluruh grup pada satu liga.
  ///
  /// Babak gugur ikut dihapus karena peserta semifinal/final ditentukan dari
  /// klasemen akhir grup — kalau klasemen di-nol-kan, bracket lama jadi tidak
  /// valid dan hanya membingungkan.
  Future<int> resetMatchesByLeague(int leagueId) async {
    final db = await database;
    final groups = await db.query('groups',
        columns: ['id'], where: 'league_id = ?', whereArgs: [leagueId]);
    int total = 0;
    for (final g in groups) {
      final groupId = g['id'] as int;
      final n = await db.update(
        'matches',
        {
          'score_home': 0,
          'score_away': 0,
          'is_finished': 0,
        },
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      total += n;
    }
    await deleteKnockoutMatches(leagueId);
    return total;
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

  // ==================== KNOCKOUT ====================

  Future<List<KnockoutMatch>> getKnockoutMatches(int leagueId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT k.*,
             ht.name as home_team_name,
             at.name as away_team_name
      FROM knockout_matches k
      LEFT JOIN teams ht ON k.home_team_id = ht.id
      LEFT JOIN teams at ON k.away_team_id = at.id
      WHERE k.league_id = ?
      ORDER BY k.stage, k.id
    ''', [leagueId]);

    return maps.map((m) => KnockoutMatch.fromMap(m)).toList();
  }

  Future<int> insertKnockoutMatches(List<KnockoutMatch> matches) async {
    final db = await database;
    final batch = db.batch();
    for (final m in matches) {
      batch.insert('knockout_matches', {
        'league_id': m.leagueId,
        'stage': m.stage,
        'home_team_id': m.homeTeamId,
        'away_team_id': m.awayTeamId,
        'score_home': 0,
        'score_away': 0,
        'is_finished': 0,
        'home_team_source': m.homeTeamSource,
        'away_team_source': m.awayTeamSource,
      });
    }
    final results = await batch.commit();
    return results.length;
  }

  Future<void> updateKnockoutMatchScore(
      int matchId, int scoreHome, int scoreAway) async {
    final db = await database;
    await db.update(
      'knockout_matches',
      {
        'score_home': scoreHome,
        'score_away': scoreAway,
        'is_finished': 1,
      },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  Future<void> resetKnockoutMatch(int matchId) async {
    final db = await database;
    await db.update(
      'knockout_matches',
      {
        'score_home': 0,
        'score_away': 0,
        'is_finished': 0,
      },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  /// Perbarui peserta sebuah knockout: dipakai untuk mengisi Final setelah
  /// semifinal selesai. `home` menandakan kolom home/away.
  /// [label] ditampilkan jika id tim belum diketahui (mis. \"W-SF1\").
  Future<void> updateKnockoutTeams(
      int matchId, int? teamId, String label, bool home) async {
    final db = await database;
    await db.update(
      'knockout_matches',
      home
          ? {
              'home_team_id': teamId,
              'home_team_source': label,
            }
          : {
              'away_team_id': teamId,
              'away_team_source': label,
            },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  /// Kosongkan peserta sebuah knockout (mis. Final) tanpa menghapus
  /// barisnya. Dipakai saat salah satu semifinal di-reset sehingga
  /// pemenang final jadi tidak valid lagi.
  Future<void> clearKnockoutTeams(int matchId) async {
    final db = await database;
    await db.update(
      'knockout_matches',
      {
        'home_team_id': null,
        'away_team_id': null,
      },
      where: 'id = ?',
      whereArgs: [matchId],
    );
  }

  Future<void> deleteKnockoutMatches(int leagueId) async {
    final db = await database;
    await db.delete('knockout_matches',
        where: 'league_id = ?', whereArgs: [leagueId]);
  }

  /// Status babak gugur: apakah fase grup sudah selesai dan siapa yang lolos.
  Future<KnockoutStatus> getKnockoutStatus(
      int leagueId, int ptsWin, int ptsDraw) async {
    final groups = await getGroupsByLeague(leagueId);
    if (groups.isEmpty) return KnockoutStatus.empty;

    final created =
        (await getKnockoutMatches(leagueId)).isNotEmpty;

    bool groupFinished = true;
    final qualifiers = <QualifiedTeam>[];
    bool resolved = true;

    for (final g in groups) {
      final matches = await getMatchesByGroup(g.id!);
      if (matches.any((m) => !m.isFinished)) {
        groupFinished = false;
        break;
      }

      final standings = await getStandings(g.id!, ptsWin, ptsDraw);
      if (standings.length < 2) {
        resolved = false;
        continue;
      }

      // Ambil Top 2, tapi pastikan tidak ada seri poin+GD+GF dengan
      // peringkat 3 (kalau seri, pemenang di luar rumus SQL tidak objektif).
      for (var pos = 1; pos <= 2; pos++) {
        final e = standings[pos - 1];
        if (pos == 2 &&
            standings.length > 2 &&
            _statKey(standings[1]) == _statKey(standings[2])) {
          resolved = false;
          break;
        }
        qualifiers.add(
          QualifiedTeam(
            teamId: e.teamId,
            teamName: e.teamName,
            groupName: g.name,
            position: pos,
            points: e.points,
            goalDifference: e.goalDifference,
          ),
        );
      }
    }

    if (!groupFinished) {
      return const KnockoutStatus(
        created: false,
        groupStageFinished: false,
        qualifiersResolved: false,
        qualifiedCount: 0,
        qualifiers: [],
      );
    }

    return KnockoutStatus(
      created: created,
      groupStageFinished: true,
      qualifiersResolved: resolved,
      qualifiedCount: qualifiers.length,
      qualifiers: qualifiers,
    );
  }

  static String _statKey(StandingEntry e) =>
      '${e.points}|${e.goalDifference}|${e.goalsFor}';

  /// Buat semifinal: Juara A vs Runner-up B, Juara B vs Runner-up A.
  /// Untuk liga 1 grup: peringkat 1 vs 4 dan 2 vs 3.
  Future<void> createKnockoutFromGroups(int leagueId) async {
    final groups = await getGroupsByLeague(leagueId);
    if (groups.isEmpty) {
      throw Exception('Tidak ada grup di liga ini');
    }

    final db = await database;
    final leagueRows =
        await db.query('leagues', where: 'id = ?', whereArgs: [leagueId]);
    if (leagueRows.isEmpty) {
      throw Exception('Liga tidak ditemukan');
    }
    final ptsWin = leagueRows.first['pts_win'] as int;
    final ptsDraw = leagueRows.first['pts_draw'] as int;

    final status = await getKnockoutStatus(leagueId, ptsWin, ptsDraw);
    if (!status.groupStageFinished) {
      throw Exception('Ada pertandingan fase grup yang belum selesai');
    }
    if (!status.qualifiersResolved) {
      throw Exception(
          'Ada peringkat seri di Top 2 — selesaikan dengan aturan fair play dulu');
    }

    final List<KnockoutMatch> fixtures = [];
    if (status.qualifiedCount == 2) {
      // Single group: hanya 2 tim -> langsung final, tanpa semifinal.
      final q = status.qualifiers;
      fixtures.add(KnockoutMatch(
        leagueId: leagueId,
        stage: 2,
        homeTeamId: q[0].teamId,
        awayTeamId: q[1].teamId,
        homeTeamSource: '1',
        awayTeamSource: '2',
      ));
    } else if (status.qualifiedCount == 4) {
      final q = status.qualifiers;
      // Urutan: [1A, 2A, 1B, 2B]
      final firstA = q.firstWhere((e) => e.position == 1);
      final secondA = q.firstWhere((e) => e.position == 2);

      // Ambil firstB & secondB: grup yang namanya bukan grup firstA.
      final firstB = q.firstWhere(
          (e) => e.position == 1 && e.groupName != firstA.groupName,
          orElse: () => q[2]);
      final secondB = q.firstWhere(
          (e) => e.position == 2 && e.groupName != secondA.groupName,
          orElse: () => q[3]);

      fixtures.add(KnockoutMatch(
        leagueId: leagueId,
        stage: 1,
        homeTeamId: firstA.teamId,
        awayTeamId: secondB.teamId,
        homeTeamSource: '1${_shortGroup(firstA.groupName)}',
        awayTeamSource: '2${_shortGroup(secondB.groupName)}',
      ));
      fixtures.add(KnockoutMatch(
        leagueId: leagueId,
        stage: 1,
        homeTeamId: firstB.teamId,
        awayTeamId: secondA.teamId,
        homeTeamSource: '1${_shortGroup(firstB.groupName)}',
        awayTeamSource: '2${_shortGroup(secondA.groupName)}',
      ));
      // Slot final kosong — diisi setelah semifinal selesai.
      fixtures.add(const KnockoutMatch(
        leagueId: 0,
        stage: 2,
        homeTeamSource: 'W-SF1',
        awayTeamSource: 'W-SF2',
      ).copyWith(leagueId: leagueId));
    } else {
      throw Exception(
          'Babak gugur otomatis hanya mendukung 2 atau 4 tim lolos '
          '(dapat ${status.qualifiedCount})');
    }

    await deleteKnockoutMatches(leagueId);
    await insertKnockoutMatches(fixtures);
  }

  /// Setelah sebuah semifinal selesai, isi slot Final dengan pemenangnya.
  /// Pemenang semifinal urutan ke-[index] (0 / 1) masuk ke sisi [home].
  Future<void> advanceWinnerToFinal(
      int leagueId, int semifinalMatchId) async {
    final matches = await getKnockoutMatches(leagueId);
    final semis = matches.where((m) => m.stage == 1).toList();
    final finals = matches.where((m) => m.stage == 2).toList();
    if (finals.isEmpty) return;

    final semiIdx = semis.indexWhere((m) => m.id == semifinalMatchId);
    if (semiIdx < 0) return;

    final semi = semis[semiIdx];
    if (!semi.isFinished ||
        semi.homeTeamId == null ||
        semi.awayTeamId == null) {
      return;
    }

    final bool homeWins = semi.scoreHome > semi.scoreAway;
    final bool draw = semi.scoreHome == semi.scoreAway;
    // Seri di knockout tidak boleh lanjut: perlu fair play di luar app.
    if (draw) {
      return;
    }

    final winnerId = homeWins ? semi.homeTeamId : semi.awayTeamId;
    final winnerName = homeWins ? semi.homeLabel : semi.awayLabel;
    final source = 'W-SF${semiIdx + 1} ($winnerName)';

    await updateKnockoutTeams(finals.first.id!, winnerId, source, semiIdx == 0);
  }

  static String _shortGroup(String name) {
    final short = name.replaceAll('Grup', '').trim();
    return short.length > 2 ? short.substring(0, 2) : short;
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
