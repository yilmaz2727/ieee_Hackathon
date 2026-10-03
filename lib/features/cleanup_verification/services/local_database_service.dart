import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Web ortamında doğrudan ve kalıcı localStorage erişimi
import 'package:universal_html/html.dart' as html;

class LocalDatabaseService {
  static const String _usersTableKey = 'APP_DB_USERS_TABLE_V6';
  static const String _cleanupsTableKey = 'APP_DB_CLEANUPS_TABLE_V6';
  static const String _activeUserKey = 'APP_DB_ACTIVE_USER_ID_V6';

  // --- ÇİFT KATMANLI DİSK ERİŞİMİ (WEB & MOBİL SENKRONİZASYONU) ---
  static Future<void> _writeToDisk(String key, String value) async {
    try {
      if (kIsWeb) {
        html.window.localStorage[key] = value;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('Disk yazma hatası ($key): $e');
    }
  }

  static Future<String?> _readFromDisk(String key) async {
    try {
      if (kIsWeb) {
        final val = html.window.localStorage[key];
        if (val != null && val.isNotEmpty) return val;
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      debugPrint('Disk okuma hatası ($key): $e');
      return null;
    }
  }

  // --- 1. EŞSİZ NICKNAME KONTROLÜ ---
  static Future<bool> isNicknameTaken(String nickname) async {
    final cleanNick = nickname.trim().toLowerCase();
    if (cleanNick.isEmpty) return false;
    final users = await getAllUsers();
    return users.any(
      (u) => (u['nickname'] as String? ?? '').trim().toLowerCase() == cleanNick,
    );
  }

  // --- 2. KULLANICI KAYDI (EŞSİZLİK & SERTİFİKA ALANLARI) ---
  static Future<Map<String, dynamic>> registerUser({
    required String nickname,
    required int age,
    required String country,
  }) async {
    final cleanNick = nickname.trim();
    if (cleanNick.isEmpty) {
      throw Exception("Kullanıcı adı boş bırakılamaz!");
    }

    List<Map<String, dynamic>> users = await getAllUsers();

    final exists = users.any(
      (u) =>
          (u['nickname'] as String? ?? '').trim().toLowerCase() ==
          cleanNick.toLowerCase(),
    );

    if (exists) {
      throw Exception(
        "Bu kullanıcı adı zaten alınmış! Lütfen başka bir ad seçin.",
      );
    }

    final String userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

    // Sertifikada ve liderlik tablosunda yer alacak tüm istatistik alanları
    final newUser = {
      'id': userId,
      'nickname': cleanNick,
      'age': age,
      'country': country,
      'total_score': 0,
      'trash_collected': 0,
      'protected_fish': 0,
      'puzzle_score': 0,
      'quiz_score': 0,
      'cleaned_source_name': '',
      'created_at': DateTime.now().toIso8601String(),
    };

    users.add(newUser);
    await _writeToDisk(_usersTableKey, jsonEncode(users));
    await _writeToDisk(_activeUserKey, userId);

    // SharedPreferences anahtarlarını da senkronize et
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', userId);
    await prefs.setString('current_user_nickname', cleanNick);
    await prefs.setInt('total_score', 0);

    return newUser;
  }

  // --- 3. TÜM KULLANICILAR ---
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    final raw = await _readFromDisk(_usersTableKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // --- 4. AKTİF KULLANICIYI GETİR ---
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final activeId = await _readFromDisk(_activeUserKey);
    final users = await getAllUsers();
    if (users.isEmpty) return null;

    if (activeId != null) {
      try {
        return users.firstWhere((u) => u['id'] == activeId);
      } catch (_) {}
    }
    return users.last;
  }

  // --- 5. OYUN ESNASINDA İSTATİSTİK VE PUANLARI GÜNCELLE ---
  static Future<void> updateUserStats({
    int? trashCollected,
    int? protectedFish,
    int? puzzleScore,
    int? quizScore,
    int? additionalScore,
    String? cleanedSourceName,
  }) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) return;

    List<Map<String, dynamic>> users = await getAllUsers();
    final index = users.indexWhere((u) => u['id'] == currentUser['id']);
    if (index == -1) return;

    if (trashCollected != null) {
      users[index]['trash_collected'] = trashCollected;
    }
    if (protectedFish != null) {
      users[index]['protected_fish'] = protectedFish;
    }
    if (puzzleScore != null) {
      users[index]['puzzle_score'] = puzzleScore;
    }
    if (quizScore != null) {
      users[index]['quiz_score'] = quizScore;
    }
    if (cleanedSourceName != null && cleanedSourceName.isNotEmpty) {
      users[index]['cleaned_source_name'] = cleanedSourceName;
    }

    // Toplam skoru tüm oyun modlarının toplamı olarak hesapla
    final int cTrash = (users[index]['trash_collected'] as int? ?? 0) * 10;
    final int pFish = (users[index]['protected_fish'] as int? ?? 0) * 10;
    final int pZle = (users[index]['puzzle_score'] as int? ?? 0);
    final int qZ = (users[index]['quiz_score'] as int? ?? 0);
    final int add = additionalScore ?? 0;

    final int calculatedTotal = cTrash + pFish + pZle + qZ + add;
    users[index]['total_score'] = calculatedTotal;

    await _writeToDisk(_usersTableKey, jsonEncode(users));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_score', calculatedTotal);
  }

