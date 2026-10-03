import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  static final AiService instance = AiService._init();

  // Initialize with a default key or an empty string, later handling it if we need an actual key.
  // We can leave this dummy or use a real key but for hackathon / fallback, if it fails, we fast-fail to verified.
  late final GenerativeModel _model25;
  late final GenerativeModel _model15;
  final String _apiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  AiService._init() {
    _model25 = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
    _model15 = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  Future<bool> verifyCleanup(Uint8List imageBytes, String mimeType) async {
    if (_apiKey.isEmpty) {
      // If we don't have a key during test, fail-safe to true.
      return true;
    }

    final prompt = TextPart(
      "Does this photo realistically show a person cleaning up trash/waste from a natural water source or nature? Answer only with 'YES' or 'NO'.",
    );
    final imagePart = DataPart(mimeType, imageBytes);

    try {
      // Primary model: gemini-2.5-flash with 10s timeout
      final response = await _model25
          .generateContent([
            Content.multi([prompt, imagePart]),
          ])
          .timeout(const Duration(seconds: 10));

      return response.text?.trim().toUpperCase().contains('YES') ?? true;
    } catch (e) {
      try {
        // Fallback model: gemini-1.5-flash with 10s timeout
        final fallbackResponse = await _model15
            .generateContent([
              Content.multi([prompt, imagePart]),
            ])
            .timeout(const Duration(seconds: 10));

        return fallbackResponse.text?.trim().toUpperCase().contains('YES') ??
            true;
      } catch (fallbackError) {
        // Fail-safe logic: If network or quota fails, return true so we don't block the user
        return true;
      }
    }
  }
}
