import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../features/cleanup_verification/data/services/gemini_vision_service.dart';

class AiService {
  AiService._init();

  static final AiService instance = AiService._init();

  final GeminiVisionService _geminiVisionService = GeminiVisionService();

  Future<bool> verifyCleanup(           
    Uint8List imageBytes,
    String mimeType,
  ) async {
    try {
      debugPrint(
        'AI temizlik doğrulaması başlatılıyor...',
      );

      final result =
          await _geminiVisionService.verifyCleanupPhoto(
        imageBytes,
      );

      debugPrint(
        'AI doğrulama sonucu: ${result.accepted}',
      );

      return result.accepted;
    } catch (e) {
      debugPrint(
        'AI doğrulama hatası: $e',
      );

      // AI çalışmadığında görevi otomatik başarılı sayma.
      return false;
    }
  }
}