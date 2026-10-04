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

Position? _userPosition;
WaterSource? _verifiedSource;


bool _isCheckingLocation = false;
bool _isLocationVerified = false;
bool _isVerifying = false;
bool _isSkipping = false;

String? _locationMessage;

  bool get _isTr => AppLocalizations.instance.isTurkish;

  static const Color primaryGreen = Color(0xFF2C5E43);
  static const Color accentGreen = Color(0xFF4A8B63);
  static const Color softBeige = Color(0xFFF9F7EE);

@override
void initState() {
  super.initState();
}
  Future<void> _continueWithoutPhoto() async {
    if (_isVerifying || _isSkipping) return;

    setState(() => _isSkipping = true);

    try {
      final skip = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: softBeige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(Icons.eco_rounded, color: primaryGreen, size: 44),
          title: Text(
            _isTr
                ? 'Fotoğraf eklemeden devam edilsin mi?'
                : 'Continue without a photo?',
            textAlign: TextAlign.center,
          ),
          content: Text(
            _isTr
                ? 'Temizlik görevini fotoğrafla paylaşır ve fotoğrafın '
                      'onaylanırsa 100 ek puan kazanabilirsin! '
                      'Doğa için attığın bu adım başkalarına da ilham verebilir.\n\n'
                      'Fotoğraf eklemek zorunlu değil. İstersen mevcut '
                      'puanlarınla sertifikanı alabilirsin.'
                : 'Share a photo of your cleanup and earn 100 bonus '
                      'points when it is approved! Your action for nature '
                      'can inspire others too.\n\n'
                      'Adding a photo is optional. You can receive your '
                      'certificate with your existing points.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _isTr ? 'Fotoğrafsız devam et' : 'Continue without a photo',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accentGreen),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_isTr ? 'Fotoğraf ekle' : 'Add a photo'),
            ),
          ],
        ),
      );

      if (!mounted || skip != true) return;

      // Önce bölüm puanlarını ve oyunun tamamlanma bilgisini kaydet.
      await widget.beforeVerify();

      if (!mounted) return;

      // Fotoğraf bonusu vermeden sertifika kaydını oluştur.
      await GuardianRewards.recordWithoutPhoto();

      if (!mounted) return;

      // Mevcut bağlantı sertifika/rozet ekranına götürüyor.
      widget.onComplete();
    } catch (_) {
      if (mounted) {
        _showErrorDialog(
          _isTr
              ? 'Oyun sonucun kaydedilemedi. Lütfen tekrar dene.'
              : 'Could not save your game result. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSkipping = false);
      }
    }
  }
