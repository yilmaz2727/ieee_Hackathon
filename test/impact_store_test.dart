import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esma_game/services/impact_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Photo pins survive loading and deleting without losing other entries',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ImpactStore(prefs);
      final entry = ImpactEntry(
        id: '1',
        place: 'Dere kıyısı',
        lat: 41.1,
        lng: 28.7,
        photo: 'AQID',
        date: '2026-09-23',
      );
      await store.write([entry]);
      final loaded = store.read();
      expect(loaded.single.place, 'Dere kıyısı');
      expect(loaded.single.bytes, [1, 2, 3]);
      await store.write([]);
      expect(store.read(), isEmpty);
    },
  );
  test(
    'Invalid image bytes are rejected rather than saved as a photo',
    () async {
      await expectLater(
        ImpactStore.preparePhoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
