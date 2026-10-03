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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // Batas tinggi yang realistis untuk layar pendek.
    final maxH = MediaQuery.of(context).size.height * (isLandscape ? 0.88 : 0.82);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 32 : 24,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 520),
        child: SingleChildScrollView(
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
              SizedBox(height: isLandscape ? 12 : 24),

              // Score input area
              if (isLandscape)
                // Layout mendatar khusus landscape: kompak agar muat.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildTeamColumn(
                      name: widget.homeTeam,
                      badge: 'Home',
                      badgeColor: colorScheme.primary,
                      score: _homeScore,
                      onIncrement: () => setState(() => _homeScore++),
                      onDecrement: () {
                        if (_homeScore > 0) setState(() => _homeScore--);
                      },
                      compact: true,
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('VS',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    Expanded(child: _buildTeamColumn(
                      name: widget.awayTeam,
                      badge: 'Away',
                      badgeColor: colorScheme.error,
                      score: _awayScore,
                      onIncrement: () => setState(() => _awayScore++),
                      onDecrement: () {
                        if (_awayScore > 0) setState(() => _awayScore--);
                      },
                      compact: true,
                    )),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _buildTeamColumn(
                      name: widget.homeTeam,
                      badge: 'Home',
                      badgeColor: colorScheme.primary,
                      score: _homeScore,
                      onIncrement: () => setState(() => _homeScore++),
                      onDecrement: () {
                        if (_homeScore > 0) setState(() => _homeScore--);
                      },
                    )),
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
                    Expanded(child: _buildTeamColumn(
                      name: widget.awayTeam,
                      badge: 'Away',
                      badgeColor: colorScheme.error,
                      score: _awayScore,
                      onIncrement: () => setState(() => _awayScore++),
                      onDecrement: () {
                        if (_awayScore > 0) setState(() => _awayScore--);
                      },
                    )),
                  ],
                ),

              SizedBox(height: isLandscape ? 14 : 28),

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
      ),
    );
  }

  Widget _buildTeamColumn({
    required String name,
    required String badge,
    required Color badgeColor,
    required int score,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    bool compact = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(badge,
            style: TextStyle(
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.w500,
            )),
        SizedBox(height: compact ? 8 : 12),
        _buildScoreControl(
          score: score,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildScoreControl({
    required int score,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    bool compact = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final boxSize = compact ? 46.0 : 60.0;
    final gap = compact ? 4.0 : 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
          ),
        ),
        SizedBox(height: gap),
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontSize: compact ? 28 : null,
                  ),
            ),
          ),
        ),
        SizedBox(height: gap),
        IconButton.filled(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
          ),
        ),
      ],
    );
  }
}
