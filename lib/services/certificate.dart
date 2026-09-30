import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../localization/app_localizations.dart';

class CertificateService {
  static Future<Uint8List> build(
    String name,
    DateTime date, {
    String? languageCode,
  }) async {
    final selectedLanguage =
        languageCode ?? AppLocalizations.instance.languageCode;
    final isTurkish = selectedLanguage == 'tr';

    final raw = await rootBundle.loadString('assets/i18n/translations.json');

    final catalogs = jsonDecode(raw) as Map<String, dynamic>;
    final texts = Map<String, dynamic>.from(
      catalogs[isTurkish ? 'tr' : 'en'] as Map,
    );

    // Bu fonksiyon yalnızca PDF'nin metinlerini seçer.
    // Oyunun dil ayarını değiştirmez.
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
    final photo = pw.MemoryImage(
      (await rootBundle.load('assets/images/picnic.png')).buffer.asUint8List(),
    );
    final formattedDate = isTurkish
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final doc = pw.Document(
      title: tr('certificate.title', {'name': name}),
      author: tr('certificate.author'),
    );
    final green = PdfColor.fromHex('#245E4C');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => pw.Container(
          padding: pw.EdgeInsets.all(25),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF9EB'),
            border: pw.Border.all(color: green, width: 2),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                tr('certificate.kicker'),
                style: pw.TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: green,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                tr('certificate.heading'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: green,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                tr('certificate.success'),
                style: pw.TextStyle(fontSize: 12, letterSpacing: 3),
              ),
              pw.SizedBox(height: 20),
              pw.ClipRRect(
                horizontalRadius: 12,
                verticalRadius: 12,
                child: pw.Image(
                  photo,
                  height: 220,
                  width: 350,
                  fit: pw.BoxFit.cover,
                  alignment: pw.Alignment.center,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: pw.EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: pw.BoxDecoration(
                  color: green,
                  borderRadius: pw.BorderRadius.circular(25),
                ),
                child: pw.Text(
                  tr('certificate.badge'),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                name,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: name.length > 35 ? 20 : 27,
                  fontWeight: pw.FontWeight.bold,
                  color: green,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                tr('certificate.body'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 12, lineSpacing: 4),
              ),
              pw.Spacer(),
              pw.Divider(color: green),
              pw.Text(
                tr('certificate.completed', {'date': formattedDate}),
                style: pw.TextStyle(fontSize: 11, color: green),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                tr('certificate.disclaimer'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  static Future<void> download(
    String name,
    DateTime date, {
    String? languageCode,
  }) async {
    final selectedLanguage =
        languageCode ?? AppLocalizations.instance.languageCode;

    final bytes = await build(name, date, languageCode: selectedLanguage);

    await Printing.sharePdf(
      bytes: bytes,
      filename: selectedLanguage == 'tr'
          ? 'Esma_ve_Pipetin_Yolculugu_TR.pdf'
          : 'Esma_and_the_Straws_Journey_EN.pdf',
    );
  }
}
