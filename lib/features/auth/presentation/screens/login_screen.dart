import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../cleanup_verification/services/local_database_service.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefs});
  final SharedPreferences? prefs;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();

  String _selectedCountry = 'Türkiye';
  String _selectedGender = 'female';
  bool _isLoading = false;

  bool get _isTr => AppLocalizations.instance.isTurkish;

  List<String> get _countries => _isTr
      ? const [
          'Türkiye',
          'Azerbaycan',
          'Almanya',
          'İngiltere',
          'Amerika',
          'Fransa',
          'Diğer',
        ]
      : const [
          'Turkey',
          'Azerbaijan',
          'Germany',
          'United Kingdom',
          'United States',
          'France',
          'Other',
        ];

  @override
  void initState() {
    super.initState();
    _selectedCountry = _isTr ? 'Türkiye' : 'Turkey';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final nickname = _nicknameController.text.trim();
      final age = int.tryParse(_ageController.text.trim()) ?? 10;
      final prefs = widget.prefs ?? await SharedPreferences.getInstance();
      final userId = DateTime.now().millisecondsSinceEpoch.toString();

      await prefs.setString('current_user_id', userId);
      await prefs.setString('current_user_nickname', nickname);
      await prefs.setInt('current_user_age', age);
      await prefs.setString('current_user_gender', _selectedGender);
      await prefs.setString('current_user_country', _selectedCountry);

      await LocalDatabaseService.registerUser(
        nickname: nickname,
        age: age,
        country: _selectedCountry,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StoryScreen(prefs: prefs)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTr
                  ? 'Bilgiler kaydedilirken bir hata oluştu.'
                  : 'An error occurred while saving.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_countries.contains(_selectedCountry)) {
      _selectedCountry = _countries.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFCBE8FA),
      body: Center(
        // Web'de de çalışsa dikey telefon oranlarını koruyan kapsayıcı
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // 1. NEHİRLİ DOĞA VE MANZARA ARKA PLANI
              Positioned.fill(
                child: CustomPaint(painter: RiverLandscapePainter()),
              ),

              // 2. SAĞ ÜST KÖŞE: DİL SEÇİM BUTONU (TR / EN)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final newCode = _isTr ? 'en' : 'tr';
                          await AppLocalizations.instance.setLanguage(
                            newCode,
                            prefs: widget.prefs,
                          );
                          if (!mounted) return;
                          setState(() {
                            _selectedCountry = _isTr ? 'Türkiye' : 'Turkey';
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.language_rounded,
                                size: 16,
                                color: Color(0xFF2C5E43),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isTr ? "TR 🇹🇷" : "EN 🇬🇧",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C5E43),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. MOBİL UYUMLU KAYDIRILABİLİR GİRİŞ KARTI
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Başlık Rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1E3A2F,
                                ).withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isTr ? "Esma'nın Yolculuğu" : "Esma's Journey",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF234B38),
                                ),
                              ),
                              Text(
                                _isTr
                                    ? "Suyun Koruyucusu Görevi"
                                    : "Guardian of Water Mission",
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF388E3C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Form Kutusu
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isTr
                                      ? "Maceraya Başla! 🌊"
                                      : "Start Adventure! 🌊",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B382B),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Oyuncu Adı
                                TextFormField(
                                  controller: _nicknameController,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF1F6F3),
                                    labelText: _isTr
                                        ? "Oyuncu Adın / Nickname"
                                        : "Player Name / Nickname",
                                    labelStyle: const TextStyle(fontSize: 12.5),
                                    prefixIcon: const Icon(
                                      Icons.person_rounded,
                                      color: Color(0xFF2C5E43),
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? (_isTr
                                            ? "Lütfen bir ad yazın"
                                            : "Please enter a name")
                                      : null,
                                ),
                                const SizedBox(height: 10),

                                // Yaş Alanı
                                TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  style: const TextStyle(fontSize: 13.5),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF1F6F3),
                                    labelText: _isTr ? "Yaşın" : "Age",
                                    labelStyle: const TextStyle(fontSize: 12.5),
                                    prefixIcon: const Icon(
                                      Icons.cake_rounded,
                                      color: Color(0xFF2C5E43),
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return _isTr
                                          ? "Lütfen yaşınızı girin"
                                          : "Please enter age";
                                    }
                                    final num = int.tryParse(v.trim());
                                    if (num == null || num <= 3 || num > 99) {
                                      return _isTr
                                          ? "Geçerli bir yaş girin"
                                          : "Enter a valid age";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Ülke Dropdown (initialValue ile güncellendi)
                                DropdownButtonFormField<String>(
                                  key: ValueKey(_selectedCountry),
                                  initialValue: _selectedCountry,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF1F6F3),
                                    labelText: _isTr ? "Ülken" : "Country",
                                    labelStyle: const TextStyle(fontSize: 12.5),
                                    prefixIcon: const Icon(
                                      Icons.public_rounded,
                                      color: Color(0xFF2C5E43),
                                      size: 20,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _countries.map((c) {
                                    return DropdownMenuItem<String>(
                                      value: c,
                                      child: Text(c),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedCountry = val);
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Karakter / Cinsiyet
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _isTr
                                        ? "Karakter / Cinsiyet:"
                                        : "Character / Gender:",
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C5E43),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildGenderCard(
                                        id: 'female',
                                        label: _isTr ? "Kız 👧" : "Girl 👧",
                                        selected: _selectedGender == 'female',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _buildGenderCard(
                                        id: 'male',
                                        label: _isTr ? "Erkek 👦" : "Boy 👦",
                                        selected: _selectedGender == 'male',
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _buildGenderCard(
                                        id: 'other',
                                        label: _isTr ? "Diğer ⭐" : "Other ⭐",
                                        selected: _selectedGender == 'other',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Kaydet Butonu
                                SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0288D1),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _handleSave,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Text(
                                            _isTr ? "KAYDET" : "SAVE",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard({
    required String id,
    required String label,
    required bool selected,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedGender = id),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0F2FE) : const Color(0xFFF1F6F3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF0288D1) : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              color: selected ? const Color(0xFF0288D1) : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nehir ve doğa manzarasını çizen CustomPainter
class RiverLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gökyüzü Gradyanı
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFBCE3F9), Color(0xFFEAF5FC)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Bulutlar
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    _drawCloud(canvas, cloudPaint, w * 0.2, h * 0.12, 45);
    _drawCloud(canvas, cloudPaint, w * 0.75, h * 0.16, 55);
    _drawCloud(canvas, cloudPaint, w * 0.45, h * 0.22, 35);

    // Uzak Açık Yeşil Tepeler
    final distantHillPaint = Paint()..color = const Color(0xFF81C784);
    final distantPath = Path()
      ..moveTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.3, h * 0.50, w * 0.6, h * 0.56)
      ..quadraticBezierTo(w * 0.85, h * 0.62, w, h * 0.54)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(distantPath, distantHillPaint);

    // Orta Yeşil Tepeler
    final midHillPaint = Paint()..color = const Color(0xFF4CAF50);
    final midPath = Path()
      ..moveTo(0, h * 0.68)
      ..quadraticBezierTo(w * 0.35, h * 0.60, w * 0.7, h * 0.67)
      ..quadraticBezierTo(w * 0.9, h * 0.71, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(midPath, midHillPaint);

    // Ön Yeşil Zemin
    final foreHillPaint = Paint()..color = const Color(0xFF388E3C);
    final forePath = Path()
      ..moveTo(0, h * 0.76)
      ..quadraticBezierTo(w * 0.25, h * 0.72, w * 0.5, h * 0.78)
      ..quadraticBezierTo(w * 0.8, h * 0.84, w, h * 0.75)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(forePath, foreHillPaint);

    // Kıvrımlı Mavi Nehir
    final riverPaint = Paint()..color = const Color(0xFF29B6F6);
    final riverPath = Path()
      ..moveTo(w * 0.52, h * 0.62)
      ..cubicTo(w * 0.44, h * 0.68, w * 0.60, h * 0.78, w * 0.38, h * 0.88)
      ..cubicTo(w * 0.28, h * 0.93, w * 0.20, h * 0.96, w * 0.15, h)
      ..lineTo(w * 0.48, h)
      ..cubicTo(w * 0.52, h * 0.95, w * 0.58, h * 0.91, w * 0.66, h * 0.86)
      ..cubicTo(w * 0.82, h * 0.77, w * 0.64, h * 0.68, w * 0.56, h * 0.62)
      ..close();
    canvas.drawPath(riverPath, riverPaint);

    // Dalgalar
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.36, h * 0.80, 40, 20),
      0.2,
      2.2,
      false,
      wavePaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.28, h * 0.91, 55, 25),
      0.2,
      2.0,
      false,
      wavePaint,
    );

    // Ağaçlar
    _drawTree(canvas, w * 0.12, h * 0.72, 28);
    _drawTree(canvas, w * 0.88, h * 0.70, 32);
    _drawTree(canvas, w * 0.95, h * 0.74, 24);
  }

  void _drawCloud(
    Canvas canvas,
    Paint paint,
    double cx,
    double cy,
    double radius,
  ) {
    canvas.drawCircle(Offset(cx, cy), radius, paint);
    canvas.drawCircle(
      Offset(cx - radius * 0.6, cy + radius * 0.15),
      radius * 0.65,
      paint,
    );
    canvas.drawCircle(
      Offset(cx + radius * 0.6, cy + radius * 0.15),
      radius * 0.65,
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + radius * 0.3),
          width: radius * 2.2,
          height: radius * 0.7,
        ),
        Radius.circular(radius * 0.35),
      ),
      paint,
    );
  }

  void _drawTree(Canvas canvas, double x, double y, double size) {
    final trunkPaint = Paint()..color = const Color(0xFF6D4C41);
    canvas.drawRect(
      Rect.fromLTWH(x - size * 0.1, y, size * 0.2, size * 0.6),
      trunkPaint,
    );

    final foliagePaint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y - size * 0.1),
        width: size * 1.1,
        height: size * 1.5,
      ),
      foliagePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
