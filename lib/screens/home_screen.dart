import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/league_config.dart';
import 'setup_screen.dart';
import 'main_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LeagueConfig? _lastLeague;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLastLeague();
  }

  Future<void> _loadLastLeague() async {
    final leagues = await DatabaseHelper.instance.getAllLeagues();
    if (leagues.isNotEmpty) {
      setState(() {
        _lastLeague = leagues.first;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          // LayoutBuilder dipakai agar versi scroll tetap bisa
          // mengisi penuh tinggi layar (minHeight) tanpa Spacer,
          // sehingga tidak overflow di mode landscape yang pendek.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = MediaQuery.of(context).orientation ==
                  Orientation.landscape;
              if (isLandscape) {
                return _buildLandscapeBody(constraints, colorScheme);
              }
              return _buildPortraitBody(constraints, colorScheme);
            },
          ),
        ),
      ),
    );
  }

  /// Tampilan potret: sama seperti sebelumnya, tapi tanpa Spacer
  /// dan dibungkus scroll agar aman di layar pendek.
  Widget _buildPortraitBody(
      BoxConstraints constraints, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight - 48,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            _buildLogo(colorScheme),
            const SizedBox(height: 24),
            // App name
            Text(
              'Turnamen Kita',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola Turnamen Sepakbola Anda',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            // Menu buttons
            _buildMenuButtons(colorScheme),
            const SizedBox(height: 32),
            // Creator info
            _buildCreatorInfo(colorScheme),
          ],
        ),
      ),
    );
  }

  /// Tampilan landscape: logo+judul di kiri, menu di kanan,
  /// dibungkus scroll vertikal agar tidak overflow.
  Widget _buildLandscapeBody(
      BoxConstraints constraints, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight - 32,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Kiri: logo + nama + info kreator
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(colorScheme, size: 84),
                  const SizedBox(height: 12),
                  Text(
                    'Turnamen Kita',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola Turnamen Sepakbola Anda',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildCreatorInfo(colorScheme, compact: true),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Kanan: tombol menu
            Expanded(
              child: _buildMenuButtons(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(ColorScheme colorScheme, {double size = 140}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.asset(
          'assets/icon.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildMenuButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        // New League button
        _buildMenuButton(
          context: context,
          icon: Icons.add_circle_outline,
          title: 'Liga Baru',
          subtitle: 'Buat turnamen baru',
          colorScheme: colorScheme,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          ),
        ),
        const SizedBox(height: 16),
        // Continue League button
        if (_isLoading)
          _buildContinueButtonLoading(colorScheme)
        else if (_lastLeague != null)
          _buildMenuButton(
            context: context,
            icon: Icons.play_circle_outline,
            title: 'Lanjutkan Liga',
            subtitle: _lastLeague!.name,
            colorScheme: colorScheme,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MainScreen(leagueConfig: _lastLeague!),
              ),
            ),
          )
        else
          _buildEmptyContinueButton(colorScheme),
      ],
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 28,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 28,
              color: colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButtonLoading(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lanjutkan Liga',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Memuat data...',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyContinueButton(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.play_circle_outline,
              size: 28,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lanjutkan Liga',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Belum ada liga sebelumnya',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorInfo(ColorScheme colorScheme, {bool compact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          thickness: 1,
        ),
        SizedBox(height: compact ? 6 : 12),
        // Bungkus dalam FittedBox agar tidak meluber saat landscape sempit.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Dibuat oleh ',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    'L9kyuu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '0851-5682-2397',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