Future<void> _verifyCurrentLocation() async {
  if (_isCheckingLocation || _isVerifying || _isSkipping) {
    return;
  }

  setState(() {
    _isCheckingLocation = true;
    _isLocationVerified = false;
    _verifiedSource = null;
    _locationMessage = _isTr
        ? 'Anlık konumunuz alınıyor...'
        : 'Getting your current location...';
  });

  try {
    final position = await _sourceService.getCurrentPosition();

    if (!mounted) return;

    setState(() {
      _userPosition = position;

      _locationMessage = _isTr
          ? 'Konum alındı. 100 metre çevrede su kaynağı aranıyor...'
          : 'Location found. Searching for a water source within 100 meters...';
    });

    final result =
        await _sourceService.checkNearbyWaterSource(position);

    if (!mounted) return;

    // 100 metre içinde uygun su kaynağı bulunamadı.
    if (!result.found) {
      setState(() {
        _isLocationVerified = false;
        _verifiedSource = null;

        _locationMessage = _isTr
            ? '100 metre çevrenizde uygun bir tatlı su kaynağı '
                'OpenStreetMap verisinde doğrulanamadı.'
            : 'No suitable freshwater source could be verified '
                'within 100 meters using OpenStreetMap data.';
      });

      return;
    }

    // Kaynağın ismini belirle.
    final sourceName =
        result.name?.trim().isNotEmpty == true
            ? result.name!.trim()
            : (result.type?.trim().isNotEmpty == true
                ? result.type!.trim()
                : (_isTr
                    ? 'Yakındaki Tatlı Su Kaynağı'
                    : 'Nearby Freshwater Source'));

    // Temizlik noktası olarak kullanacağımız kaynak.
    final source = WaterSource(
      id: 'gps_${DateTime.now().millisecondsSinceEpoch}',
      name: sourceName,
      latitude: position.latitude,
      longitude: position.longitude,
      description: result.message,
    );

    setState(() {
      _verifiedSource = source;
      _isLocationVerified = true;

      _locationMessage = _isTr
          ? 'Konum doğrulandı. 100 metre içinde uygun bir '
              'tatlı su kaynağı bulundu.'
          : 'Location verified. A suitable freshwater source '
              'was found within 100 meters.';
    });
  } on LocationAccuracyException catch (e) {
    // GPS var ancak 100 metrelik kontrol için yeterince hassas değil.
    if (!mounted) return;

    setState(() {
      _isLocationVerified = false;
      _verifiedSource = null;

      _locationMessage = _isTr
          ? 'GPS doğruluğu yeterli değil '
              '(${e.accuracy.toStringAsFixed(0)} m). '
              'Lütfen açık bir alanda tekrar deneyin.'
          : 'GPS accuracy is not sufficient '
              '(${e.accuracy.toStringAsFixed(0)} m). '
              'Please try again in an open area.';
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isLocationVerified = false;
      _verifiedSource = null;

      _locationMessage = _isTr
          ? 'Konum doğrulanamadı. '
              'Lütfen konum ve internet bağlantınızı kontrol edip tekrar deneyin.'
          : 'Location could not be verified. '
              'Please check your location and internet connection and try again.';
    });
  } finally {
    if (mounted) {
      setState(() {
        _isCheckingLocation = false;
      });
    }
  }
}
  void _showPhotoSourceDialog(WaterSource source) {
      if (_isVerifying ||
      _isSkipping ||
      !_isLocationVerified ||
      _verifiedSource == null) {
    return;
  }
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
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
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
            child: _isVerifying
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
    padding: const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 10,
    ),
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3EBD8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFCCE0B8),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.eco_rounded,
              color: primaryGreen,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isTr
                    ? 'Tatlı su kaynağının yakınındaysan konumunu doğrula, '
                        'çevredeki atıkları topla ve fotoğrafını paylaş!'
                    : 'If you are near a freshwater source, verify your '
                        'location, collect nearby waste and share your photo!',
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
            ? 'KONUM DOĞRULAMA'
            : 'LOCATION VERIFICATION',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black45,
          letterSpacing: 1.1,
        ),
      ),

      const SizedBox(height: 12),

      _buildLocationCard(),

      const SizedBox(height: 12),

      Text(
        _isTr
            ? 'Onaylanan temizlik fotoğrafı: +100 puan'
            : 'Approved cleanup photo: +100 points',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),

      const SizedBox(height: 14),

      OutlinedButton.icon(
        onPressed: _isSkipping || _isVerifying
            ? null
            : _continueWithoutPhoto,
        icon: _isSkipping
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.arrow_forward_rounded,
              ),
        label: Text(
          _isTr
              ? 'Fotoğraf eklemeden devam et'
              : 'Continue without a photo',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(
            color: primaryGreen,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      const SizedBox(height: 20),
    ],
  );
}
 Widget _buildLocationCard() {
  final source = _verifiedSource;

  return Container(
    padding: const EdgeInsets.all(18),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isLocationVerified
                    ? const Color(0xFFE3F3E8)
                    : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _isLocationVerified
                    ? Icons.verified_rounded
                    : Icons.my_location_rounded,
                color: _isLocationVerified
                    ? accentGreen
                    : Colors.blueAccent,
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLocationVerified
                        ? (_isTr
                            ? 'Konum Doğrulandı'
                            : 'Location Verified')
                        : (_isTr
                            ? 'Mevcut Konum'
                            : 'Current Location'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                    ),
                  ),

                  if (_userPosition != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _isTr
                          ? 'GPS doğruluğu: '
                              '${_userPosition!.accuracy.toStringAsFixed(0)} m'
                          : 'GPS accuracy: '
                              '${_userPosition!.accuracy.toStringAsFixed(0)} m',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        if (_locationMessage != null) ...[
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isLocationVerified
                  ? const Color(0xFFF0F7F2)
                  : const Color(0xFFFFF6E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _locationMessage!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: _isLocationVerified
                    ? primaryGreen
                    : const Color(0xFF8A5A00),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        if (source != null) ...[
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.water_drop_rounded,
                color: Colors.blueAccent,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  source.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLocationVerified
                  ? accentGreen
                  : primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isCheckingLocation
                ? null
                : _verifyCurrentLocation,
            icon: _isCheckingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isLocationVerified
                        ? Icons.refresh_rounded
                        : Icons.my_location_rounded,
                    size: 19,
                  ),
            label: Text(
              _isCheckingLocation
                  ? (_isTr
                      ? 'Konum Kontrol Ediliyor...'
                      : 'Checking Location...')
                  : _isLocationVerified
                      ? (_isTr
                          ? 'Konumu Tekrar Kontrol Et'
                          : 'Check Location Again')
                      : (_isTr
                          ? 'Anlık Konumumu Doğrula'
                          : 'Verify My Current Location'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),

        if (_isLocationVerified &&
            source != null) ...[
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.camera_alt_outlined,
                size: 19,
              ),
              label: Text(
                _isTr
                    ? 'Fotoğraf Çek ve Doğrula'
                    : 'Take Photo & Verify',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: () =>
                  _showPhotoSourceDialog(source),
            ),
          ),
        ],
      ],
    ),
  );
}
}
