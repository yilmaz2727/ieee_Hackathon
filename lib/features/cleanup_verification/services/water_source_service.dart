import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationAccuracyException implements Exception {
  final double accuracy;

  const LocationAccuracyException(this.accuracy);
}

class WaterSource {
  const WaterSource({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description = '',
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String description;
}

class WaterSourceCheckResult {
  const WaterSourceCheckResult({
    required this.found,
    required this.message,
    this.name,
    this.type,
    this.latitude,
    this.longitude,
  });

  final bool found;
  final String message;

  final String? name;
  final String? type;

  final double? latitude;
  final double? longitude;
}

class WaterSourceService {
  static const int searchRadiusMeters = 10000;

  static const String _overpassUrl =
      'https://overpass-api.de/api/interpreter';

  /// Telefonun mevcut konumunu alır.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Konum servisi kapalı. Lütfen telefonunuzun konumunu açın.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Konum izni verilmedi.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Konum izni kalıcı olarak reddedilmiş. '
        'Telefon ayarlarından uygulamaya konum izni vermelisiniz.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Fake GPS / mock location kontrolü
    if (position.isMocked) {
      throw Exception(
        'Sahte konum algılandı. '
        'Görev için gerçek GPS konumunuzu kullanmalısınız.',
      );
    }

    // 100 metre kontrolü yapacağımız için
    // aşırı hatalı GPS verisini kabul etmiyoruz.
if (position.accuracy > 150) {
  throw LocationAccuracyException(position.accuracy);
}

    return position;
  }

  /// Kullanıcının mevcut konumunun 100 metre çevresinde
  /// uygun su kaynağı olup olmadığını kontrol eder.
  Future<WaterSourceCheckResult> checkNearbyWaterSource(
    Position position,
  ) async {
    final lat = position.latitude;
    final lon = position.longitude;

    final query = '''
[out:json][timeout:15];
(
  node(around:$searchRadiusMeters,$lat,$lon)
    ["natural"="spring"];

  way(around:$searchRadiusMeters,$lat,$lon)
    ["natural"="spring"];

  node(around:$searchRadiusMeters,$lat,$lon)
    ["waterway"~"^(river|stream)\$"];

  way(around:$searchRadiusMeters,$lat,$lon)
    ["waterway"~"^(river|stream)\$"];

  relation(around:$searchRadiusMeters,$lat,$lon)
    ["waterway"~"^(river|stream)\$"];

  node(around:$searchRadiusMeters,$lat,$lon)
    ["natural"="water"];

  way(around:$searchRadiusMeters,$lat,$lon)
    ["natural"="water"];

  relation(around:$searchRadiusMeters,$lat,$lon)
    ["natural"="water"];
);
out tags center;
''';

    final response = await http
        .post(
          Uri.parse(_overpassUrl),
          headers: const {
            'Content-Type':
                'application/x-www-form-urlencoded; charset=UTF-8',
          },
          body: {
            'data': query,
          },
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Su kaynağı sorgulanamadı. '
        'Sunucu kodu: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Su kaynağı servisinden geçersiz cevap alındı.',
      );
    }

    final elements = decoded['elements'];

    if (elements is! List || elements.isEmpty) {
      return const WaterSourceCheckResult(
        found: false,
        message:
            '100 metre çevrenizde uygun bir tatlı su kaynağı bulunamadı.',
      );
    }

    for (final element in elements) {
      if (element is! Map) {
        continue;
      }

      final rawTags = element['tags'];

      if (rawTags is! Map) {
        continue;
      }

      final tags =
          Map<String, dynamic>.from(rawTags);

      if (!_isAcceptedWaterSource(tags)) {
        continue;
      }

      final name = tags['name']?.toString();
      final type = _getWaterType(tags);

      return WaterSourceCheckResult(
        found: true,
        name: name,
        type: type,
        latitude: lat,
        longitude: lon,
        message:
            name != null && name.trim().isNotEmpty
                ? '$name yakınınızda bulundu.'
                : '100 metre içinde $type bulundu.',
      );
    }

    return const WaterSourceCheckResult(
      found: false,
      message:
          '100 metre çevrenizde uygun bir tatlı su kaynağı bulunamadı.',
    );
  }

  bool _isAcceptedWaterSource(
    Map<String, dynamic> tags,
  ) {
    final natural = tags['natural']?.toString();
    final waterway = tags['waterway']?.toString();
    final water = tags['water']?.toString();

    // Kesinlikle kabul etmek istemediğimiz yapay alanlar.
    const rejectedWaterTypes = {
      'swimming_pool',
      'wastewater',
      'sewage',
    };

    if (water != null &&
        rejectedWaterTypes.contains(water)) {
      return false;
    }

    // Doğal kaynak / pınar
    if (natural == 'spring') {
      return true;
    }

    // Dere veya nehir
    if (waterway == 'stream' ||
        waterway == 'river') {
      return true;
    }

    // Göl, gölet, rezervuar vb.
    if (natural == 'water') {
      return true;
    }

    return false;
  }

  String _getWaterType(
    Map<String, dynamic> tags,
  ) {
    final natural = tags['natural']?.toString();
    final waterway = tags['waterway']?.toString();
    final water = tags['water']?.toString();

    if (natural == 'spring') {
      return 'doğal su kaynağı';
    }

    if (waterway == 'stream') {
      return 'dere';
    }

    if (waterway == 'river') {
      return 'nehir';
    }

    switch (water) {
      case 'lake':
        return 'göl';

      case 'pond':
        return 'gölet';

      case 'reservoir':
        return 'rezervuar';

      case 'river':
        return 'nehir';

      default:
        return 'su kaynağı';
    }
  }
}