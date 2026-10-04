import 'package:geolocator/geolocator.dart';
import 'local_database_service.dart';

class WaterSource {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isCleaned;
  final String? cleanedBy;
  final String? cleanedAt;

  WaterSource({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.isCleaned = false,
    this.cleanedBy,
    this.cleanedAt,
  });

  // Veritabanından gelen temizlik kaydını WaterSource nesnesine dönüştürme
  factory WaterSource.fromCleanedSpot(Map<String, dynamic> json) {
    return WaterSource(
      id: json['id']?.toString() ?? '',
      name: json['water_source_name']?.toString() ?? 'Temizlenen Nokta',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      isCleaned: true,
      cleanedBy: json['user_nickname']?.toString() ?? 'Bir Kahraman',
      cleanedAt: json['cleaned_at']?.toString(),
    );
  }
}

class WaterSourceService {
  // Sabit temel tatlı su kaynakları
  final List<WaterSource> _defaultSources = [
    WaterSource(id: '1', name: 'Kent Park Göleti', latitude: 40.78, longitude: 30.39),
    WaterSource(id: '2', name: 'Yeşil Vadi Dere Kenarı', latitude: 40.79, longitude: 30.40),
    WaterSource(id: '3', name: 'Mavi Göl Piknik Alanı', latitude: 40.75, longitude: 30.35),
    WaterSource(id: '4', name: 'Yayla Pınarı', latitude: 40.82, longitude: 30.45),
  ];

  // Hem temel kaynakları hem de oyuncuların veritabanına eklediği temizlenmiş yerleri birleşik çeker
  Future<List<WaterSource>> getAllSourcesWithCleanups() async {
    List<WaterSource> combined = List.from(_defaultSources);

    try {
      // Veritabanındaki tüm temizlenmiş noktaları çek
      final cleanedRecords = await LocalDatabaseService.getAllCleanedSpots();
      
      for (var spot in cleanedRecords) {
        final spotSource = WaterSource.fromCleanedSpot(spot);
        
        // Eğer sabit bir kaynağın adı ile eşleşiyorsa o kaynağı "temizlendi" yap
        final index = combined.indexWhere((s) => s.name.toLowerCase() == spotSource.name.toLowerCase());
        if (index != -1) {
          combined[index] = WaterSource(
            id: combined[index].id,
            name: combined[index].name,
            latitude: combined[index].latitude,
            longitude: combined[index].longitude,
            isCleaned: true,
            cleanedBy: spotSource.cleanedBy,
            cleanedAt: spotSource.cleanedAt,
          );
        } else {
          // Yeni özel bir noktaysa listeye ekle
          combined.add(spotSource);
        }
      }
    } catch (_) {}

    return combined;
  }

  // Kullanıcının konumuna en yakın 3 kaynağı bulan metod
  Future<List<WaterSource>> getClosest3Sources(Position? userPosition) async {
    final allSources = await getAllSourcesWithCleanups();

    if (userPosition == null) {
      return allSources.take(3).toList();
    }

    allSources.sort((a, b) {
      double distA = _quickDistance(userPosition.latitude, userPosition.longitude, a.latitude, a.longitude);
      double distB = _quickDistance(userPosition.latitude, userPosition.longitude, b.latitude, b.longitude);
      return distA.compareTo(distB);
    });

    return allSources.take(3).toList();
  }
}

double _quickDistance(double lat1, double lon1, double lat2, double lon2) {
  final double latDiff = lat2 - lat1;
  final double lonDiff = lon2 - lon1;
  return latDiff * latDiff + lonDiff * lonDiff;
}