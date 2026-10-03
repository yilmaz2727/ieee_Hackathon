import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/water_source_service.dart';
import '../../services/local_database_service.dart';
import '../../../../localization/app_localizations.dart';
import 'leaderboard_screen.dart';

class CleanedSpotsMapScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final WaterSource? pendingSource;
  final VoidCallback? onBack;

  const CleanedSpotsMapScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.pendingSource,
    this.onBack,
  });

  @override
  State<CleanedSpotsMapScreen> createState() => _CleanedSpotsMapScreenState();
}

class _CleanedSpotsMapScreenState extends State<CleanedSpotsMapScreen> {
  List<Map<String, dynamic>> _spots = [];
  bool _isLoading = true;
  bool _isSaving = false;
  WaterSource? _activePendingSource;
  final MapController _mapController = MapController();

  LatLng _currentCenter = const LatLng(39.92077, 32.85411);
  static const Color primaryGreen = Color(0xFF2C5E43);

  bool get _isTr => AppLocalizations.instance.isTurkish;

  @override
  void initState() {
    super.initState();
    _activePendingSource = widget.pendingSource;
    _initMapCenterAndSpots();
  }

  Future<void> _initMapCenterAndSpots() async {
    final spots = await LocalDatabaseService.getAllCleanedSpots();

    // 1. Öncelik: Yeni temizlenen nokta
    if (widget.pendingSource != null) {
      _currentCenter = LatLng(
        widget.pendingSource!.latitude,
        widget.pendingSource!.longitude,
      );
    }
    // 2. Öncelik: Dışarıdan verilen koordinat
    else if (widget.initialLat != null && widget.initialLng != null) {
      _currentCenter = LatLng(widget.initialLat!, widget.initialLng!);
    }
    // 3. Öncelik: Veritabanındaki en son temizlenmiş noktanın koordinatı
    else if (spots.isNotEmpty) {
      final lastSpot = spots.last;
      _currentCenter = LatLng(
        (lastSpot['latitude'] as num).toDouble(),
        (lastSpot['longitude'] as num).toDouble(),
      );
    }
    // 4. Öncelik: Canlı GPS konumu
    else {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          _currentCenter = LatLng(pos.latitude, pos.longitude);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _spots = spots;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_currentCenter, 14);
      });
    }
  }

  Future<void> _loadSpots() async {
    final spots = await LocalDatabaseService.getAllCleanedSpots();
    if (mounted) {
      setState(() {
        _spots = spots;
      });
    }
  }

  void _showEntry(Map<String, dynamic> e) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFFF9F7EE),
        title: Text(
          e['water_source_name'].toString(),
          style: const TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.green, size: 64),
              const SizedBox(height: 10),
              Text(
                _isTr ? "Doğrulandı" : "Verified",
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_isTr ? "Temizleyen:" : "Cleaned by:"} 👤 ${e['user_nickname']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${e['points_earned']} ${_isTr ? "Puan" : "Points"}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              _isTr ? "Tamam" : "OK",
              style: const TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmSpot() async {
    if (_activePendingSource == null) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = await LocalDatabaseService.getCurrentUser();

      // Fotoğraf doğrulamasından kazanılan gerçek bonus
      const int photoBonus = 20;

      await prefs.setBool('ai_photo_verified', true);

      // Mevcut GERÇEK toplam puan
      final int currentTotal =
          prefs.getInt('total_score') ??
          (currentUser?['total_score'] as int? ?? 0);

      // Sadece +20 ekle
      final int finalGameScore = currentTotal + photoBonus;

      // Bonus ayrıca saklansın
      final int currentBonus = prefs.getInt('bonus_score') ?? 0;
      await prefs.setInt('bonus_score', currentBonus + photoBonus);

      // Gerçek temizlenen kaynak
      await prefs.setString('cleaned_source_name', _activePendingSource!.name);

      // Haritadaki nokta sadece BU işlemde kazanılan puanı göstermeli.
      // Buraya finalGameScore VERME!
      await LocalDatabaseService.saveCleanedSpot(
        waterSourceName: _activePendingSource!.name,
        latitude: _activePendingSource!.latitude,
        longitude: _activePendingSource!.longitude,
        earnedPoints: photoBonus,
      );

      // Liderlik tablosundaki toplam puanı gerçek değerle eşitle
      await LocalDatabaseService.setTotalScore(finalGameScore);

      await _loadSpots();

      if (!mounted) return;

      setState(() {
        _activePendingSource = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isTr
                ? 'Nokta haritaya eklendi! Toplam Skorun: $finalGameScore 🌟'
                : 'Spot marked on map! Total Score: $finalGameScore 🌟',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF242F28),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF9F7EE),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  AppBar(
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: primaryGreen,
                        size: 20,
                      ),
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                    ),
                    title: Text(
                      _isTr
                          ? "Topluluk Temizlikleri (${_spots.length})"
                          : "Community Cleanups (${_spots.length})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        fontSize: 16,
                      ),
                    ),
                    centerTitle: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    iconTheme: const IconThemeData(color: primaryGreen),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: _currentCenter,
                                    initialZoom: 14,
                                    minZoom: 3,
                                    maxZoom: 18,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      // subdomains: const ['a', 'b', 'c', 'd'],
                                      userAgentPackageName:
                                          'com.esma.suyunkoruyucusu',
                                      maxZoom: 19,
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        for (final e in _spots)
                                          Marker(
                                            point: LatLng(
                                              (e['latitude'] as num).toDouble(),
                                              (e['longitude'] as num)
                                                  .toDouble(),
                                            ),
                                            width: 80,
                                            height: 60,
                                            alignment: const Alignment(0, -1),
                                            child: GestureDetector(
                                              onTap: () => _showEntry(e),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.95,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.2,
                                                                ),
                                                            blurRadius: 2,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        "👤 ${e['user_nickname']}",
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.park_rounded,
                                                    size: 34,
                                                    color: Colors.green,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (_activePendingSource != null)
                                          Marker(
                                            point: LatLng(
                                              _activePendingSource!.latitude,
                                              _activePendingSource!.longitude,
                                            ),
                                            width: 80,
                                            height: 60,
                                            alignment: const Alignment(0, -1),
                                            child: const Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 40,
                                                  color: Colors.blue,
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (_activePendingSource != null)
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      icon: _isSaving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.check_circle_rounded,
                                              size: 20,
                                            ),
                                      label: Text(
                                        _isSaving
                                            ? (_isTr
                                                  ? 'Kaydediliyor...'
                                                  : 'Saving...')
                                            : (_isTr
                                                  ? 'Bu Noktayı Temizlediğimi Onayla'
                                                  : 'Confirm I Cleaned This Spot'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: _isSaving
                                          ? null
                                          : _handleConfirmSpot,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.leaderboard_rounded,
                                        size: 20,
                                      ),
                                      label: Text(
                                        _isTr
                                            ? 'Liderlik Tablosunu Gör'
                                            : 'View Leaderboard',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const LeaderboardScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () => launchUrl(
                                      Uri.parse(
                                        'https://www.openstreetmap.org/copyright',
                                      ),
                                    ),
                                    child: const Text(
                                      '© OpenStreetMap contributors',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
