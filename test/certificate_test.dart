import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:esma_game/localization/app_localizations.dart';
import 'package:esma_game/services/certificate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppLocalizations.instance.loadInitial(null);
  });
  test(
    'Certificate handles Turkish and long names with bundled fonts',
    () async {
      final bytes = await CertificateService.build(
        'Çağrı Şükrü Öztürk — Suyun Koruyucusu',
        DateTime(2026, 9, 23),
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(bytes.length, greaterThan(10000));
      await Directory('build/qa').create(recursive: true);
      await File('build/qa/certificate_sample.pdf').writeAsBytes(bytes);
    },
  );
}
