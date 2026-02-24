import 'package:flutter/material.dart';

class ScoreInputDialog extends StatefulWidget {
  final String homeTeam;
  final String awayTeam;
  final int initialHomeScore;
  final int initialAwayScore;

  const ScoreInputDialog({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.initialHomeScore = 0,
    this.initialAwayScore = 0,
  });

  @override
  State<ScoreInputDialog> createState() => _ScoreInputDialogState();
}

class _ScoreInputDialogState extends State<ScoreInputDialog> {
  late int _homeScore;
  late int _awayScore;

  @override
  void initState() {
    super.initState();
    _homeScore = widget.initialHomeScore;
    _awayScore = widget.initialAwayScore;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Input Skor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Score input area
            Row(
              children: [
                // Home team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.homeTeam,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('Home',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(height: 12),
                      _buildScoreControl(
                        score: _homeScore,
                        onIncrement: () =>
                            setState(() => _homeScore++),
                        onDecrement: () {
                          if (_homeScore > 0) {
                            setState(() => _homeScore--);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // VS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'VS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.outline,
                        ),
                  ),
                ),

                // Away team
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        widget.awayTeam,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('Away',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          )),
                      const SizedBox(height: 12),
                      _buildScoreControl(
                        score: _awayScore,
                        onIncrement: () =>
                            setState(() => _awayScore++),
                        onDecrement: () {
                          if (_awayScore > 0) {
                            setState(() => _awayScore--);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'home': _homeScore,
                        'away': _awayScore,
                      });
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
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

  Widget _buildScoreControl({
    required int score,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        IconButton.filled(
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            '$score',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
          ),
        ),
        const SizedBox(height: 8),
        IconButton.filled(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
        ),
      ],
    );
  }
}
