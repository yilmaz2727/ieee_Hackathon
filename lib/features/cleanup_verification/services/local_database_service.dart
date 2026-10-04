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
    final prefs = await SharedPreferences.getInstance();

    final saved = await prefs.setString(key, value);

    if (!saved) {
      throw StateError('Veri kaydedilemedi: $key');
    }

    if (kIsWeb) {
      html.window.localStorage[key] = value;
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

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final activeId = await _readFromDisk(_activeUserKey);
    if (activeId == null || activeId.isEmpty) return null;

    final users = await getAllUsers();

    for (final user in users) {
      if (user['id'] == activeId) return user;
    }

    return null;
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

    // 1. Temizlik noktasını harita listesine ekle
    List<Map<String, dynamic>> cleanups = await getAllCleanedSpots();
    final newSpot = {
      'id': 'spot_${DateTime.now().millisecondsSinceEpoch}',
      'user_id': userId,
      'user_nickname': nickname,
      'water_source_name': waterSourceName,
      'latitude': latitude,
      'longitude': longitude,
      'points_earned': earnedPoints,
      'cleaned_at': DateTime.now().toIso8601String(),
    };
    cleanups.add(newSpot);
    await _writeToDisk(_cleanupsTableKey, jsonEncode(cleanups));

    // 2. Bu metot yalnızca temizlik noktasını kaydeder.
    // Puan/bonus güncellemesi çağıran ekran tarafından tek sefer yapılır;
    // böylece aynı puanın iki kez eklenmesi engellenir.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cleaned_source_name', waterSourceName);

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
    final i = users.indexWhere((u) => u['id'] == currentUser['id']);
    if (i == -1) return;
    users[i]['total_score'] = total;
    await _writeToDisk(_usersTableKey, jsonEncode(users));
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

  // Her hesaba ayrı kaydedilecek oyun bilgileri.
  // Dil ve ses ayarları cihazda ortak kalır.
  static const List<String> _accountProgressKeys = [
    'cleanup_count',
    'cleanup_score',
    'fish_saved',
    'fish_swallowed',
    'healing_score',
    'chapter2_score',
    'quiz_correct',
    'quiz_score',
    'puzzle_score',
    'bonus_score',
    'total_score',
    'cleaned_source_name',
    'water_source',
    'ai_photo_verified',
    'chapter',
    'completed',
    'completedAt',
    'chapter1_difference_found',
    'chapter2_healing_taps',
  ];

  static String _progressKey(String userId) => 'ACCOUNT_PROGRESS_V1_$userId';

  static Future<void> _saveCurrentAccountProgress(
    SharedPreferences prefs,
  ) async {
    final userId = prefs.getString('current_user_id');

    if (userId == null || userId.isEmpty) return;

    final progress = <String, dynamic>{};

    for (final key in _accountProgressKeys) {
      final value = prefs.get(key);

      if (value != null) {
        progress[key] = value;
      }
    }

    final saved = await prefs.setString(
      _progressKey(userId),
      jsonEncode(progress),
    );

    if (!saved) {
      throw StateError('Oyuncu ilerlemesi kaydedilemedi.');
    }
  }

  static Future<void> _clearCurrentProgress(SharedPreferences prefs) async {
    for (final key in _accountProgressKeys) {
      final removed = await prefs.remove(key);

      if (!removed) {
        throw StateError('Oyun oturumu temizlenemedi.');
      }
    }
  }

  static Future<void> _restoreAccountProgress(
    SharedPreferences prefs,
    String userId,
  ) async {
    final raw = prefs.getString(_progressKey(userId));

    // Bu hesabın henüz bir oyun kaydı yok.
    if (raw == null) return;

    final progress = Map<String, dynamic>.from(jsonDecode(raw) as Map);

    for (final key in _accountProgressKeys) {
      final value = progress[key];

      if (value == null) continue;

      bool saved;

      if (value is bool) {
        saved = await prefs.setBool(key, value);
      } else if (value is int) {
        saved = await prefs.setInt(key, value);
      } else if (value is double) {
        saved = await prefs.setDouble(key, value);
      } else if (value is String) {
        saved = await prefs.setString(key, value);
      } else if (value is List) {
        saved = await prefs.setStringList(
          key,
          value.map((item) => item.toString()).toList(),
        );
      } else {
        throw StateError('Desteklenmeyen oyun kaydı.');
      }

      if (!saved) {
        throw StateError('Oyuncu ilerlemesi yüklenemedi.');
      }
    }
  }

  static Future<void> signInWithNickname(
    String nickname, {
    required int age,
    required String gender,
  }) async {
    final cleanNick = nickname.trim();

    if (cleanNick.length < 2 || cleanNick.length > 24) {
      throw ArgumentError('Oyuncu adı 2–24 karakter olmalı.');
    }

    if (age < 4 || age > 120) {
      throw ArgumentError('Geçerli bir yaş girilmeli.');
    }

    const allowedGenders = {'female', 'male', 'other', 'prefer_not_to_say'};

    if (!allowedGenders.contains(gender)) {
      throw ArgumentError('Geçerli bir cinsiyet seçilmeli.');
    }

    final prefs = await SharedPreferences.getInstance();
    final previousId = prefs.getString('current_user_id');
    final users = await getAllUsers();

    final index = users.indexWhere(
      (user) =>
          (user['nickname'] as String? ?? '').trim().toLowerCase() ==
          cleanNick.toLowerCase(),
    );

    late final Map<String, dynamic> user;

    if (index >= 0) {
      // Aynı nick mevcutsa aynı hesabı kullan.
      // Puan, rozet ve kullanıcı kimliği değişmez.
      user = Map<String, dynamic>.from(users[index]);

      user['age'] = age;
      user['gender'] = gender;
      user['updated_at'] = DateTime.now().toIso8601String();

      users[index] = user;
    } else {
      user = <String, dynamic>{
        'id': 'user_${DateTime.now().microsecondsSinceEpoch}',
        'nickname': cleanNick,
        'age': age,
        'gender': gender,
        'country': '',
        'total_score': 0,
        'trash_collected': 0,
        'protected_fish': 0,
        'puzzle_score': 0,
        'quiz_score': 0,
        'cleaned_source_name': '',
        'created_at': DateTime.now().toIso8601String(),
      };

      users.add(user);
    }

    final userId = user['id'] as String;

    if (previousId != userId) {
      await _saveCurrentAccountProgress(prefs);
      await _clearCurrentProgress(prefs);
      await _restoreAccountProgress(prefs, userId);
    }

    await _writeToDisk(_usersTableKey, jsonEncode(users));

    await prefs.setString('current_user_nickname', user['nickname'] as String);
    await prefs.setInt('current_user_age', age);
    await prefs.setString('current_user_gender', gender);

    await _writeToDisk(_activeUserKey, userId);
    await prefs.setString('current_user_id', userId);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();

    // Çıkıştan önce mevcut oyuncunun kaldığı yeri sakla.
    await _saveCurrentAccountProgress(prefs);

    await _writeToDisk(_activeUserKey, '');

    await prefs.remove('current_user_id');
    await prefs.remove('current_user_nickname');
    await prefs.remove('current_user_age');
    await prefs.remove('current_user_gender');
    await prefs.remove('current_user_country');

    await _clearCurrentProgress(prefs);

    // Kullanıcı tablosu, hesaplara ait ilerlemeler ve
    // guardian_best_reward_v1_* rozet kayıtları silinmez.
  }
}
