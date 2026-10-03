import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/league_config.dart';
import '../models/group_model.dart';
import '../models/match_model.dart';
import '../models/standing_entry.dart';
import '../database/database_helper.dart';
import 'score_input_dialog.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  final LeagueConfig leagueConfig;

  const MainScreen({super.key, required this.leagueConfig});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _hScrollController;
  List<GroupModel> _groups = [];
  int _selectedGroupIndex = 0;
  List<MatchModel> _matches = [];
  List<StandingEntry> _standings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _hScrollController = ScrollController();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hScrollController.dispose();
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

  bool get _hasAnyFinishedMatch {
    return _matches.any((m) => m.isFinished);
  }

  /// Reset semua skor pada grup yang sedang dipilih —
  /// dipakai untuk lanjutan liga/musim baru tanpa menghapus tim & jadwal.
  Future<void> _showResetGroupDialog() async {
    if (!_hasAnyFinishedMatch) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada skor yang perlu di-reset')),
      );
      return;
    }

    final groupName = _groups.isNotEmpty
        ? _groups[_selectedGroupIndex].name
        : 'grup ini';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.restart_alt, size: 32),
        title: Text('Reset $groupName?'),
        content: const Text(
          'Semua skor di grup ini akan dihapus (kembali 0 - 0) '
          'sehingga liga bisa dilanjutkan dari awal.\n\n'
          'Tim dan jadwal TIDAK dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Grup'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final n = await db.resetMatchesByGroup(
        _groups[_selectedGroupIndex].id!,
      );
      await _loadGroupData(_groups[_selectedGroupIndex].id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n pertandingan di-reset. Siap lanjut!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal reset: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Reset semua skor di seluruh grup pada liga ini.
  Future<void> _showResetLeagueDialog() async {
    final groupName = _groups.isNotEmpty
        ? _groups[_selectedGroupIndex].name
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 32, color: Theme.of(context).colorScheme.error),
        title: Text('Reset ${widget.leagueConfig.name}?'),
        content: Text(
          'Semua skor di ${_groups.length} grup '
          '${groupName.isNotEmpty ? '(termasuk $groupName) ' : ''}'
          'akan dihapus.\n\n'
          'Tim dan jadwal TIDAK dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Liga'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final n = await db.resetMatchesByLeague(widget.leagueConfig.id!);
      _selectedGroupIndex = 0;
      if (_groups.isNotEmpty) {
        await _loadGroupData(_groups[_selectedGroupIndex].id!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n pertandingan di-reset. Siap lanjut!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal reset: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu liga',
            onSelected: (value) {
              if (value == 'reset_league') {
                _showResetLeagueDialog();
              } else if (value == 'reset_group') {
                _showResetGroupDialog();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset_group',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    const Text('Reset grup ini'),
                  ],
                ),
              ),
              if (_groups.length > 1)
                PopupMenuItem(
                  value: 'reset_league',
                  child: Row(
                    children: [
                      Icon(Icons.autorenew,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      const Text('Reset seluruh liga'),
                    ],
                  ),
                ),
            ],
          ),
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

    final bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mode potret: semua kolom tampil dan tabel digeser horizontal.
        // Mode lanskap/tablet: GF/GA disembunyikan bila ruang tidak cukup.
        final bool showDetailedGoals =
            isPortrait || constraints.maxWidth >= _kBreakpointDetailedGoals;

        // Lebar semua kolom yang berukuran tetap.
        final double fixedW = (2 * _kRowPadX) +
            _kRankW +
            (showDetailedGoals ? (8 * _kStatW) : (6 * _kStatW)) +
            _kPointsW;

        // Ruang yang benar-benar tersedia setelah padding luar.
        final double availableW = constraints.maxWidth - (2 * _kOuterPadX);

        // Kolom "Tim" memakai sisa ruang, minimal sebesar _kMinTeamW.
        // Kalau ruang tidak cukup, tabel dibuat lebih lebar dari layar
        // sehingga bisa digeser ke samping.
        final double teamW = math.max(
          isPortrait ? _kMinTeamWPortrait : _kMinTeamW,
          availableW - fixedW,
        );
        final double tableWidth = fixedW + teamW;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _kOuterPadX,
            12,
            _kOuterPadX,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStandingsHeader(colorScheme),
              const SizedBox(height: 12),
              if (tableWidth > availableW)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.swipe_left,
                          size: 14, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        'Geser tabel ke samping',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              // Scrollbar bawaan disembunyikan khusus di sini: di
              // desktop/web thumb-nya melayang di tepi bawah viewport
              // dan menutupi baris terakhir setiap kali tabel digeser.
              // Geser tetap bisa dengan drag/swipe seperti biasa.
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _hScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Ruang bawah agar bayangan tabel tidak terpotong.
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: tableWidth,
                    child: _buildModernStandingsTable(
                      colorScheme,
                      showDetailedGoals: showDetailedGoals,
                      teamWidth: teamW,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandingsHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      // Wrap agar di layar sempit label tidak kepotong/overflow,
      // melainkan turun ke baris berikutnya.
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildLegendItem(Icons.workspace_premium, 'Juara', colorScheme.primary),
          _buildLegendItem(Icons.trending_up, 'Promosi', colorScheme.tertiary),
          _buildLegendItem(Icons.schedule, 'Belum main',
              colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  // ===== Layout constants =====
  static const double _kRowPadX = 6;
  static const double _kRankW = 38;
  static const double _kStatW = 30;
  static const double _kPointsW = 52;
  static const double _kRowH = 40;
  static const double _kMinTeamW = 90;
  static const double _kMinTeamWPortrait = 150;
  static const double _kOuterPadX = 12;

  // GF/GA baru ditampilkan bila ruang sisa cukup lega untuk nama tim.
  static const double _kBreakpointDetailedGoals = 456;

  Widget _buildModernStandingsTable(
    ColorScheme colorScheme, {
    required bool showDetailedGoals,
    required double teamWidth,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Sticky header
          Container(
            height: _kRowH,
            padding: const EdgeInsets.symmetric(horizontal: _kRowPadX),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
            ),
            child: Row(
              children: [
                _buildHeaderCell('#', colorScheme, width: _kRankW),
                SizedBox(width: teamWidth, child: _TeamHeaderLabel(label: 'Tim')),
                _buildHeaderCell('M', colorScheme, width: _kStatW),
                _buildHeaderCell('M', colorScheme, width: _kStatW),
                _buildHeaderCell('S', colorScheme, width: _kStatW),
                _buildHeaderCell('K', colorScheme, width: _kStatW),
                if (showDetailedGoals) ...[
                  _buildHeaderCell('GF', colorScheme, width: _kStatW),
                  _buildHeaderCell('GA', colorScheme, width: _kStatW),
                ],
                _buildHeaderCell('GD', colorScheme, width: _kStatW),
                _buildHeaderCell('Pts', colorScheme, width: _kPointsW, bold: true),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Rows
          ...List.generate(_standings.length, (i) {
            final s = _standings[i];
            final rank = i + 1;
            final isTop2 = rank <= 2;
            final isOdd = i.isOdd;

            return Container(
              height: _kRowH,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isTop2
                    ? colorScheme.primary.withValues(alpha: 0.08)
                    : (isOdd
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : null),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildRankCell(rank, colorScheme, isTop2),
                  _TeamCell(teamName: s.teamName, isTop2: isTop2, width: teamWidth),
                  _buildStatDataCell('${s.played}', colorScheme, width: _kStatW),
                  _buildStatDataCell('${s.won}', colorScheme,
                      width: _kStatW, valueColor: colorScheme.tertiary),
                  _buildStatDataCell('${s.drawn}', colorScheme, width: _kStatW),
                  _buildStatDataCell('${s.lost}', colorScheme, width: _kStatW),
                  if (showDetailedGoals) ...[
                    _buildStatDataCell('${s.goalsFor}', colorScheme, width: _kStatW),
                    _buildStatDataCell('${s.goalsAgainst}', colorScheme, width: _kStatW),
                  ],
                  _buildGoalDiffCell(s.goalDifference, colorScheme, width: _kStatW),
                  _buildPointsCell(s.points, colorScheme, isTop2, width: _kPointsW),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, ColorScheme colorScheme, {required double width, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.2,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildRankCell(int rank, ColorScheme colorScheme, bool isTop2) {
    return SizedBox(
      width: _kRankW,
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isTop2
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(rank <= 2 ? 99 : 8),
            border: isTop2
                ? Border.all(color: colorScheme.primary.withValues(alpha: 0.4), width: 1.5)
                : null,
          ),
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isTop2 ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatDataCell(String value, ColorScheme colorScheme,
      {required double width, Color? valueColor}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: valueColor ?? colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildGoalDiffCell(int goalDiff, ColorScheme colorScheme,
      {required double width}) {
    Color color;
    if (goalDiff > 0) {
      color = Colors.green.shade700;
    } else if (goalDiff < 0) {
      color = Colors.red.shade700;
    } else {
      color = colorScheme.onSurfaceVariant;
    }

    return SizedBox(
      width: width,
      child: Center(
        child: Text(
          goalDiff > 0 ? '+$goalDiff' : '$goalDiff',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildPointsCell(int points, ColorScheme colorScheme, bool isTop2,
      {required double width}) {
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isTop2
                ? colorScheme.primary.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(99),
            border: isTop2
                ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.35),
                    width: 1.5)
                : null,
          ),
          child: Text(
            '$points',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isTop2 ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamHeaderLabel extends StatelessWidget {
  final String label;
  const _TeamHeaderLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 8),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.2,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _TeamCell extends StatelessWidget {
  final String teamName;
  final bool isTop2;
  final double width;
  const _TeamCell(
      {required this.teamName, required this.isTop2, required this.width});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, right: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            teamName,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isTop2 ? colorScheme.primary : colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
