import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/gemini_vision_service.dart';
import '../../services/water_source_service.dart';
// Removed unused DB import
import '../../../../localization/app_localizations.dart';
import 'cleaned_spots_map_screen.dart';

class FinalMissionScreen extends StatefulWidget {
  const FinalMissionScreen({super.key});

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
                  _openWebCameraCapture(source);
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
                  _pickFromGallery(source);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Canlı Web Kamerası ile Çekim
  Future<void> _openWebCameraCapture(WaterSource source) async {
    if (!kIsWeb) {
      final ImagePicker picker = ImagePicker();
      final XFile? img = await picker.pickImage(source: ImageSource.camera);
      if (img != null) {
        final bytes = await img.readAsBytes();
        _processVerification(source, bytes);
      }
      return;
    }

    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {'facingMode': 'environment'},
        'audio': false,
      });

      if (stream == null) {
        _showErrorDialog("Kamera açılamadı veya erişim izni verilmedi.");
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) {
          final videoElement = html.VideoElement()
            ..srcObject = stream
            ..autoplay = true
            ..muted = true
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover';

          return Dialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 380,
              height: 480,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Kamera Önizleme",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          stream.getTracks().forEach((track) => track.stop());
                          Navigator.pop(dialogCtx);
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: HtmlElementView.fromTagName(
                        tagName: 'video',
                        onElementCreated: (element) {
                          final el = element as html.VideoElement;
                          el.srcObject = stream;
                          el.autoplay = true;
                          el.muted = true;
                          el.play();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: Text(
                        _isTr ? "Fotoğrafı Çek" : 'Capture Photo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final int sourceW = videoElement.videoWidth > 0
                            ? videoElement.videoWidth
                            : 640;
                        final int sourceH = videoElement.videoHeight > 0
                            ? videoElement.videoHeight
                            : 480;
                        final int targetW = sourceW > 720 ? 720 : sourceW;
                        final int targetH = (sourceH / sourceW * targetW)
                            .toInt();

                        final canvas = html.CanvasElement(
                          width: targetW,
                          height: targetH,
                        );
                        canvas.context2D.drawImageScaled(
                          videoElement,
                          0,
                          0,
                          targetW,
                          targetH,
                        );

                        final blob = await canvas.toBlob('image/jpeg', 0.75);
                        final reader = html.FileReader();
                        reader.readAsArrayBuffer(blob);
                        await reader.onLoadEnd.first;

                        final bytes = Uint8List.fromList(
                          reader.result as List<int>,
                        );

                        stream.getTracks().forEach((track) => track.stop());
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);

                        _processVerification(source, bytes);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      _showErrorDialog("Kamera başlatılamadı: $e");
    }
  }

  // Galeriden Seçim
  Future<void> _pickFromGallery(WaterSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 75,
    );

    if (image == null) return;
    final bytes = await image.readAsBytes();
    _processVerification(source, bytes);
  }

  // Gemini Doğrulaması
  Future<void> _processVerification(WaterSource source, Uint8List bytes) async {
    setState(() => _isVerifying = true);

    try {
      var result = await _geminiService.verifyCleanupPhoto(bytes);

      if (result.accepted) {
        final prefs = await SharedPreferences.getInstance();
        final nickname = prefs.getString('current_user_nickname') ?? 'Kahraman';

        if (mounted) setState(() => _isVerifying = false);
        if (mounted) _showSuccessDialog(source, nickname);
      } else {
        if (mounted) setState(() => _isVerifying = false);
        if (mounted) _showErrorDialog(result.reason);
      }
    } catch (e) {
      if (mounted) setState(() => _isVerifying = false);
      if (mounted) _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog(WaterSource source, String nickname) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 380),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: softBeige,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3EBD8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: primaryGreen,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isTr ? 'Tebrikler!' : 'Congratulations!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isTr
                        ? '${_getLocalizedSourceName(source.name)} başarıyla temizlendi!'
                        : '${_getLocalizedSourceName(source.name)} has been successfully cleaned!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(
                        _isTr
                            ? 'Temizliği Haritada İşaretle 🗺️'
                            : 'Mark on Map 🗺️',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CleanedSpotsMapScreen(
                              initialLat:
                                  _userPosition?.latitude ?? source.latitude,
                              initialLng:
                                  _userPosition?.longitude ?? source.longitude,
                              pendingSource: WaterSource(
                                id: source.id,
                                name: source.name,
                                latitude:
                                    _userPosition?.latitude ?? source.latitude,
                                longitude:
                                    _userPosition?.longitude ??
                                    source.longitude,
                              ),
                            ),
                          ),
                        );
                      },
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryGreen,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
