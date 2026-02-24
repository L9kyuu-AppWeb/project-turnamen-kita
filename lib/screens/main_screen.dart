import 'package:flutter/material.dart';
import '../models/league_config.dart';
import '../models/group_model.dart';
import '../models/match_model.dart';
import '../models/standing_entry.dart';
import '../database/database_helper.dart';
import 'score_input_dialog.dart';
import 'setup_screen.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  final LeagueConfig leagueConfig;

  const MainScreen({super.key, required this.leagueConfig});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<GroupModel> _groups = [];
  int _selectedGroupIndex = 0;
  List<MatchModel> _matches = [];
  List<StandingEntry> _standings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      _groups = await db.getGroupsByLeague(widget.leagueConfig.id!);

      if (_groups.isNotEmpty) {
        await _loadGroupData(_groups[_selectedGroupIndex].id!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadGroupData(int groupId) async {
    final db = DatabaseHelper.instance;
    _matches = await db.getMatchesByGroup(groupId);
    _standings = await db.getStandings(
      groupId,
      widget.leagueConfig.ptsWin,
      widget.leagueConfig.ptsDraw,
    );
  }

  Future<void> _onTapMatch(MatchModel match) async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => ScoreInputDialog(
        homeTeam: match.homeTeamName ?? 'Home',
        awayTeam: match.awayTeamName ?? 'Away',
        initialHomeScore: match.isFinished ? match.scoreHome : 0,
        initialAwayScore: match.isFinished ? match.scoreAway : 0,
      ),
    );

    if (result != null) {
      final db = DatabaseHelper.instance;
      await db.updateMatchScore(match.id!, result['home']!, result['away']!);
      await _loadGroupData(_groups[_selectedGroupIndex].id!);
      if (mounted) setState(() {});
    }
  }

  Future<void> _onLongPressMatch(MatchModel match) async {
    if (!match.isFinished) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Skor'),
        content: Text(
            'Reset pertandingan ${match.homeTeamName} vs ${match.awayTeamName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = DatabaseHelper.instance;
      await db.resetMatch(match.id!);
      await _loadGroupData(_groups[_selectedGroupIndex].id!);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leagueConfig.name),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          if (_groups.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Pilih Grup',
              onSelected: (index) async {
                _selectedGroupIndex = index;
                setState(() => _isLoading = true);
                await _loadGroupData(_groups[index].id!);
                if (mounted) setState(() => _isLoading = false);
              },
              itemBuilder: (_) => _groups.asMap().entries.map((e) {
                return PopupMenuItem(
                  value: e.key,
                  child: Row(
                    children: [
                      if (e.key == _selectedGroupIndex)
                        Icon(Icons.check, color: colorScheme.primary, size: 20),
                      if (e.key == _selectedGroupIndex) const SizedBox(width: 8),
                      Text(e.value.name),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              if (_groups.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _groups.isNotEmpty
                        ? _groups[_selectedGroupIndex].name
                        : '',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.sports_soccer), text: 'Pertandingan'),
                  Tab(icon: Icon(Icons.leaderboard), text: 'Klasemen'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMatchesTab(colorScheme),
                _buildStandingsTab(colorScheme),
              ],
            ),
    );
  }

  Widget _buildMatchesTab(ColorScheme colorScheme) {
    if (_matches.isEmpty) {
      return const Center(child: Text('Belum ada pertandingan'));
    }

    // Group matches by round
    final Map<int, List<MatchModel>> byRound = {};
    for (final m in _matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rounds.length,
      itemBuilder: (context, index) {
        final round = rounds[index];
        final roundMatches = byRound[round]!;
        final finishedCount =
            roundMatches.where((m) => m.isFinished).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pekan $round',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$finishedCount/${roundMatches.length} selesai',
                    style: TextStyle(
                      color: colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ...roundMatches.map((m) => _buildMatchCard(m, colorScheme)),
          ],
        );
      },
    );
  }

  Widget _buildMatchCard(MatchModel match, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: match.isFinished
              ? colorScheme.outlineVariant.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: () => _onTapMatch(match),
        onLongPress: () => _onLongPressMatch(match),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Home team
              Expanded(
                flex: 3,
                child: Text(
                  match.homeTeamName ?? '-',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: match.isFinished &&
                            match.scoreHome > match.scoreAway
                        ? colorScheme.primary
                        : null,
                  ),
                ),
              ),

              // Score
              Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: match.isFinished
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  match.isFinished
                      ? '${match.scoreHome} - ${match.scoreAway}'
                      : 'vs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: match.isFinished ? 16 : 14,
                    color: match.isFinished
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.outline,
                  ),
                ),
              ),

              // Away team
              Expanded(
                flex: 3,
                child: Text(
                  match.awayTeamName ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: match.isFinished &&
                            match.scoreAway > match.scoreHome
                        ? colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandingsTab(ColorScheme colorScheme) {
    if (_standings.isEmpty) {
      return const Center(child: Text('Belum ada data klasemen'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with legend
          _buildStandingsHeader(colorScheme),
          const SizedBox(height: 12),
          // Standings table
          _buildModernStandingsTable(colorScheme),
        ],
      ),
    );
  }

  Widget _buildStandingsHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildLegendItem(Icons.emoji_events, 'Top 2', colorScheme.primary),
          const SizedBox(width: 24),
          _buildLegendItem(Icons.trending_up, 'Promosi', colorScheme.tertiary),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: 10, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStandingsTable(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('#', 8, colorScheme),
                _buildHeaderCell('Tim', 40, colorScheme, isTeam: true),
                _buildStatCell('M', colorScheme, tooltip: 'Main'),
                _buildStatCell('W', colorScheme, tooltip: 'Menang'),
                _buildStatCell('D', colorScheme, tooltip: 'Seri'),
                _buildStatCell('L', colorScheme, tooltip: 'Kalah'),
                _buildStatCell('GF', colorScheme, tooltip: 'Gol Masuk'),
                _buildStatCell('GA', colorScheme, tooltip: 'Gol Kemasukan'),
                _buildStatCell('GD', colorScheme, tooltip: 'Selisih Gol'),
                _buildStatCell('Pts', colorScheme, tooltip: 'Poin', isPoints: true),
              ],
            ),
          ),
          // Table Rows
          ...List.generate(_standings.length, (i) {
            final s = _standings[i];
            final rank = i + 1;
            final isTop2 = rank <= 2;
            final isBottom = i == _standings.length - 1;

            return Container(
              decoration: BoxDecoration(
                color: isTop2
                    ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : null,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildRankCell(rank, colorScheme, isTop2),
                  _buildTeamCell(s.teamName, colorScheme, isTop2),
                  _buildStatDataCell('${s.played}', colorScheme),
                  _buildStatDataCell('${s.won}', colorScheme, 
                      valueColor: colorScheme.tertiary),
                  _buildStatDataCell('${s.drawn}', colorScheme),
                  _buildStatDataCell('${s.lost}', colorScheme),
                  _buildStatDataCell('${s.goalsFor}', colorScheme),
                  _buildStatDataCell('${s.goalsAgainst}', colorScheme),
                  _buildGoalDiffCell(s.goalDifference, colorScheme),
                  _buildPointsCell(s.points, colorScheme, isTop2),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, double flex, ColorScheme colorScheme, {bool isTeam = false}) {
    return Expanded(
      flex: flex.toInt(),
      child: Center(
        child: Text(
          label,
          textAlign: isTeam ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCell(String label, ColorScheme colorScheme, {String? tooltip, bool isPoints = false}) {
    return Expanded(
      flex: isPoints ? 12 : 10,
      child: Center(
        child: Tooltip(
          message: tooltip ?? '',
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isPoints ? FontWeight.bold : FontWeight.w600,
              fontSize: isPoints ? 13 : 11,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankCell(int rank, ColorScheme colorScheme, bool isTop2) {
    return SizedBox(
      width: 40,
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isTop2
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isTop2 ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCell(String teamName, ColorScheme colorScheme, bool isTop2) {
    return Expanded(
      flex: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          teamName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isTop2 ? colorScheme.primary : colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildStatDataCell(String value, ColorScheme colorScheme, {Color? valueColor}) {
    return Expanded(
      flex: 10,
      child: Center(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: valueColor ?? colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildGoalDiffCell(int goalDiff, ColorScheme colorScheme) {
    Color color;
    if (goalDiff > 0) {
      color = Colors.green;
    } else if (goalDiff < 0) {
      color = Colors.red;
    } else {
      color = colorScheme.onSurfaceVariant;
    }

    return Expanded(
      flex: 10,
      child: Center(
        child: Text(
          goalDiff > 0 ? '+$goalDiff' : '$goalDiff',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildPointsCell(int points, ColorScheme colorScheme, bool isTop2) {
    return Expanded(
      flex: 12,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isTop2
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$points',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isTop2 ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
