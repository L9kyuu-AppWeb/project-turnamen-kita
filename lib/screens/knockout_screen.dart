import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/knockout_match.dart';
import '../models/league_config.dart';
import 'score_input_dialog.dart';

/// Isi tab / halaman babak gugur.
///
/// Dipakai dua kali: sebagai tab "Knockout" di dalam [MainScreen], dan
/// sebagai halaman penuh lewat [KnockoutScreen].
class KnockoutView extends StatefulWidget {
  final LeagueConfig leagueConfig;

  const KnockoutView({super.key, required this.leagueConfig});

  @override
  State<KnockoutView> createState() => _KnockoutViewState();
}

class _KnockoutViewState extends State<KnockoutView> {
  List<KnockoutMatch> _matches = [];
  KnockoutStatus _status = KnockoutStatus.empty;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _leagueId => widget.leagueConfig.id!;

  List<KnockoutMatch> get _semis =>
      _matches.where((m) => m.stage == 1).toList();

  List<KnockoutMatch> get _finals =>
      _matches.where((m) => m.stage == 2).toList();

  KnockoutMatch? get _finalMatch => _finals.isEmpty ? null : _finals.first;

  /// Nama juara, atau null kalau final belum selesai / masih seri.
  String? get _championName {
    final f = _finalMatch;
    if (f == null || !f.isFinished) return null;
    if (f.scoreHome == f.scoreAway) return null;
    return f.scoreHome > f.scoreAway ? f.homeLabel : f.awayLabel;
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final matches = await db.getKnockoutMatches(_leagueId);
    final status = await db.getKnockoutStatus(
      _leagueId,
      widget.leagueConfig.ptsWin,
      widget.leagueConfig.ptsDraw,
    );
    if (!mounted) return;
    setState(() {
      _matches = matches;
      _status = status;
      _isLoading = false;
    });
  }

  Future<void> _createKnockout() async {
    setState(() => _isCreating = true);
    try {
      await DatabaseHelper.instance.createKnockoutFromGroups(_leagueId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Babak gugur dibuat! Semifinal siap main.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _confirmCreateKnockout() async {
    final qualifiers = _status.qualifiers;
    final isFinalOnly = _status.qualifiedCount == 2;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 32),
        title: Text(isFinalOnly ? 'Buat Final?' : 'Buat Babak Gugur?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFinalOnly
                  ? 'Juara grup akan melaju langsung ke final.'
                  : 'Bracket dibuat otomatis dari 2 tim teratas setiap grup:',
            ),
            const SizedBox(height: 10),
            ...qualifiers.map(
              (q) => Text('• ${q.position == 1 ? 'Juara' : 'Runner-up'} '
                  '${q.groupName}: ${q.teamName}'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Seri tidak diperbolehkan di babak gugur.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _createKnockout();
  }

  Future<void> _inputScore(KnockoutMatch match) async {
    // Slot final masih kosong selama semifinal belum selesai.
    if (match.homeTeamId == null || match.awayTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tim di match ini belum ditentukan')),
      );
      return;
    }

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => ScoreInputDialog(
        homeTeam: match.homeLabel,
        awayTeam: match.awayLabel,
        initialHomeScore: match.isFinished ? match.scoreHome : 0,
        initialAwayScore: match.isFinished ? match.scoreAway : 0,
      ),
    );

    if (result == null) return;

    final home = result['home']!;
    final away = result['away']!;

    // Seri tidak mungkin di babak gugur — cegah di sini agar
    // app tidak menyimpan hasil yang tidak bisa ditentukan pemenangnya.
    if (home == away) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Babak gugur tidak boleh seri.')),
      );
      return;
    }

    final db = DatabaseHelper.instance;
    await db.updateKnockoutMatchScore(match.id!, home, away);

    // Kalau ini semifinal, pemenang otomatis masuk ke final.
    if (match.stage == 1) {
      await db.advanceWinnerToFinal(_leagueId, match.id!);
    }

    await _load();
  }

  Future<void> _resetScore(KnockoutMatch match) async {
    if (!match.isFinished) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Skor'),
        content: Text(
          'Reset ${match.label} ${match.homeLabel} vs ${match.awayLabel}?',
        ),
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
    if (confirmed != true) return;

    final db = DatabaseHelper.instance;
    await db.resetKnockoutMatch(match.id!);

    // Kalau semifinal di-reset, peserta final harus dikosongkan lagi
    // supaya pemenang yang dulu tidak ikut tampil.
    if (match.stage == 1) {
      final all = await db.getKnockoutMatches(_leagueId);
      for (final f in all.where((m) => m.stage == 2)) {
        final id = f.id;
        if (id != null) await db.clearKnockoutTeams(id);
      }
    }

    await _load();
  }

