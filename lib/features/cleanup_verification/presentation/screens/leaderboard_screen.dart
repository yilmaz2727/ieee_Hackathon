import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/local_database_service.dart';
import '../../../../localization/app_localizations.dart';
import '../../../../services/certificate.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  String _currentNickname = '';
  int _userScore = 0;

  static const Color primaryGreen = Color(0xFF2C5E43);
  static const Color softBeige = Color(0xFFF9F7EE);

  bool get _isTr => AppLocalizations.instance.isTurkish;

  @override
  void initState() {
    super.initState();
    _syncAndLoadLeaderboard();
  }

  Future<void> _syncAndLoadLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentNickname = prefs.getString('current_user_nickname') ?? 'Kahraman';
      _userScore = prefs.getInt('total_score') ?? 0;

      // LocalDatabaseService'deki güncel tabloyu doğrudan oku
      List<Map<String, dynamic>> list =
          await LocalDatabaseService.getLeaderboard();

      final currentUserId = prefs.getString('current_user_id');

      // Kullanıcının kendi satırını listede canlı skor ile eşitle
      list = list.map((item) {
        final mutableItem = Map<String, dynamic>.from(item);
        final isMe =
            (currentUserId != null && mutableItem['id'] == currentUserId) ||
            mutableItem['nickname'] == _currentNickname;

        if (isMe && _userScore > (mutableItem['total_score'] as int? ?? 0)) {
          mutableItem['total_score'] = _userScore;
        }
        return mutableItem;
      }).toList();

      list.sort(
        (a, b) => (b['total_score'] as int? ?? 0).compareTo(
          a['total_score'] as int? ?? 0,
        ),
      );

      if (mounted) {
        setState(() {
          _leaderboard = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadCertificate() async {
    setState(() => _isDownloading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final nickname = _currentNickname.isNotEmpty
          ? _currentNickname
          : 'Kahraman';
      final savedTotal = prefs.getInt('total_score') ?? 0;
      final effectiveTotal = _userScore > savedTotal ? _userScore : savedTotal;

      await CertificateService.download(
        nickname,
        DateTime.now(),
        languageCode: _isTr ? 'tr' : 'en',
        totalScore: effectiveTotal > 0 ? effectiveTotal : 0,
        trashCollected: prefs.getInt('cleanup_count') ?? 0,
        protectedFish: prefs.getInt('fish_saved') ?? 0,
        quizScore: prefs.getInt('quiz_score') ?? 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isTr
                  ? 'Sertifikanız başarıyla indirildi! 📜'
                  : 'Certificate downloaded! 📜',
            ),
            backgroundColor: primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF242F28), // Mobil uygulama arka planı
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: softBeige,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // APPBAR
                  AppBar(
                    title: Text(
                      _isTr ? "Liderlik Tablosu 🏆" : "Leaderboard 🏆",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        fontSize: 18,
                      ),
                    ),
                    centerTitle: true,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: primaryGreen,
                        size: 20,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),

                  // LİSTE ALANI
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
                          )
                        : _leaderboard.isEmpty
                        ? Center(
                            child: Text(
                              _isTr
                                  ? "Henüz kayıtlı temizlik yok."
                                  : "No records yet.",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            itemCount: _leaderboard.length,
                            itemBuilder: (context, index) {
                              final user = _leaderboard[index];
                              final nick =
                                  (user['nickname'] as String? ?? 'Kahraman')
                                      .trim();
                              final score = (user['total_score'] as int?) ?? 0;
                              final isMe =
                                  _currentNickname.isNotEmpty &&
                                  nick.toLowerCase() ==
                                      _currentNickname.toLowerCase();

                              Color rankBadgeColor;
                              if (index == 0) {
                                rankBadgeColor = const Color(
                                  0xFFF59E0B,
                                ); // Altın
                              } else if (index == 1) {
                                rankBadgeColor = const Color(
                                  0xFF94A3B8,
                                ); // Gümüş
                              } else if (index == 2) {
                                rankBadgeColor = const Color(
                                  0xFFD97706,
                                ); // Bronz
                              } else {
                                rankBadgeColor = primaryGreen;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFFE8F5E9)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isMe
                                        ? primaryGreen
                                        : const Color(0xFFE2E8F0),
                                    width: isMe ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: rankBadgeColor,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.person_pin_rounded,
                                      color: primaryGreen,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        nick +
                                            (isMe
                                                ? (_isTr ? ' (Sen)' : ' (You)')
                                                : ''),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isMe
                                              ? primaryGreen
                                              : const Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$score ${_isTr ? "Puan" : "Pts"}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // ALT AKSİYON PANELİ (MOBİL UYUMLU VE SERTİFİKA BUTONLU)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // SERTİFİKA İNDİR BUTONU
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.card_membership_rounded,
                                    size: 20,
                                  ),
                            label: Text(
                              _isDownloading
                                  ? (_isTr ? 'Hazırlanıyor...' : 'Preparing...')
                                  : (_isTr
                                        ? 'Sertifikamı İndir 📜'
                                        : 'Download Certificate 📜'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            onPressed: _isDownloading
                                ? null
                                : _downloadCertificate,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ANA MENÜYE DÖN BUTONU
                        // ANA MENÜYE DÖN BUTONU
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.home_rounded, size: 18),
                            label: Text(
                              _isTr ? 'Ana Menüye Dön' : 'Back to Main Menu',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () {
                              // Yığın boşsa veya pushReplacement ile gelinmişse doğrudan kök sayfaya yönlendir
                              Navigator.of(
                                context,
                              ).pushNamedAndRemoveUntil('/', (route) => false);
                            },
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