  // --- 6. TEMİZLİK NOKTASINI KAYDET VE HARİTAYA EKLE ---
  static Future<void> saveCleanedSpot({
    required String waterSourceName,
    required double latitude,
    required double longitude,
    required int earnedPoints,
  }) async {
    final currentUser = await getCurrentUser();

    final userId =
        currentUser?['id'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

    final nickname = currentUser?['nickname'] ?? 'Kahraman';

    // Temizlik noktasını haritaya kaydet
    List<Map<String, dynamic>> cleanups = await getAllCleanedSpots();

    final newSpot = {
      'id': 'spot_${DateTime.now().millisecondsSinceEpoch}',
      'user_id': userId,
      'user_nickname': nickname,
      'water_source_name': waterSourceName,
      'latitude': latitude,
      'longitude': longitude,

      // Sadece bu işlemde kazanılan puan
      'points_earned': earnedPoints,

      'cleaned_at': DateTime.now().toIso8601String(),
    };

    cleanups.add(newSpot);

    await _writeToDisk(_cleanupsTableKey, jsonEncode(cleanups));

    // Burada total_score'a puan EKLEME!
    // Puan zaten ilgili oyun ekranında hesaplanıyor.
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('cleaned_source_name', waterSourceName);

    // Kullanıcının temizlediği gerçek kaynağı DB'ye kaydet
    List<Map<String, dynamic>> users = await getAllUsers();

    final userIdx = users.indexWhere(
      (u) => u['id'] == userId || u['nickname'] == nickname,
    );

    if (userIdx != -1) {
      users[userIdx]['cleaned_source_name'] = waterSourceName;

      await _writeToDisk(_usersTableKey, jsonEncode(users));
    }
  }

  // --- 6.1 CANLI TOPLAM SKORU DİSKE VE VERİTABANINA YAZ ---
  static Future<void> setTotalScore(int total) async {
    final currentUser = await getCurrentUser();

    if (currentUser == null) return;

    final users = await getAllUsers();

    final index = users.indexWhere((u) => u['id'] == currentUser['id']);

    if (index == -1) return;

    // Liderlik tablosunun kullanacağı gerçek toplam
    users[index]['total_score'] = total;

    await _writeToDisk(_usersTableKey, jsonEncode(users));

    // SharedPreferences ile de senkron tut
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('total_score', total);
  }

  // --- 7. TÜM TEMİZLİK NOKTALARI (HARİTA MARKERLARI) ---
  static Future<List<Map<String, dynamic>>> getAllCleanedSpots() async {
    final raw = await _readFromDisk(_cleanupsTableKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // --- 8. LİDERLİK TABLOSU SIRALAMASI ---
  static Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final users = await getAllUsers();
    users.sort(
      (a, b) => ((b['total_score'] as int?) ?? 0).compareTo(
        (a['total_score'] as int?) ?? 0,
      ),
    );
    return users;
  }
}