  Future<void> _confirmResetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded,
            size: 32, color: Theme.of(context).colorScheme.error),
        title: const Text('Hapus Babak Gugur?'),
        content: const Text(
          'Seluruh bracket semifinal & final akan dihapus.\n\n'
          'Data fase grup TIDAK terpengaruh. Anda bisa membuat bracket '
          'lagi kapan saja.',
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await DatabaseHelper.instance.deleteKnockoutMatches(_leagueId);
    await _load();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_matches.isEmpty) return _buildEmptyState(colorScheme);
    return _buildBracket(colorScheme);
  }

  Widget _buildEmptyState(ColorScheme cs) {
    final canCreate = _status.groupStageFinished &&
        _status.qualifiersResolved &&
        (_status.qualifiedCount == 2 || _status.qualifiedCount == 4);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: 72,
          color: cs.outline.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 20),
        Text(
          'Belum ada Babak Gugur',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          _status.groupStageFinished
              ? 'Fase grup sudah selesai. Buat bracket dari 2 tim teratas '
                  'setiap grup.'
              : 'Selesaikan seluruh pertandingan fase grup dulu, lalu buat '
                  'bracket dari 2 tim teratas setiap grup.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
        ),
        if (_status.groupStageFinished && _status.qualifiers.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildQualifiersPreview(cs),
        ],
        if (!canCreate) ...[
          const SizedBox(height: 24),
          _buildBlockedReason(cs),
        ] else ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isCreating ? null : _confirmCreateKnockout,
            icon: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.emoji_events),
            label: Text(_isCreating ? 'Menyiapkan...' : 'Buat Babak Gugur'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
        ],
      ],
    );
  }

  /// Penjelasan kenapa tombol "Buat" tidak muncul.
  Widget _buildBlockedReason(ColorScheme cs) {
    final String msg;
    if (!_status.groupStageFinished) {
      msg = 'Masih ada pertandingan fase grup yang belum selesai.';
    } else if (!_status.qualifiersResolved) {
      msg = 'Ada peringkat seri di zona Top 2. Selesaikan dulu lewat '
          'aturan fair play (head-to-head / gol away) yang disepakati.';
    } else {
      msg = 'Babak gugur otomatis hanya mendukung 2 atau 4 tim lolos. '
          'Saat ini ${_status.qualifiedCount} tim lolos.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(fontSize: 12.5, color: cs.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualifiersPreview(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tim yang lolos',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ..._status.qualifiers.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: q.position == 1 ? cs.primary : cs.tertiary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${q.position}',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q.teamName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${q.points} pts',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBracket(ColorScheme cs) {
    final champion = _championName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (champion != null) ...[
          _buildChampionBanner(cs, champion),
          const SizedBox(height: 24),
        ],
        if (_semis.isNotEmpty) ...[
          _buildStageTitle('Semifinal', Icons.sports_mma, cs),
          const SizedBox(height: 10),
          ..._semis.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildKnockoutCard(e.value, 'SF${e.key + 1}', cs),
                ),
              ),
          const SizedBox(height: 12),
        ],
        if (_finalMatch != null) ...[
          _buildStageTitle('Final', Icons.emoji_events, cs),
          const SizedBox(height: 10),
          _buildKnockoutCard(_finalMatch!, 'FINAL', cs),
        ],
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _confirmResetAll,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Hapus babak gugur'),
          style: TextButton.styleFrom(foregroundColor: cs.error),
        ),
      ],
    );
  }

  Widget _buildStageTitle(String title, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
      ],
    );
  }

  Widget _buildChampionBanner(ColorScheme cs, String champion) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, Color.lerp(cs.primary, Colors.amber.shade700, 0.5)!],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 48, color: Colors.white),
          const SizedBox(height: 10),
          const Text(
            'JUARA',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            champion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.leagueConfig.name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildKnockoutCard(KnockoutMatch match, String tag, ColorScheme cs) {
    final isPlaceholder =
        match.homeTeamId == null || match.awayTeamId == null;
    final draw = match.isFinished && match.scoreHome == match.scoreAway;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: match.isFinished
              ? cs.primary.withValues(alpha: 0.35)
              : cs.outlineVariant,
          width: match.isFinished ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isPlaceholder ? null : () => _inputScore(match),
        onLongPress: match.isFinished ? () => _resetScore(match) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (match.isFinished)
                    Icon(
                      draw ? Icons.error_outline : Icons.check_circle,
                      size: 16,
                      color: draw ? cs.error : cs.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildTeamRow(
                label: match.homeLabel,
                score: match.isFinished ? '${match.scoreHome}' : null,
                isWinner:
                    match.isFinished && match.scoreHome > match.scoreAway,
                cs: cs,
                alignEnd: true,
              ),
              const SizedBox(height: 6),
              _buildTeamRow(
                label: match.awayLabel,
                score: match.isFinished ? '${match.scoreAway}' : null,
                isWinner:
                    match.isFinished && match.scoreAway > match.scoreHome,
                cs: cs,
                alignEnd: false,
              ),
              const SizedBox(height: 8),
              Text(
                isPlaceholder
                    ? 'Menunggu pemenang semifinal'
                    : (match.isFinished ? 'Tekan & tahan untuk reset' : 'Ketuk untuk input skor'),
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: isPlaceholder ? FontStyle.italic : null,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow({
    required String label,
    required String? score,
    required bool isWinner,
    required ColorScheme cs,
    required bool alignEnd,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14,
              color: isWinner ? cs.primary : cs.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                score == null ? cs.surfaceContainerHighest : cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            score ?? 'vs',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: score == null ? 12 : 16,
              color: score == null
                  ? cs.onSurfaceVariant
                  : cs.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

/// Halaman babak gugur berdiri sendiri (dibuka dari daftar liga).
class KnockoutScreen extends StatelessWidget {
  final LeagueConfig leagueConfig;

  const KnockoutScreen({super.key, required this.leagueConfig});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Babak Gugur'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              leagueConfig.name,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
      body: KnockoutView(leagueConfig: leagueConfig),
    );
  }
}