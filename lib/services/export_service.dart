import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart'
    show ShareParams, SharePlus, ShareResult, XFile;

import '../models/group_model.dart';
import '../models/knockout_match.dart';
import '../models/league_config.dart';
import '../models/match_model.dart';
import '../models/standing_entry.dart';

/// Ringkasan satu grup untuk keperluan export.
class GroupExportData {
  final GroupModel group;
  final List<StandingEntry> standings;
  final List<MatchModel> matches;

  const GroupExportData({
    required this.group,
    required this.standings,
    required this.matches,
  });
}

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  static const _brandGreen = PdfColor.fromInt(0xFF1B5E20);

  // ==================== PDF ====================

  /// Buat file PDF berisi klasemen (dan opsional jadwal) semua grup.
  ///
  /// Kalau [knockoutMatches] diberikan, halaman tambahan babak gugur
  /// ditambahkan di bagian akhir (semifinal & final).
  Future<File> buildStandingsPdf({
    required LeagueConfig league,
    required List<GroupExportData> groups,
    bool includeSchedule = false,
    List<KnockoutMatch>? knockoutMatches,
  }) async {
    final doc = pw.Document(
      title: 'Klasemen ${league.name}',
      author: 'Turnamen Kita',
    );

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(),
        ),
        header: (ctx) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            league.name,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _brandGreen,
            ),
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount} • $dateStr',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 8),
          pw.Text(
            'Klasemen • $dateStr',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          for (final g in groups) ...[
            pw.Text(
              g.group.name,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _brandGreen,
              ),
            ),
            pw.SizedBox(height: 6),
            _standingsTable(g.standings),
            if (includeSchedule) ...[
              pw.SizedBox(height: 14),
              pw.Text('Jadwal & Hasil',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  )),
              pw.SizedBox(height: 6),
              _scheduleTable(g.matches),
            ],
            pw.SizedBox(height: 18),
          ],
          if (knockoutMatches != null && knockoutMatches.isNotEmpty)
            ..._knockoutSection(knockoutMatches),
        ],
      ),
    );

    final dir = await _tempDir();
    final safeName = _safeFileName(league.name);
    final file = File('${dir.path}/${safeName}_klasemen_$dateStr.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ---- Knockout khusus babak gugur  ----

  List<pw.Widget> _knockoutSection(List<KnockoutMatch> matches) {
    final semis = matches.where((m) => m.stage == 1).toList();
    final finals = matches.where((m) => m.stage == 2).toList();

    pw.Widget cellKo(String text, {bool header = false}) {
      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
                header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? _brandGreen : PdfColors.grey900,
          ),
        ),
      );
    }

    pw.Widget scoreCell(KnockoutMatch k) {
      if (!k.isFinished) return cellKo('-');
      if (k.scoreHome == k.scoreAway) return cellKo('Seri');
      return cellKo('${k.scoreHome} - ${k.scoreAway}');
    }

    final List<pw.Widget> out = [];
    out.add(pw.Divider(color: PdfColors.grey300, height: 1, thickness: 0.5));
    out.add(pw.SizedBox(height: 16));
    out.add(
      pw.Text(
        'Babak Gugur',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: _brandGreen,
        ),
      ),
    );

    void table(String title, List<KnockoutMatch> list) {
      out.add(pw.SizedBox(height: 8));
      out.add(
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      );
      out.add(pw.SizedBox(height: 6));
      out.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(34),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(4),
            3: pw.FixedColumnWidth(72),
          },
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F5E9)),
              children: [
                cellKo('Tag', header: true),
                cellKo('Tim 1', header: true),
                cellKo('Tim 2', header: true),
                cellKo('Hasil', header: true),
              ],
            ),
            for (final k in list)
              pw.TableRow(
                children: [
                  cellKo(k.stage == 1 ? 'SF' : 'FINAL'),
                  cellKo(k.homeLabel),
                  cellKo(k.awayLabel),
                  scoreCell(k),
                ],
              ),
          ],
        ),
      );
    }

    if (semis.isNotEmpty) table('Semifinal', semis);
    if (finals.isNotEmpty) table('Final', finals);

    return out;
  }

  pw.Widget _standingsTable(List<StandingEntry> rows) {
    pw.Widget cell(String text,
        {bool header = false, pw.Alignment align = pw.Alignment.center}) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
                header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? _brandGreen : PdfColors.grey900,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FlexColumnWidth(4),
        2: pw.FixedColumnWidth(24),
        3: pw.FixedColumnWidth(24),
        4: pw.FixedColumnWidth(24),
        5: pw.FixedColumnWidth(24),
        6: pw.FixedColumnWidth(26),
        7: pw.FixedColumnWidth(26),
        8: pw.FixedColumnWidth(26),
        9: pw.FixedColumnWidth(30),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F5E9)),
          children: [
            cell('#', header: true),
            cell('Tim', header: true, align: pw.Alignment.centerLeft),
            cell('M', header: true),
            cell('W', header: true),
            cell('D', header: true),
            cell('L', header: true),
            cell('GF', header: true),
            cell('GA', header: true),
            cell('GD', header: true),
            cell('Pts', header: true),
          ],
        ),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final isTop2 = i < 2;
          final gd = s.goalDifference;
          return pw.TableRow(
            decoration: isTop2
                ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F8E9))
                : null,
            children: [
              cell('${i + 1}'),
              cell(s.teamName,
                  align: pw.Alignment.centerLeft),
              cell('${s.played}'),
              cell('${s.won}'),
              cell('${s.drawn}'),
              cell('${s.lost}'),
              cell('${s.goalsFor}'),
              cell('${s.goalsAgainst}'),
              cell(gd > 0 ? '+$gd' : '$gd'),
              cell('${s.points}'),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _scheduleTable(List<MatchModel> matches) {
    pw.Widget cell(String text,
        {bool header = false, pw.Alignment align = pw.Alignment.center}) {
      return pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? PdfColors.grey800 : PdfColors.grey900,
          ),
        ),
      );
    }

    final sorted = [...matches]..sort((a, b) => a.round.compareTo(b.round));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(40),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(4),
        3: pw.FixedColumnWidth(55),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            cell('Pekan', header: true),
            cell('Tim 1', header: true, align: pw.Alignment.centerLeft),
            cell('Tim 2', header: true, align: pw.Alignment.centerLeft),
            cell('Hasil', header: true),
          ],
        ),
        ...sorted.map((m) => pw.TableRow(children: [
              cell('${m.round}'),
              cell(m.homeTeamName ?? '-', align: pw.Alignment.centerLeft),
              cell(m.awayTeamName ?? '-', align: pw.Alignment.centerLeft),
              cell(m.isFinished ? '${m.scoreHome} - ${m.scoreAway}' : '-'),
            ])),
      ],
    );
  }

  // ==================== SHARE ====================

  Future<ShareResult> shareFiles(List<File> files, {String? text}) {
    final xFiles = files.map((f) => XFile(f.path)).toList();
    return SharePlus.instance.share(ShareParams(files: xFiles, text: text));
  }

  /// Salin ringkasan babak gugur ke clipboard (WhatsApp). Dipakai dari tab
  /// "Knockout" dengan dua mode yang sama: [copyKnockoutText].
  Future<void> copyKnockoutText({
    required LeagueConfig league,
    required List<KnockoutMatch> matches,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    if (matches.isEmpty) {
      await Clipboard.setData(
        ClipboardData(text: '*${league.name}*\n\nBelum ada babak gugur.'),
      );
      return;
    }

    String rowOf(KnockoutMatch k, String tag) {
      final hasil = k.isFinished
          ? '${k.scoreHome} - ${k.scoreAway}'
          : 'belum main';
      return '• *$tag* — ${k.homeLabel} $hasil ${k.awayLabel}';
    }

    final b = StringBuffer()
      ..writeln('*${league.name}*')
      ..writeln('🏆 BABAK GUGUR')
      ..writeln('_${dateStr}_')
      ..writeln();

    final semis = matches.where((m) => m.stage == 1).toList();
    final finals = matches.where((m) => m.stage == 2).toList();

    if (semis.isNotEmpty) {
      b.writeln('⚔️ SEMIFINAL');
      for (var i = 0; i < semis.length; i++) {
        b.writeln(rowOf(semis[i], 'SF${i + 1}'));
      }
      b.writeln();
    }
    if (finals.isNotEmpty) {
      b.writeln('👑 FINAL');
      b.writeln(rowOf(finals.first, 'FINAL'));
      b.writeln();
    }
    b.writeln('_Dibuat via Turnamen Kita_');

    await Clipboard.setData(ClipboardData(text: b.toString()));
  }

  /// Salin ringkasan klasemen ke clipboard dalam format tabel WhatsApp.
  ///
  /// Pakai emoji + baris tabel bergaris agar tetap rapi di layar HP yang
  /// sempit, dan angka selalu rata kanan per kolom.
  Future<void> copyStandingsText({
    required LeagueConfig league,
    required GroupExportData data,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final rows = data.standings;
    if (rows.isEmpty) {
      await Clipboard.setData(ClipboardData(
        text: '*${league.name}*\n\nBelum ada data klasemen.',
      ));
      return;
    }

    // Lebar kolom: tim dibiarkan lebar, angka dibuat rata dengan padding.
    final teamWidth = rows
        .map((e) => e.teamName.length)
        .fold<int>(4, (a, b) => a > b ? a : b)
        .clamp(10, 22);

    String l(String v, int w) =>
        v.length >= w ? v.substring(0, w) : v.padRight(w);

    String r(String v, int w) => v.padLeft(w);

    // Hitung panjang baris agar garis pemisah pas.
    final line = '═' * (teamWidth + 30);

    final b = StringBuffer()
      ..writeln('*${league.name}*')
      ..writeln('🏆 KLASEMEN ${data.group.name.toUpperCase()}')
      ..writeln('_${dateStr}_')
      ..writeln()
      ..writeln(line)
      ..writeln('${l("#", 2)} │ ${l("TIM", teamWidth)} │'
          ' ${r("M", 2)} ${r("W", 2)} ${r("D", 2)} ${r("L", 2)} │'
          ' ${r("GD", 3)} ${r("PTS", 3)}')
      ..writeln(line);

    for (var i = 0; i < rows.length; i++) {
      final s = rows[i];
      final pos = i + 1;
      final gd = s.goalDifference;
      final gdText = gd > 0 ? '+$gd' : '$gd';

      final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : '  ');
      final rank = '$medal$pos';

      final row = '${l(rank, 4)}│ ${l(s.teamName, teamWidth)} │'
          ' ${r("${s.played}", 2)} ${r("${s.won}", 2)}'
          ' ${r("${s.drawn}", 2)} ${r("${s.lost}", 2)} │'
          ' ${r(gdText, 3)} ${r("${s.points}", 3)}';

      // Tabel WhatsApp tidak bisa bold per sel, jadi pakai tanda bintang
      // hanya untuk tim peringkat 1 & 2 agar mudah dibaca.
      b.writeln(i < 2 ? '*$row*' : row);
    }

    b
      ..writeln(line)
      ..writeln()
      ..writeln('📊 Keterangan:')
      ..writeln('M = Main, W = Menang, D = Seri, L = Kalah')
      ..writeln('GD = Selisih Gol, Pts = Poin')
      ..writeln()
      ..writeln('_Dibuat via Turnamen Kita_');

    await Clipboard.setData(ClipboardData(text: b.toString()));
  }

  Future<Directory> _tempDir() async {
    final dir = await getTemporaryDirectory();
    final exportDir = Directory('${dir.path}/turnamen_export');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  static String _safeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }
}