import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class ImpactEntry {
  ImpactEntry({
    required this.id,
    required this.place,
    required this.lat,
    required this.lng,
    required this.photo,
    required this.date,
  });
  final String id, place, photo, date;
  final double lat, lng;
  Uint8List get bytes => base64Decode(photo);
  Map<String, dynamic> toJson() => {
    'id': id,
    'place': place,
    'lat': lat,
    'lng': lng,
    'photo': photo,
    'date': date,
  };
  factory ImpactEntry.fromJson(Map<String, dynamic> j) => ImpactEntry(
    id: j['id'] as String,
    place: j['place'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    photo: j['photo'] as String,
    date: j['date'] as String,
  );
}

class ImpactStore {
  ImpactStore(this.prefs);
  final SharedPreferences? prefs;
  static const key = 'esma_impact_v1';
  List<ImpactEntry> read() {
    try {
      return (jsonDecode(prefs?.getString(key) ?? '[]') as List)
          .map((j) => ImpactEntry.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } catch (_) {
      throw const FormatException(
        'impact.store.readError',
      );
    }
  }

  Future<void> write(List<ImpactEntry> entries) async {
    if (prefs == null) {
      throw StateError(
        'impact.store.unavailable',
      );
    }
    final data = jsonEncode(entries.map((e) => e.toJson()).toList());
    if (utf8.encode(data).length > 2800000) {
      throw StateError('impact.store.full');
    }
    if (!await prefs!.setString(key, data)) {
      throw StateError('impact.store.saveError');
    }
  }

  static Future<Uint8List> preparePhoto(Uint8List bytes) =>
      compute(_resizePhoto, bytes);
}

Uint8List _resizePhoto(Uint8List bytes) {
  if (bytes.length > 12 * 1024 * 1024) {
    throw const FormatException('impact.maxSize');
  }
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null) {
    throw const FormatException('impact.photo.invalid');
  }
  final info = decoder.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException('impact.photo.tooLargeUnreadable');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('impact.photo.readError');
  final oriented = img.bakeOrientation(decoded);
  final resized = img.copyResize(
    oriented,
    width: oriented.width >= oriented.height ? 900 : null,
    height: oriented.height > oriented.width ? 900 : null,
  );
  // Copy pixels to a fresh image, intentionally excluding EXIF/GPS metadata.
  final clean = img.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  img.compositeImage(clean, resized);
  return Uint8List.fromList(img.encodeJpg(clean, quality: 75));
}
