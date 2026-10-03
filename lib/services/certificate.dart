import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';

class CertificateService {
  static Future<Uint8List> build(
    String name,
    DateTime date, {
    String? languageCode,
    int? totalScore,
    int? trashCollected,
    int? protectedFish,
    int? quizScore,
  }) async {
    final selectedLanguage =
        languageCode ?? AppLocalizations.instance.languageCode;

    final isTurkish = selectedLanguage == 'tr';

    final prefs = await SharedPreferences.getInstance();

    // ============================================================
    // GERÇEK OYUN VERİLERİ
    // ============================================================

    // 1. GERÇEK TOPLAM SKOR
    //
    // Öncelik:
    // 1) main.dart tarafından gönderilen totalScore
    // 2) SharedPreferences'taki total_score
    // 3) Veri yoksa 0
    //
    // Artık 309 gibi uydurma bir varsayılan değer YOK.
    final int effectiveScore = totalScore ?? prefs.getInt('total_score') ?? 0;

    // ------------------------------------------------------------
    // 2. GERÇEK TOPLANAN ATIK SAYISI
    // ------------------------------------------------------------

    final int wasteCount =
        trashCollected ??
        prefs.getInt('cleanup_count') ??
        prefs.getInt('trash_collected') ??
        ((prefs.getInt('cleanup_score') ?? 0) ~/ 10);

    // cleanup_score varsa doğrudan onu kullan.
    // Yoksa gerçek atık sayısı * 10.
    final int wasteScore = prefs.getInt('cleanup_score') ?? (wasteCount * 10);

    // ------------------------------------------------------------
    // 3. GERÇEK KORUNAN CANLI SAYISI
    // ------------------------------------------------------------
    //
    // DİKKAT:
    // healing_score burada kullanılmıyor.
    //
    // Çünkü:
    // fish_saved     = canlı ADEDİ
    // healing_score  = bölüm PUANI
    //
    // Bunlar aynı veri değildir.
    final int fishSaved =
        protectedFish ??
        prefs.getInt('fish_saved') ??
        prefs.getInt('protected_fish') ??
        0;

    // ------------------------------------------------------------
    // 4. GERÇEK QUIZ SONUCU
    // ------------------------------------------------------------

    final int effectiveQuizScore = quizScore ?? prefs.getInt('quiz_score') ?? 0;

    final int quizCorrect =
        prefs.getInt('quiz_correct') ?? (effectiveQuizScore ~/ 20);

    // Quiz yüzdesini güvenli aralıkta tut.
    final int quizPercentage = effectiveQuizScore.clamp(0, 100).toInt();

    // ------------------------------------------------------------
    // 5. GERÇEKTEN TEMİZLENEN / DOĞRULANAN SU KAYNAĞI
    // ------------------------------------------------------------
    //
    // Artık "Kent Park Göleti" gibi uydurma fallback yok.
    // Kaynak gerçekten kaydedilmişse sertifikada gösterilir.
    final String cleanedSource =
        (prefs.getString('cleaned_source_name') ??
                prefs.getString('water_source') ??
                '')
            .trim();

    // ============================================================
    // ÇEVİRİ METİNLERİ
    // ============================================================

    final raw = await rootBundle.loadString('assets/i18n/translations.json');

    final catalogs = jsonDecode(raw) as Map<String, dynamic>;

    final texts = Map<String, dynamic>.from(
      catalogs[isTurkish ? 'tr' : 'en'] as Map,
    );

    String tr(String key, [Map<String, Object?> params = const {}]) {
      var value = texts[key]?.toString() ?? key;

      for (final entry in params.entries) {
        value = value.replaceAll('{${entry.key}}', '${entry.value}');
      }

      return value;
    }

    // ============================================================
    // FONTLAR
    // ============================================================

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
    );

    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    );

    // ============================================================
    // SERTİFİKA RESMİ
    // ============================================================

    pw.MemoryImage? photo;

    try {
      photo = pw.MemoryImage(
        (await rootBundle.load(
          'assets/images/picnic.png',
        )).buffer.asUint8List(),
      );
    } catch (_) {
      photo = null;
    }

    // ============================================================
    // TARİH
    // ============================================================

    final formattedDate = isTurkish
        ? '${date.day.toString().padLeft(2, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.year}'
        : '${date.year}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';

    // ============================================================
    // PDF
    // ============================================================

    final doc = pw.Document(
      title: tr('certificate.title', {'name': name}),
      author: tr('certificate.author'),
    );

    final green = PdfColor.fromHex('#245E4C');
    final gold = PdfColor.fromHex('#B45309');
    final rowBg = PdfColor.fromHex('#F8FAF6');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFFDF5'),
            border: pw.Border.all(color: green, width: 2),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // ==================================================
              // ÜST BAŞLIK
              // ==================================================
              pw.Column(
                children: [
                  pw.Text(
                    tr('certificate.kicker'),
                    style: pw.TextStyle(
                      fontSize: 8,
                      letterSpacing: 2,
                      color: green,
                    ),
                  ),

                  pw.SizedBox(height: 2),

                  pw.Text(
                    tr('certificate.heading'),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),

                  pw.SizedBox(height: 1),

                  pw.Text(
                    tr('certificate.success'),
                    style: const pw.TextStyle(fontSize: 8, letterSpacing: 1.5),
                  ),
                ],
              ),

              // ==================================================
              // RESİM
              // ==================================================
              if (photo != null)
                pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    photo,
                    height: 95,
                    width: 200,
                    fit: pw.BoxFit.cover,
                  ),
                ),

              // ==================================================
              // ROZET + KULLANICI ADI
              // ==================================================
              pw.Column(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: green,
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text(
                      tr('certificate.badge'),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        fontSize: 8,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 4),

                  pw.Text(
                    name,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),

                  pw.SizedBox(height: 3),

                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 20),
                    child: pw.Text(
                      tr('certificate.body'),
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8, lineSpacing: 1.5),
                    ),
                  ),
                ],
              ),

              // ==================================================
              // GERÇEK BAŞARI VERİLERİ
              // ==================================================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: rowBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#CBD5E1'),
                    width: 0.8,
                  ),
                ),
                child: pw.Column(
                  children: [
                    // --------------------------------------------
                    // TOPLAM PUAN
                    // --------------------------------------------
                    _buildRowItem(
                      label: isTurkish
                          ? 'Genel Toplam Skor'
                          : 'Total Score Achieved',
                      value: isTurkish
                          ? '$effectiveScore Puan'
                          : '$effectiveScore Points',
                      valueColor: gold,
                      green: green,
                    ),

                    pw.Divider(
                      color: PdfColor.fromHex('#E2E8F0'),
                      thickness: 0.5,
                    ),

                    // --------------------------------------------
                    // ATIK
                    // --------------------------------------------
                    _buildRowItem(
                      label: isTurkish
                          ? 'Kıyıdan Toplanan Atık'
                          : 'Shore Waste Collected',
                      value: isTurkish
                          ? '$wasteCount Adet (+$wasteScore Puan)'
                          : '$wasteCount Items (+$wasteScore Points)',
                      valueColor: green,
                      green: green,
                    ),

                    pw.Divider(
                      color: PdfColor.fromHex('#E2E8F0'),
                      thickness: 0.5,
                    ),

                    // --------------------------------------------
                    // KORUNAN CANLI
                    // --------------------------------------------
                    _buildRowItem(
                      label: isTurkish
                          ? 'Mikroplastikten Korunan Canlı'
                          : 'Creatures Protected',
                      value: isTurkish
                          ? '$fishSaved Canlı'
                          : '$fishSaved Creatures',
                      valueColor: green,
                      green: green,
                    ),

                    pw.Divider(
                      color: PdfColor.fromHex('#E2E8F0'),
                      thickness: 0.5,
                    ),

                    // --------------------------------------------
                    // QUIZ
                    // --------------------------------------------
                    _buildRowItem(
                      label: isTurkish
                          ? 'Çevre Testi Başarısı'
                          : 'Prevention Quiz Score',
                      value: isTurkish
                          ? '$quizCorrect/5 Doğru '
                                '(%$quizPercentage)'
                          : '$quizCorrect/5 Correct '
                                '($quizPercentage%)',
                      valueColor: gold,
                      green: green,
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GERÇEKTEN TEMİZLENEN SU KAYNAĞI
              // ==================================================
              if (cleanedSource.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2.5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#E8F5E9'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    isTurkish
                        ? 'Temizlenen ve Doğrulanan '
                              'Su Kaynağı: $cleanedSource'
                        : 'Verified Cleaned Spot: '
                              '$cleanedSource',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),
                ),

              // ==================================================
              // ALT BİLGİLER
              // ==================================================
              pw.Column(
                children: [
                  pw.Divider(color: green, thickness: 0.6),

                  pw.SizedBox(height: 2),

                  pw.Text(
                    tr('certificate.completed', {'date': formattedDate}),
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: green,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 1),

                  pw.Text(
                    tr('certificate.disclaimer'),
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  // ============================================================
  // SATIR WIDGET'I
  // ============================================================

  static pw.Widget _buildRowItem({
    required String label,
    required String value,
    required PdfColor valueColor,
    required PdfColor green,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: green,
              ),
            ),
          ),

          pw.SizedBox(width: 8),

          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PDF İNDİR / PAYLAŞ
  // ============================================================

  static Future<void> download(
    String name,
    DateTime date, {
    String? languageCode,
    int? totalScore,
    int? trashCollected,
    int? protectedFish,
    int? quizScore,
  }) async {
    final selectedLanguage =
        languageCode ?? AppLocalizations.instance.languageCode;

    final isTurkish = selectedLanguage == 'tr';

    final bytes = await build(
      name,
      date,
      languageCode: selectedLanguage,
      totalScore: totalScore,
      trashCollected: trashCollected,
      protectedFish: protectedFish,
      quizScore: quizScore,
    );

    final cleanFileName = name
        .replaceAll(RegExp(r'[^\w\s]+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    final String exportFileName = isTurkish
        ? '${cleanFileName}_Suyun_Koruyucusu_Sertifikasi.pdf'
        : '${cleanFileName}_Guardian_of_Water_Certificate.pdf';

    await Printing.sharePdf(bytes: bytes, filename: exportFileName);
  }
}
