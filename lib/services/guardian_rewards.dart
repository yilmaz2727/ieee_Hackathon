import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../ui/widgets.dart';

class GuardianRewards {
  static String tier(int score) {
    if (score >= 300) return 'gold';
    if (score >= 200) return 'silver';
    return 'bronze';
  }

  static String label(int score, bool tr) {
    return switch (tier(score)) {
      'gold' => tr ? 'Altın' : 'Gold',
      'silver' => tr ? 'Gümüş' : 'Silver',
      _ => tr ? 'Bronz' : 'Bronze',
    };
  }

  static Color color(int score) {
    return switch (tier(score)) {
      'gold' => const Color(0xFFE2AF36),
      'silver' => const Color(0xFF9AA9B8),
      _ => const Color(0xFFB87842),
    };
  }

  static String _key(String userId) => 'guardian_best_reward_v1_$userId';

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('current_user_id');

    if (id == null) return null;

    final raw = prefs.getString(_key(id));
    if (raw == null) return null;

    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  // Yalnızca AI sonucunun accepted olduğu dal tarafından çağrılır.
  static Future<void> recordApprovedRun(String sourceName) {
    return _recordCompletedRun(photoApproved: true, sourceName: sourceName);
  }

  static Future<void> recordWithoutPhoto() {
    return _recordCompletedRun(photoApproved: false);
  }

  static Future<void> _recordCompletedRun({
    required bool photoApproved,
    String? sourceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('current_user_id');
    final nickname = prefs.getString('current_user_nickname');

    if (id == null || nickname == null) {
      throw StateError('No active player.');
    }

    if (prefs.getBool('completed') != true) {
      throw StateError('Complete the game before claiming a reward.');
    }

    final cleanup = prefs.getInt('cleanup_score') ?? 0;
    final protection = prefs.getInt('chapter2_score') ?? 0;
    final puzzle = prefs.getInt('puzzle_score') ?? 0;
    final quiz = prefs.getInt('quiz_score') ?? 0;

    final photoBonus = photoApproved ? 100 : 0;

    // Sabit toplam hesaplanır; tekrar çağrılırsa bonus katlanmaz.
    final score = max(0, cleanup + protection + puzzle + quiz + photoBonus);

    final oldRaw = prefs.getString(_key(id));
    final old = oldRaw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(oldRaw) as Map);

    final oldScore = (old?['score'] as num?)?.toInt() ?? -1;

    // Önceki en iyi başarı korunur.
    if (score > oldScore) {
      final reward = <String, dynamic>{
        'userId': id,
        'nickname': nickname,
        'score': score,
        'tier': tier(score),
        'cleanupScore': cleanup,
        'protectionScore': protection,
        'puzzleScore': puzzle,
        'quizScore': quiz,
        'trashCount': prefs.getInt('cleanup_count') ?? 0,
        'fishSaved': prefs.getInt('fish_saved') ?? 0,
        'quizCorrect': prefs.getInt('quiz_correct') ?? 0,
        'photoBonus': photoBonus,
        'photoVerified': photoApproved,
        'source': photoApproved ? (sourceName ?? '') : '',
        'earnedAt': DateTime.now().toIso8601String(),
      };

      final saved = await prefs.setString(_key(id), jsonEncode(reward));

      if (!saved) {
        throw StateError('Reward could not be saved.');
      }
    }

    await prefs.setInt('bonus_score', photoBonus);
    await prefs.setInt('total_score', score);
    await prefs.setBool('ai_photo_verified', photoApproved);

    if (photoApproved) {
      await prefs.setString('cleaned_source_name', sourceName ?? '');
    } else {
      await prefs.remove('cleaned_source_name');
    }
  }

  static Future<void> downloadCertificate({required bool turkish}) async {
    // Sertifika yalnızca onaylanmış ve saklanmış başarıdan oluşturulur.
    final reward = await load();
    if (reward == null) throw StateError('No approved reward.');

    final score = (reward['score'] as num).toInt();
    final nickname = reward['nickname'] as String;
    final date = DateTime.parse(reward['earnedAt'] as String);
    final photoVerified =
        reward['photoVerified'] == true ||
        (reward['photoVerified'] == null &&
            ((reward['photoBonus'] as num?)?.toInt() ?? 0) > 0);

    final missionSource = photoVerified
        ? (reward['source'] as String? ?? '')
        : (turkish ? 'Fotoğraf görevi atlandı' : 'Photo mission skipped');

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    );

    final medal = switch (tier(score)) {
      'gold' => PdfColor.fromHex('#D6A332'),
      'silver' => PdfColor.fromHex('#8698AB'),
      _ => PdfColor.fromHex('#AF713E'),
    };

    final green = PdfColor.fromHex('#245E4C');
    final doc = pw.Document();

