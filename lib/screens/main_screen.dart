import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/league_config.dart';
import '../models/group_model.dart';
import '../models/match_model.dart';
import '../models/standing_entry.dart';
import '../database/database_helper.dart';
import '../services/export_service.dart';
import 'knockout_screen.dart';
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

  int get _leagueId => widget.leagueConfig.id!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      _groups = await db.getGroupsByLeague(_leagueId);

      if (_groups.isNotEmpty) {
        // Tahan indeks kalau datang dari liga yang grupnya berkurang.
        if (_selectedGroupIndex >= _groups.length) _selectedGroupIndex = 0;
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

  // ==================== BAGIKAN (EXPORT & SHARE) ====================

  Future<void> _showShareDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.share),
        title: const Text('Bagikan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pilih yang ingin dibagikan:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, 'pdf_this_group'),
              icon: const Icon(Icons.picture_as_pdf),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  (_groups.length > 1 && _groups.isNotEmpty)
                      ? _groups[_selectedGroupIndex].name
                      : 'Klasemen grup ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_groups.length > 1) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(context, 'pdf_all_groups'),
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('Semua grup (PDF)'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'copy_text'),
              icon: const Icon(Icons.copy),
              label: const Text('Salin sebagai teks'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;

    switch (result) {
      case 'copy_text':
        await _shareAsText();
        break;
      case 'pdf_this_group':
        await _shareStandingsPdf(allGroups: false);
        break;
      case 'pdf_all_groups':
        await _shareStandingsPdf(allGroups: true);
        break;
    }
  }

  Future<void> _shareAsText() async {
    if (_groups.isEmpty) return;
    await ExportService.instance.copyStandingsText(
      league: widget.leagueConfig,
      data: GroupExportData(
        group: _groups[_selectedGroupIndex],
        standings: _standings,
        matches: _matches,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disalin — tinggal paste di WhatsApp')),
    );
  }

  Future<void> _shareStandingsPdf({required bool allGroups}) async {
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Text('Menyiapkan PDF...'),
          ],
        ),
      ),
    );

    try {
      final db = DatabaseHelper.instance;
      final groupsToExport = allGroups
          ? _groups
          : <GroupModel>[if (_groups.isNotEmpty) _groups[_selectedGroupIndex]];

      final dataList = <GroupExportData>[];
      for (final g in groupsToExport) {
        if (allGroups) {
          // Grup lain belum dimuat di state, ambil langsung dari DB.
          final m = await db.getMatchesByGroup(g.id!);
          final s = await db.getStandings(g.id!, widget.leagueConfig.ptsWin,
              widget.leagueConfig.ptsDraw);
          dataList.add(GroupExportData(group: g, standings: s, matches: m));
        } else {
          dataList.add(GroupExportData(
              group: g, standings: _standings, matches: _matches));
        }
      }

      final file = await ExportService.instance.buildStandingsPdf(
        league: widget.leagueConfig,
        groups: dataList,
      );

      navigator.pop(); // tutup dialog loading
      await ExportService.instance.shareFiles(
        [file],
        text: 'Klasemen ${widget.leagueConfig.name} — dari Turnamen Kita',
      );
    } catch (e) {
      if (!navigator.mounted) return;
      if (navigator.canPop()) navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e')),
      );
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
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Bagikan',
            onPressed: _showShareDialog,
          ),
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
                  Tab(icon: Icon(Icons.emoji_events), text: 'Knockout'),
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
                KnockoutView(leagueConfig: widget.leagueConfig),
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

        // Lebar kolom "Tim" menyesuaikan isi (nama terpanjang), tanpa
        // minimum, dengan batas maksimal = lebar kolom Tim pada layout
        // awal (availableW - fixedW, minimal _kMinTeamWPortrait/_kMinTeamW).
        // Nama yang lebih panjang dari batas akan membungkus ke baris
        // berikutnya, bukan dipotong.
        final double fixedW = (2 * _kRowPadX) +
            _kRankW +
            (showDetailedGoals ? (8 * _kStatW) : (6 * _kStatW)) +
            _kPointsW;
        final double availableW = constraints.maxWidth - (2 * _kOuterPadX);
        final double maxTeamW = math.max(
          isPortrait ? _kMinTeamWPortrait : _kMinTeamW,
          availableW - fixedW,
        );

        double longestName = 0;
        const nameStyle =
            TextStyle(fontWeight: FontWeight.w700, fontSize: 13);
        for (final s in _standings) {
          final tp = TextPainter(
            text: TextSpan(text: s.teamName, style: nameStyle),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();
          if (tp.width > longestName) longestName = tp.width;
        }
        final double teamW = (longestName + 14).clamp(0.0, maxTeamW);

        // Tinggi baris seragam: nama terpanjang yang membungkus (2 baris
        // atau lebih) menentukan tinggi baris untuk KEDUA pane agar baris
        // di kiri dan kanan tetap sejajar.
        int maxLines = 1;
        double lineHeight = 0;
        final double textMaxW = teamW - 14; // padding kiri 6 + kanan 8
        for (final s in _standings) {
          final tp = TextPainter(
            text: TextSpan(text: s.teamName, style: nameStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: textMaxW < 1 ? 1 : textMaxW);
          final int lines = tp.computeLineMetrics().length;
          if (lines > maxLines) maxLines = lines;
          if (lineHeight == 0 && lines > 0) lineHeight = tp.height / lines;
        }
        if (lineHeight == 0) lineHeight = 18;
        final double bodyRowH =
            (maxLines * lineHeight + 20) > _kRowH ? (maxLines * lineHeight + 20) : _kRowH;

        final double leftW = _kRankW + teamW + (2 * _kRowPadX);
        final double statsW = (showDetailedGoals ? 7 : 5) * _kStatW + _kPointsW;
        final bool statsScrollable =
            (leftW + statsW + (2 * _kRowPadX)) > availableW;

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
              if (statsScrollable)
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
              _buildModernStandingsTable(
                colorScheme,
                showDetailedGoals: showDetailedGoals,
                teamWidth: teamW,
                bodyRowH: bodyRowH,
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
    required double bodyRowH,
  }) {
    // Kolom "Tim" dibekukan (tidak ikut geser horizontal); hanya kolom
    // statistik yang berada di dalam scroll horizontal.
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pane kiri beku: # + Tim
          SizedBox(
            width: _kRankW + teamWidth + (2 * _kRowPadX),
            child: _buildFrozenPane(colorScheme, teamWidth, bodyRowH),
          ),
          // Pane kanan: statistik, bisa digeser horizontal
          Expanded(
            child: SingleChildScrollView(
              controller: _hScrollController,
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              child: _buildStatsPane(colorScheme, showDetailedGoals, bodyRowH),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrozenPane(ColorScheme colorScheme, double teamWidth, double bodyRowH) {
    return Column(
      children: [
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
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        ...List.generate(_standings.length, (i) {
          final s = _standings[i];
          final rank = i + 1;
          final isTop2 = rank <= 2;
          final isOdd = i.isOdd;
          return Container(
            height: bodyRowH,
            padding: const EdgeInsets.symmetric(horizontal: _kRowPadX, vertical: 8),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRankCell(rank, colorScheme, isTop2),
                SizedBox(
                  width: teamWidth,
                  child: _TeamCell(teamName: s.teamName, isTop2: isTop2),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatsPane(ColorScheme colorScheme, bool showDetailedGoals, double bodyRowH) {
    return Column(
      children: [
        Container(
          height: _kRowH,
          padding: const EdgeInsets.symmetric(horizontal: _kRowPadX),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          ),
          child: Row(
            children: [
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
        ...List.generate(_standings.length, (i) {
          final s = _standings[i];
          final rank = i + 1;
          final isTop2 = rank <= 2;
          final isOdd = i.isOdd;
          return Container(
            height: bodyRowH,
            padding: const EdgeInsets.symmetric(horizontal: _kRowPadX),
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
  const _TeamCell({required this.teamName, required this.isTop2});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
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
          softWrap: true,
        ),
      ),
    );
  }
}
