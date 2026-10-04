import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../../domain/entities/verification_result.dart';

class GeminiVisionService {
  // Önbellek için değişken
  static String? _cachedApiKey;

  // .env dosyasından anahtarı okuyan yardımcı metod
  static Future<String> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    try {
      final envString = await rootBundle.loadString('.env');
      for (final line in envString.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('GEMINI_API_KEY=')) {
          _cachedApiKey = trimmed.substring('GEMINI_API_KEY='.length).trim();
          return _cachedApiKey!;
        }
      }
    } catch (e) {
      debugPrint('.env okuma hatası: $e');
    }
    return '';
  }

  final List<String> _modelsToTry = [
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.0-flash',
  ];

  Future<VerificationResult> verifyCleanupPhoto(Uint8List imageBytes) async {
    // API anahtarını .env dosyasından alıyoruz:
    final apiKey = await _getApiKey();

    if (apiKey.isEmpty) {
      return VerificationResult.fromJson({
        'accepted': false,
        'reason':
            'AI doğrulama servisi yapılandırılmamış. GEMINI_API_KEY bulunamadı.',
      });
    }

    // ... (metodun geri kalan kısmı aynı şekilde devam eder)

    const prompt = '''
Bu fotoğrafı çevre temizliği görevi açısından değerlendir.

Fotoğrafta aşağıdakilerden en az biri açıkça görülmelidir:
- Toplanmış çöp veya atık
- Plastik şişe, ambalaj veya benzeri atıklar
- Çöp torbası veya atık toplama kabı
- Doğal bir alanın temizlendiğine dair makul görsel kanıt

Şunları kabul etme:
- Sadece doğa veya manzara fotoğrafı
- Hiç çöp/atık görünmeyen fotoğraf
- Görevle ilgisiz fotoğraf
- Temizlik yapıldığını doğrulamaya yetmeyen fotoğraf

Yalnızca aşağıdaki JSON formatında cevap ver:

{
  "accepted": true veya false,
  "reason": "Kısa açıklama"
}
''';

    Uint8List optimizedBytes = imageBytes;

    try {
      final image = img.decodeImage(imageBytes);

      if (image != null) {
        var resized = image;

        if (image.width > 768 || image.height > 768) {
          if (image.width >= image.height) {
            resized = img.copyResize(image, width: 768);
          } else {
            resized = img.copyResize(image, height: 768);
          }
        }

        optimizedBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: 75),
        );

        debugPrint('Image optimized: ${optimizedBytes.length} bytes');
      }
    } catch (e) {
      debugPrint('Image optimization error: $e');
    }

    for (final modelName in _modelsToTry) {
      try {
        debugPrint('Trying Gemini model: $modelName');

        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.1,
            responseMimeType: 'application/json',
          ),
        );

        final response = await model
            .generateContent([
              Content.multi([
                TextPart(prompt),
                DataPart('image/jpeg', optimizedBytes),
              ]),
            ])
            .timeout(const Duration(seconds: 12));

        final responseText = response.text;

        if (responseText == null || responseText.trim().isEmpty) {
          throw Exception('Model boş yanıt döndürdü.');
        }

        var cleanedJson = responseText.trim();

        if (cleanedJson.startsWith('```json')) {
          cleanedJson = cleanedJson.substring(7).trim();
        } else if (cleanedJson.startsWith('```')) {
          cleanedJson = cleanedJson.substring(3).trim();
        }

        if (cleanedJson.endsWith('```')) {
          cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3).trim();
        }

        final decoded = jsonDecode(cleanedJson);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException(
            'Gemini geçerli bir JSON nesnesi döndürmedi.',
          );
        }

        if (decoded['accepted'] is! bool) {
          throw const FormatException('accepted alanı bool değil.');
        }

        return VerificationResult.fromJson(decoded);
      } catch (e) {
        debugPrint('Gemini error ($modelName): $e');
      }
    }

    // AI gerçekten doğrulama yapamadıysa
    // görevi otomatik başarılı saymıyoruz.
    return VerificationResult.fromJson({
      'accepted': false,
      'reason':
          'Fotoğraf şu anda AI tarafından doğrulanamadı. Lütfen tekrar deneyin.',
    });
  }
}
