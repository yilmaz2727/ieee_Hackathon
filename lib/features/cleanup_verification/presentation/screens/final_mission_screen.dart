import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/guardian_rewards.dart';
import '../../data/services/gemini_vision_service.dart';
import '../../services/water_source_service.dart';
// Removed unused DB import
import '../../../../localization/app_localizations.dart';
import 'cleaned_spots_map_screen.dart';

class FinalMissionScreen extends StatefulWidget {
  const FinalMissionScreen({
    super.key,
    required this.beforeVerify,
    required this.onComplete,
  });

  final Future<void> Function() beforeVerify;
  final VoidCallback onComplete;

  @override
  State<FinalMissionScreen> createState() => _FinalMissionScreenState();
}

class _FinalMissionScreenState extends State<FinalMissionScreen> {
  final WaterSourceService _sourceService = WaterSourceService();
  final GeminiVisionService _geminiService = GeminiVisionService();

  List<WaterSource> _closestSources = [];
  Position? _userPosition;
  bool _isLoading = true;
  bool _isVerifying = false;
  bool get _isTr => AppLocalizations.instance.isTurkish;

  static const Color primaryGreen = Color(0xFF2C5E43);
  static const Color accentGreen = Color(0xFF4A8B63);
  static const Color softBeige = Color(0xFFF9F7EE);

  @override
  void initState() {
    super.initState();
    _determinePositionAndLoadSources();
  }

