import 'package:flutter/material.dart';
import '../models/league_config.dart';
import '../database/database_helper.dart';
import '../models/group_model.dart';
import 'team_entry_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ptsWinController = TextEditingController(text: '3');
  final _ptsDrawController = TextEditingController(text: '1');
  final _groupCountController = TextEditingController(text: '2');
  final _teamsPerGroupController = TextEditingController(text: '4');

  String _type = 'league';
  bool _isHomeAway = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ptsWinController.dispose();
    _ptsDrawController.dispose();
    _groupCountController.dispose();
    _teamsPerGroupController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final config = LeagueConfig(
        name: _nameController.text.trim(),
        type: _type,
        ptsWin: int.parse(_ptsWinController.text),
        ptsDraw: int.parse(_ptsDrawController.text),
        isHomeAway: _isHomeAway,
        numberOfGroups: _type == 'group'
            ? int.parse(_groupCountController.text)
            : 1,
        teamsPerGroup: int.parse(_teamsPerGroupController.text),
      );

      final db = DatabaseHelper.instance;
      final leagueId = await db.insertLeague(config);

      // Create groups
      final int groupCount = config.numberOfGroups;
      final List<GroupModel> groups = [];
      for (int i = 0; i < groupCount; i++) {
        final groupName = groupCount == 1
            ? config.name
            : 'Grup ${String.fromCharCode(65 + i)}'; // A, B, C...
        final groupId = await db.insertGroup(GroupModel(
          leagueId: leagueId,
          name: groupName,
        ));
        groups.add(GroupModel(id: groupId, leagueId: leagueId, name: groupName));
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamEntryScreen(
            leagueConfig: config.copyWith(id: leagueId),
            groups: groups,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Turnamen Baru'),
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // League Name
                    _buildCard(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Turnamen',
                          hintText: 'Contoh: Liga 1 Indonesia',
                          prefixIcon: Icon(Icons.emoji_events),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type & Format
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tipe Turnamen',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  )),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'league',
                                label: Text('League'),
                                icon: Icon(Icons.format_list_numbered),
                              ),
                              ButtonSegment(
                                value: 'group',
                                label: Text('Group Stage'),
                                icon: Icon(Icons.groups),
                              ),
                            ],
                            selected: {_type},
                            onSelectionChanged: (v) =>
                                setState(() => _type = v.first),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Home & Away'),
                            subtitle: const Text(
                                'Setiap tim bertemu 2 kali (kandang & tandang)'),
                            value: _isHomeAway,
                            onChanged: (v) => setState(() => _isHomeAway = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Points Settings
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengaturan Poin',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  )),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ptsWinController,
                                  decoration: const InputDecoration(
                                    labelText: 'Poin Menang',
                                    prefixIcon: Icon(Icons.star),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v == null || int.tryParse(v) == null
                                          ? 'Angka'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _ptsDrawController,
                                  decoration: const InputDecoration(
                                    labelText: 'Poin Seri',
                                    prefixIcon: Icon(Icons.handshake),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      v == null || int.tryParse(v) == null
                                          ? 'Angka'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Group settings (conditional)
                    if (_type == 'group')
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pengaturan Grup',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    )),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _groupCountController,
                                    decoration: const InputDecoration(
                                      labelText: 'Jumlah Grup',
                                      prefixIcon: Icon(Icons.category),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      if (n == null || n < 2) {
                                        return 'Min. 2';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _teamsPerGroupController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tim per Grup',
                                      prefixIcon: Icon(Icons.people),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final n = int.tryParse(v ?? '');
                                      if (n == null || n < 2) {
                                        return 'Min. 2';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Teams per group for league mode
                    if (_type == 'league')
                      _buildCard(
                        child: TextFormField(
                          controller: _teamsPerGroupController,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah Tim',
                            prefixIcon: Icon(Icons.people),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 2) return 'Min. 2 tim';
                            return null;
                          },
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Next button
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _onNext,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(_isLoading ? 'Menyimpan...' : 'Lanjut Input Tim'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