    String t(String tr, String en) => turkish ? tr : en;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (_) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(28),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF9E9'),
            border: pw.Border.all(color: medal, width: 5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                t('SUYUN KORUYUCUSU', 'GUARDIAN OF WATER'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: green,
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                t('Başarı Sertifikası', 'Certificate of Achievement'),
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 35),
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: medal,
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Text(
                  '${label(score, turkish)} ${t('Rozet', 'Badge')}',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                nickname,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: green,
                  fontSize: 25,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                t(
                  'Oyundaki görevleri tamamladı ve gerçek dünya görevi için '
                      'gönderdiği fotoğraf yapay zekâ kontrolünden geçti.',
                  'Completed the game missions and submitted a real-world '
                      'mission photo that passed the AI check.',
                ),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
              ),
              pw.SizedBox(height: 25),
              pw.Text(
                '${t('Onaylanmış en iyi puan', 'Best approved score')}: $score',
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                  color: green,
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                '${t('Toplanan atık', 'Waste collected')}: ${reward['trashCount']}\n'
                '${t('Korunan balık', 'Fish protected')}: ${reward['fishSaved']}\n'
                '${t('Puzzle puanı', 'Puzzle score')}: ${reward['puzzleScore']}\n'
                '${t('Hikâye testi', 'Story quiz')}: ${reward['quizCorrect']}/5\n'
                '${t('Görev yeri', 'Mission location')}: $missionSource',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 5),
              ),
              pw.Spacer(),
              pw.Text(
                '${date.day.toString().padLeft(2, '0')}.'
                '${date.month.toString().padLeft(2, '0')}.${date.year}',
                style: pw.TextStyle(color: green, fontSize: 11),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                photoVerified
                    ? t(
                        'Oyundaki görevleri tamamladı ve gerçek dünya görevi için '
                            'gönderdiği fotoğraf yapay zekâ kontrolünden geçti.',
                        'Completed the game missions and submitted a real-world '
                            'mission photo that passed the AI check.',
                      )
                    : t(
                        'Oyundaki görevleri tamamlayarak atık ayrıştırma, '
                            'mikroplastikler ve su canlılarını koruma konularındaki '
                            'öğrenme yolculuğunu başarıyla bitirdi.',
                        'Completed the game missions and the learning journey '
                            'about waste sorting, microplastics and protecting aquatic life.',
                      ),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: turkish
          ? 'Suyun_Koruyucusu_Sertifikasi.pdf'
          : 'Guardian_of_Water_Certificate.pdf',
    );
  }
}

class GuardianRewardScreen extends StatefulWidget {
  const GuardianRewardScreen({
    super.key,
    required this.onHome,
    required this.onReplay,
  });

  final VoidCallback onHome;
  final VoidCallback onReplay;

  @override
  State<GuardianRewardScreen> createState() => _GuardianRewardScreenState();
}

class _GuardianRewardScreenState extends State<GuardianRewardScreen> {
  late final Future<Map<String, dynamic>?> _reward = GuardianRewards.load();
  bool _exporting = false;

  bool get _tr => AppLocalizations.instance.isTurkish;

  Future<void> _download(bool turkish) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      await GuardianRewards.downloadCertificate(turkish: turkish);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr
                ? 'Sertifika oluşturulamadı. Tekrar dene.'
                : 'Could not create the certificate. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _reward,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final reward = snapshot.data;

        if (reward == null) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Paper(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 50, color: ink),
                    const SizedBox(height: 15),
                    Text(
                      snapshot.hasError
                          ? (_tr
                                ? 'Rozetin şu anda okunamadı.'
                                : 'Could not load your badge.')
                          : (_tr
                                ? 'Rozetini kazanmak için oyunu tamamla.'
                                : 'Complete the game to earn your badge.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    StoryButton(
                      _tr ? 'Ana menü' : 'Home',
                      onPressed: widget.onHome,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final score = (reward['score'] as num).toInt();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Paper(
            child: Column(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 110,
                  color: GuardianRewards.color(score),
                ),
                Text(
                  '${GuardianRewards.label(score, _tr)} '
                  '${_tr ? 'Suyun Koruyucusu' : 'Guardian of Water'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'StorySerif',
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  reward['nickname'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_tr ? 'Onaylanmış en iyi puanın' : 'Best approved score'}: '
                  '$score',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  _tr
                      ? 'Bronz: 0–199 • Gümüş: 200–299 • Altın: 300+\n'
                            'Tekrar oyna, fotoğraf görevini tamamla ve rozetini yükselt. '
                            'Önceki başarın kaybolmaz.'
                      : 'Bronze: 0–199 • Silver: 200–299 • Gold: 300+\n'
                            'Replay and complete the photo mission to upgrade '
                            'your badge. Your previous achievement stays safe.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 22),
                StoryButton(
                  'Türkçe PDF',
                  onPressed: _exporting ? null : () => _download(true),
                  icon: Icons.download_rounded,
                  loading: _exporting,
                ),
                const SizedBox(height: 10),
                StoryButton(
                  'English PDF',
                  secondary: true,
                  onPressed: _exporting ? null : () => _download(false),
                  icon: Icons.download_rounded,
                ),
                const SizedBox(height: 10),
                StoryButton(
                  _tr ? 'Tekrar oyna' : 'Play again',
                  onPressed: _exporting ? null : widget.onReplay,
                  icon: Icons.replay_rounded,
                ),
                const SizedBox(height: 10),
                StoryButton(
                  _tr ? 'Ana menü' : 'Home',
                  secondary: true,
                  onPressed: widget.onHome,
                  icon: Icons.home_outlined,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