  Future<void> _determinePositionAndLoadSources() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 3));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 3),
        );
      }

      Position? position = await Geolocator.getLastKnownPosition().timeout(
        const Duration(seconds: 3),
      );
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 3));

      var sources = await _sourceService
          .getClosest3Sources(position)
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _userPosition = position;
          _closestSources = sources;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _closestSources = [
            WaterSource(
              id: 'dummy1',
              name: 'Kent Park Göleti',
              latitude: 39.9,
              longitude: 32.8,
            ),
            WaterSource(
              id: 'dummy2',
              name: 'Yeşil Vadi',
              latitude: 39.9,
              longitude: 32.8,
            ),
            WaterSource(
              id: 'dummy3',
              name: 'Mavi Göl',
              latitude: 39.9,
              longitude: 32.8,
            ),
          ];
          _isLoading = false;
        });
      }
    }
  }

  String _getLocalizedSourceName(String originalName) {
    if (originalName.contains('Mavi Göl')) {
      return _isTr ? 'Mavi Göl' : 'Mavi Göl (Blue Lake)';
    }
    if (originalName.contains('Kent Park')) {
      return _isTr ? 'Kent Park Göleti' : 'Kent Park Lake';
    }
    if (originalName.contains('Yeşil Vadi')) {
      return _isTr ? 'Yeşil Vadi' : 'Yesil Vadi (Green Valley)';
    }
    return originalName;
  }

  void _showPhotoSourceDialog(WaterSource source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: softBeige,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isTr ? 'Fotoğraf Kaynağı' : 'Photo Source',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: primaryGreen,
                ),
                title: Text(
                  _isTr ? 'Kamera' : 'Camera',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(source, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: primaryGreen,
                ),
                title: Text(
                  _isTr ? 'Galeri' : 'Gallery',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(source, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kamera veya galeriden fotoğraf seçimi (mobil uyumlu, image_picker).
  // Gemini'ye gitmeden önce 720 piksele küçültülür ve %75 kalitede sıkıştırılır.
  Future<void> _pickImage(WaterSource source, ImageSource imageSource) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image;
    try {
      image = await picker.pickImage(
        source: imageSource,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 75,
        preferredCameraDevice: CameraDevice.rear,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final isCamera = imageSource == ImageSource.camera;
      if (e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied') {
        _showErrorDialog(
          isCamera
              ? (_isTr
                    ? 'Kamera izni reddedildi. Görevi doğrulamak için cihaz ayarlarından kamera iznini açabilir veya galeriden fotoğraf seçebilirsin.'
                    : 'Camera permission was denied. Enable camera access in your device settings or pick a photo from the gallery.')
              : (_isTr
                    ? 'Galeri izni reddedildi. Lütfen cihaz ayarlarından fotoğraf erişimine izin ver.'
                    : 'Photo library permission was denied. Please allow photo access in your device settings.'),
        );
      } else {
        _showErrorDialog(
          isCamera
              ? (_isTr
                    ? 'Kamera açılamadı. Lütfen tekrar dene.'
                    : 'Could not open the camera. Please try again.')
              : (_isTr
                    ? 'Galeri açılamadı. Lütfen tekrar dene.'
                    : 'Could not open the gallery. Please try again.'),
        );
      }
      return;
    }

    if (image == null) return;
    final bytes = await image.readAsBytes();
    _processVerification(source, bytes);
  }

  // Gemini Doğrulaması
  Future<void> _processVerification(WaterSource source, Uint8List bytes) async {
    if (_isVerifying || !mounted) return;

    setState(() => _isVerifying = true);

    try {
      // Ana oyunun bekleyen puan kayıtları bitmeden AI işlemine geçme.
      await widget.beforeVerify();

      final result = await _geminiService.verifyCleanupPhoto(bytes);
      if (!mounted) return;

      if (!result.accepted) {
        _showErrorDialog(result.reason);
        return;
      }

      await GuardianRewards.recordApprovedRun(source.name);

      final prefs = await SharedPreferences.getInstance();
      final nickname = prefs.getString('current_user_nickname') ?? '';

      if (mounted) {
        _showSuccessDialog(source, nickname);
      }
    } catch (_) {
      if (mounted) {
        _showErrorDialog(
          _isTr
              ? 'Doğrulama veya kayıt tamamlanamadı. Lütfen tekrar dene.'
              : 'Verification or saving failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _showSuccessDialog(WaterSource source, String nickname) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: softBeige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(_isTr ? 'Görevin onaylandı!' : 'Mission approved!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/esma.png',
                height: 130,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                _isTr
                    ? 'Tebrikler $nickname! Fotoğrafın onaylandı ve '
                          'başarın kaydedildi. Şimdi görev yerini haritada işaretleyebilirsin.'
                    : 'Well done, $nickname! Your photo was approved and '
                          'your achievement was saved. You can now mark your mission on the map.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: Text(_isTr ? 'Haritaya geç' : 'Open map'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    // StoryScreen'i silme; haritayı onun üzerine aç.
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (mapContext) => CleanedSpotsMapScreen(
          initialLat: _userPosition?.latitude ?? source.latitude,
          initialLng: _userPosition?.longitude ?? source.longitude,
          pendingSource: WaterSource(
            id: source.id,
            name: source.name,
            latitude: _userPosition?.latitude ?? source.latitude,
            longitude: _userPosition?.longitude ?? source.longitude,
          ),
          onBack: () => Navigator.of(mapContext).pop(),
        ),
      ),
    );

    if (mounted) widget.onComplete();
  }

  void _showErrorDialog(String reason) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: softBeige,
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTr ? 'Bir Hata Oluştu' : 'An Error Occurred',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(reason, style: const TextStyle(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  _isTr ? 'Tekrar Dene' : 'Try Again',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBeige,
      appBar: AppBar(
        backgroundColor: softBeige,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          _isTr ? 'Gerçek Dünya Görevi' : 'Real-World Mission',
          style: const TextStyle(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  )
                : _isVerifying
                ? _buildVerifyingOverlay()
                : _buildMainContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyingOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: primaryGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              _isTr ? 'Doğrulanıyor...' : 'Verifying...',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isTr
                  ? 'Fotoğraf Yapay Zeka (Gemini) tarafından inceleniyor 🍃'
                  : 'Photo is being reviewed by AI (Gemini) 🍃',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE3EBD8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCCE0B8)),
          ),
          child: Row(
            children: [
              const Icon(Icons.eco_rounded, color: primaryGreen, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isTr
                      ? 'En yakın tatlı su kenarına git, atıkları topla ve haritada izin kalsın!'
                      : 'Go to the nearest freshwater spot, collect waste in a bag, and leave your mark on the map!',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: primaryGreen,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isTr
              ? 'EN YAKIN 3 TATLI SU KAYNAĞI'
              : 'TOP 3 NEAREST FRESHWATER SPOTS',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black45,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        ..._closestSources.map((source) => _buildSourceCard(source)),
      ],
    );
  }

  Widget _buildSourceCard(WaterSource source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLocalizedSourceName(source.name),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isTr ? 'Tatlı Su Kaynağı' : 'Freshwater Source',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(
                  _isTr ? 'Fotoğraf Çek ve Doğrula' : 'Take Photo & Verify',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => _showPhotoSourceDialog(source),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
