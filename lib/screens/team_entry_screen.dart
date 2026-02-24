import 'package:flutter/material.dart';
import '../models/league_config.dart';
import '../models/group_model.dart';
import '../models/team_model.dart';
import '../database/database_helper.dart';
import '../logic/scheduler.dart';
import 'main_screen.dart';

class TeamEntryScreen extends StatefulWidget {
  final LeagueConfig leagueConfig;
  final List<GroupModel> groups;

  const TeamEntryScreen({
    super.key,
    required this.leagueConfig,
    required this.groups,
  });

  @override
  State<TeamEntryScreen> createState() => _TeamEntryScreenState();
}

class _TeamEntryScreenState extends State<TeamEntryScreen> {
  // Map<groupId, List<TextEditingController>>
  late Map<int, List<TextEditingController>> _controllers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (final group in widget.groups) {
      _controllers[group.id!] = List.generate(
        widget.leagueConfig.teamsPerGroup,
        (_) => TextEditingController(),
      );
    }
  }

  @override
  void dispose() {
    for (final controllers in _controllers.values) {
      for (final c in controllers) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _onGenerate() async {
    // Validate all fields have names
    for (final entry in _controllers.entries) {
      for (int i = 0; i < entry.value.length; i++) {
        if (entry.value[i].text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Semua nama tim harus diisi!'),
              backgroundColor: Colors.red.shade700,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper.instance;

      for (final group in widget.groups) {
        final controllers = _controllers[group.id!]!;

        // Insert teams
        final List<TeamModel> teams = [];
        for (final c in controllers) {
          final teamId = await db.insertTeam(TeamModel(
            groupId: group.id!,
            name: c.text.trim(),
          ));
          teams.add(TeamModel(
            id: teamId,
            groupId: group.id!,
            name: c.text.trim(),
          ));
        }

        // Generate schedule
        final matches = Scheduler.generateRoundRobin(
          teams: teams,
          groupId: group.id!,
          isHomeAway: widget.leagueConfig.isHomeAway,
        );

        await db.insertMatches(matches);
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(
            leagueConfig: widget.leagueConfig,
          ),
        ),
        (route) => false,
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
    final isMultiGroup = widget.groups.length > 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Input Tim'),
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  Card(
                    color: colorScheme.primaryContainer,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: colorScheme.onPrimaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${widget.leagueConfig.name} • '
                              '${isMultiGroup ? "${widget.groups.length} Grup" : "Liga"} • '
                              '${widget.leagueConfig.teamsPerGroup} tim${isMultiGroup ? "/grup" : ""} • '
                              '${widget.leagueConfig.isHomeAway ? "Home & Away" : "Single Match"}',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Team input fields per group
                  for (final group in widget.groups) ...[
                    if (isMultiGroup) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (int i = 0;
                                i < _controllers[group.id!]!.length;
                                i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              TextFormField(
                                controller: _controllers[group.id!]![i],
                                decoration: InputDecoration(
                                  labelText: 'Tim ${i + 1}',
                                  prefixIcon: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  border: const OutlineInputBorder(),
                                  hintText: 'Nama tim...',
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Generate button
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _onGenerate,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(_isLoading
                        ? 'Membuat Jadwal...'
                        : 'Generate Jadwal Pertandingan'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
