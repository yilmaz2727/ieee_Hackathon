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

    // Sertifikada yalnızca gerçekten kaydedilmiş oyun verilerini kullan.
    // Veri yoksa tahmin/sabit değer üretme.
    final int effectiveScore = totalScore ?? prefs.getInt('total_score') ?? 0;

    final int wasteCount = trashCollected ??
        prefs.getInt('cleanup_count') ??
        prefs.getInt('trash_collected') ??
        ((prefs.getInt('cleanup_score') ?? 0) ~/ 10);
    final int wasteScore = prefs.getInt('cleanup_score') ?? (wasteCount * 10);

    final int fishSaved = protectedFish ??
        prefs.getInt('fish_saved') ??
        prefs.getInt('protected_fish') ??
        0;

    final int effectiveQuizScore = quizScore ?? prefs.getInt('quiz_score') ?? 0;
    final int quizCorrect = prefs.getInt('quiz_correct') ?? (effectiveQuizScore ~/ 20);

    final String cleanedSource = (prefs.getString('cleaned_source_name') ??
            prefs.getString('water_source') ??
            '')
        .trim();

    // Çeviri metinleri
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

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    );

    pw.MemoryImage? photo;
    try {
      photo = pw.MemoryImage(
        (await rootBundle.load('assets/images/picnic.png')).buffer.asUint8List(),
      );
    } catch (_) {}

    final formattedDate = isTurkish
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
              // Üst Başlık Bölümü
              pw.Column(
                children: [
                  pw.Text(
                    tr('certificate.kicker'),
                    style: pw.TextStyle(fontSize: 8, letterSpacing: 2, color: green),
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

              // Resim
              if (photo != null)
                pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(photo, height: 95, width: 200, fit: pw.BoxFit.cover),
                ),

              // Rozet ve Kullanıcı Adı
              pw.Column(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 3),
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

              // BAŞARI LİSTESİ (ALT ALTA VE KESİNLİKLE DOLU)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: rowBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    _buildRowItem(
                      label: isTurkish ? 'Genel Toplam Skor' : 'Total Score Achieved',
                      value: '$effectiveScore PUAN',
                      valueColor: gold,
                      green: green,
                    ),
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5),
                    _buildRowItem(
                      label: isTurkish ? 'Kıyıdan Toplanan Atık' : 'Shore Waste Collected',
                      value: '$wasteCount Adet (+$wasteScore Puan)',
                      valueColor: green,
                      green: green,
                    ),
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5),
                    _buildRowItem(
                      label: isTurkish ? 'Mikroplastikten Korunan Canlı' : 'Creatures Protected',
                      value: '$fishSaved Canlı',
                      valueColor: green,
                      green: green,
                    ),
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5),
                    _buildRowItem(
                      label: isTurkish ? 'Çevre Testi Başarısı' : 'Prevention Quiz Score',
                      value: '$quizCorrect/5 Doğru (%$effectiveQuizScore)',
                      valueColor: gold,
                      green: green,
                    ),
                  ],
                ),
              ),

              // Temizlenen Su Kaynağı
              if (cleanedSource.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#E8F5E9'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    isTurkish
                        ? 'Temizlenen ve Doğrulanan Su Kaynağı: $cleanedSource 🍃'
                        : 'Verified Cleaned Spot: $cleanedSource 🍃',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: green,
                    ),
                  ),
                ),

              // Alt Bilgiler
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
                    style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
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
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: green),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

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

    await Printing.sharePdf(
      bytes: bytes,
      filename: exportFileName,
    );
  }
}