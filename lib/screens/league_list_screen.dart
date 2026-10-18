import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/league_config.dart';
import 'setup_screen.dart';
import 'main_screen.dart';

class LeagueListScreen extends StatefulWidget {
  const LeagueListScreen({super.key});

  @override
  State<LeagueListScreen> createState() => _LeagueListScreenState();
}

class _LeagueListScreenState extends State<LeagueListScreen> {
  List<LeagueConfig> _leagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _leagues = await DatabaseHelper.instance.getAllLeagues();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openLeague(LeagueConfig league) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(leagueConfig: league)),
    );
    if (mounted) _load();
  }

  Future<void> _renameLeague(LeagueConfig league) async {
    final newName = await showDialog<String?>(
      context: context,
      builder: (_) => _RenameLeagueDialog(initialName: league.name),
    );
    if (newName == null || newName.trim().isEmpty || newName.trim() == league.name) return;

    final trimmed = newName.trim();
    await DatabaseHelper.instance.renameLeague(league.id!, trimmed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Diubah menjadi "$trimmed"')),
    );
    _load();
  }

  Future<void> _duplicateLeague(LeagueConfig league) async {
    final name = await showDialog<String?>(
      context: context,
      builder: (_) => _DuplicateLeagueDialog(initialName: '${league.name} (Musim Baru)'),
    );
    if (name == null || name.trim().isEmpty) return;

    try {
      final id = await DatabaseHelper.instance.duplicateLeague(league.id!,
          newName: name.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liga berhasil diduplikat')),
      );
      await _load();
      if (!mounted) return;
      // Buka liga duplikat langsung.
      final created =
          _leagues.firstWhere((l) => l.id == id, orElse: () => league);
      _openLeague(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal duplikat: $e')),
      );
    }
  }

  Future<void> _deleteLeague(LeagueConfig league) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.delete_forever,
            size: 32, color: Theme.of(context).colorScheme.error),
        title: Text('Hapus "${league.name}"?'),
        content: const Text(
          'Semua grup, tim, dan pertandingan di liga ini akan terhapus permanen.',
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
    if (ok != true) return;

    await DatabaseHelper.instance.deleteLeague(league.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${league.name}" dihapus')),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Liga'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leagues.isEmpty
              ? _EmptyState(colorScheme: colorScheme)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _leagues.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _LeagueCard(
                      league: _leagues[i],
                      onOpen: () => _openLeague(_leagues[i]),
                      onRename: () => _renameLeague(_leagues[i]),
                      onDuplicate: () => _duplicateLeague(_leagues[i]),
                      onDelete: () => _deleteLeague(_leagues[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          );
          if (mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Liga Baru'),
      ),
    );
  }
}

class _LeagueCard extends StatelessWidget {
  final LeagueConfig league;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _LeagueCard({
    required this.league,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, int>>(
      future: DatabaseHelper.instance.getLeagueSummary(league.id!),
      builder: (_, snap) {
        final s = snap.data;
        final subtitle = s == null
            ? _typeSubtitle(league)
            : '${_typeSubtitle(league)} • ${s['teams']} tim • '
                '${s['finished']}/${s['matches']} selesai';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      league.type == 'group'
                          ? Icons.groups
                          : Icons.emoji_events,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            _Pill(
                                label: 'P Pts ${league.ptsWin}-${league.ptsDraw}'),
                            if (league.isHomeAway) const _Pill(label: 'Home & Away'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') onRename();
                      if (v == 'duplicate') onDuplicate();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(children: [
                          Icon(Icons.edit, size: 18, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          const Text('Ubah nama'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Row(children: [
                          Icon(Icons.content_copy,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          const Text('Duplikat untuk musim baru'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, size: 18, color: colorScheme.error),
                          const SizedBox(width: 12),
                          Text('Hapus',
                              style: TextStyle(color: colorScheme.error)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _typeSubtitle(LeagueConfig c) {
    if (c.type == 'group') return '${c.numberOfGroups} grup • ${c.teamsPerGroup} tim/grup';
    return '${c.teamsPerGroup} tim • ${c.type}';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// Dialog ubah nama: controller milik state dialog sendiri,
// di-dispose saat rute dialog benar-benar dihancurkan.
class _RenameLeagueDialog extends StatefulWidget {
  final String initialName;
  const _RenameLeagueDialog({required this.initialName});

  @override
  State<_RenameLeagueDialog> createState() => _RenameLeagueDialogState();
}

class _RenameLeagueDialogState extends State<_RenameLeagueDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dialog custom + SingleChildScrollView agar tidak overflow saat
    // keyboard muncul: actions ikut ke-scroll bersama content,
    // tidak seperti AlertDialog.actions yang ukurannya kaku.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ubah nama liga',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nama liga',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog duplikat: controller milik state dialog sendiri,
// di-dispose saat rute dialog benar-benar dihancurkan.
class _DuplicateLeagueDialog extends StatefulWidget {
  final String initialName;
  const _DuplicateLeagueDialog({required this.initialName});

  @override
  State<_DuplicateLeagueDialog> createState() =>
      _DuplicateLeagueDialogState();
}

class _DuplicateLeagueDialogState extends State<_DuplicateLeagueDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sama seperti dialog ubah nama: Dialog + SingleChildScrollView agar
    // tombol tetap terlihat walau keyboard menutupi sebagian layar.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.content_copy,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Duplikat liga',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Liga baru akan menyalin grup, tim, dan jadwal dengan skor 0-0 (siap untuk musim baru).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Nama liga baru',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    child: const Text('Duplikat'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 56, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Belum ada liga',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat liga baru untuk mulai mengelola turnamen.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
