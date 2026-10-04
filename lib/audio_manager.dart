import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Oyunun tüm seslerini yöneten merkezi Singleton.
///
/// Kullanım: `AudioManager.instance.playBGM('ana_menu_bg')`,
/// `AudioManager.instance.playEffect('ch1_dogru_kutu.mp3')`.
/// Dosya adı `.mp3` uzantılı veya uzantısız verilebilir.
class AudioManager {
  AudioManager._();

  static final AudioManager instance = AudioManager._();
  SharedPreferences? _musicPrefs;

  double _musicVolume = 0.5;
  bool _musicMuted = false;
  Future<void> _musicSettingsQueue = Future<void>.value();

  double get musicVolume => _musicVolume;
  bool get musicMuted => _musicMuted;
  double get effectiveMusicVolume => _musicMuted ? 0.0 : _musicVolume;

  void loadMusicSettings(SharedPreferences? prefs) {
    _musicPrefs = prefs;

    _musicVolume = (prefs?.getDouble('music_volume') ?? 0.5)
        .clamp(0.0, 1.0)
        .toDouble();

    _musicMuted = prefs?.getBool('music_muted') ?? false;
  }

  void setMusicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0).toDouble();
    _applyMusicSettings();
  }

  void setMusicMuted(bool value) {
    _musicMuted = value;
    _applyMusicSettings();
  }

  void _applyMusicSettings() {
    // Slider hareketleri sırayla uygulanır ve kaydedilir.
    _musicSettingsQueue = _musicSettingsQueue.then((_) async {
      await _safely(() async {
        if (_initialized) {
          await bgPlayer.setVolume(effectiveMusicVolume);
        }
      });

      await _safely(() async {
        await _musicPrefs?.setDouble('music_volume', _musicVolume);
        await _musicPrefs?.setBool('music_muted', _musicMuted);
      });
    });
  }

  static const _folder = 'audio/';

  // Şimdilik yalnızca bu dosyalar önceden yüklenir.
  static const preloadFiles = <String>[
    'ana_menu_bg.mp3',
    'bubble_button_click.mp3',
    'chapter_hikaye_bg.mp3',
    'ch1_oyun_bg.mp3',
    'ch1_nesne_tutma_effect.mp3',
    'ch1_dogru_kutu.mp3',
    'ch1_yanlis_kutu.mp3',
    'kazandin.mp3',
    'kaybettin.mp3',
    'dedenin_kitabi_click.mp3',
    'fark_bulma_oyunu_bg.mp3',
    'fark_bulma_bildin.mp3',
    'ch2_oyun_bg.mp3',
    'mikroplastik_yutma.mp3',
    'mikroplastik_sonu.mp3',
    'balik_heal_bg.mp3',
    'dogru_balik_heal.mp3',
    'final_heal.mp3',
    'tum_balik_heal.mp3',
    'ch3_balik_tutma_bg.mp3',
    'olta_atma.mp3',
    'oltayi_cek.mp3',
    'cop_tuttu.mp3',
    'balik_tuttu.mp3',
    'puzzle_bg.mp3',
    'puzzle_tutus.mp3',
  ];

  // Aynı anda çalabilecek efekt sayısı.
  static const _effectPoolSize = 4;

  // Efektler müziği bastırmasın diye tam seviyenin biraz altında.
  static const _effectVolume = 0.8;

  // Sık ve uzun çalan efektler için ayrı seviye (0.0–1.0). CH1'de her atıkta
  // iki efekt çalıyor; oyun müziği duyulabilsin diye daha kısık. Kulakla
  // ayarlamak için yalnızca bu tabloyu değiştirmek yeterli.
  static const _effectVolumes = <String, double>{
    'ch1_nesne_tutma_effect.mp3': 0.45,
    'ch1_dogru_kutu.mp3': 0.5,
    'ch1_yanlis_kutu.mp3': 0.55,
    // CH3 basılı tutma boyunca ~3 sn çalar; varsayılan 0.8'den kısık.
    'oltayi_cek.mp3': 0.6,
  };

  // Oyuncular init() içinde oluşturulur. init() çağrılmadıysa (ör. testlerde,
  // ses eklentisi yokken) tüm çalma fonksiyonları sessizce hiçbir şey yapmaz.
  late final AudioPlayer bgPlayer;
  late final List<AudioPlayer> effectPlayers;

  int _nextEffect = 0;
  // Her efekt dosyasını son çalan oyuncu; aynı efekt üst üste binmesin diye.
  final Map<String, AudioPlayer> _lastPlayerFor = {};
  // Her efekt dosyası için istek sayacı; stopEffect, henüz başlamamış bir
  // playEffect'in sonradan çalmasını engeller.
  final Map<String, int> _effectRequest = {};
  String? _currentBGM;
  // Her müzik isteğinde artar; bekleyen bir "sonra çal" isteğinin hâlâ
  // geçerli olup olmadığını anlamak için kullanılır.
  int _bgmRequest = 0;
  bool _initialized = false;

  // Uygulama arka plandayken ses çalınmaz. Duraklatılan müzik dönüşte kaldığı
  // yerden sürer; arka plandayken istenen yeni müzik dönüşte başlar.
  bool _inBackground = false;
  bool _resumeOnForeground = false;
  String? _pendingBGM;

  /// Oyun açılışında bir kez çağrılır.
  static Future<void> init() => instance._init();

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    bgPlayer = AudioPlayer(playerId: 'bg');
    effectPlayers = List.generate(
      _effectPoolSize,
      (i) => AudioPlayer(playerId: 'effect_$i'),
    );

    // Efektler müziği durdurmasın: hiçbir oyuncu ses odağını tek başına almaz.
    final context = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
    ).build();

    await _safely(() async {
      await bgPlayer.setAudioContext(context);
      await bgPlayer.setReleaseMode(ReleaseMode.loop);
      await bgPlayer.setVolume(effectiveMusicVolume);
    });

    for (final player in effectPlayers) {
      await _safely(() async {
        await player.setAudioContext(context);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(_effectVolume);
      });
    }

    // Dosyaları önbelleğe al; ilk çalmada gecikme olmasın.
    await _safely(
      () => AudioCache.instance.loadAll([
        for (final file in preloadFiles) '$_folder$file',
      ]),
    );
  }

  /// Arka plan müziğini sonsuz döngüde çalar.
  /// Aynı müzik zaten çalıyorsa baştan başlatmaz.
  Future<void> playBGM(String dosyaAdi) async {
    if (!_initialized) return;
    final file = _normalize(dosyaAdi);
    if (_inBackground) {
      _bgmRequest++;
      _currentBGM = file;
      _pendingBGM = file;
      _resumeOnForeground = false;
      return;
    }
    if (_currentBGM == file && bgPlayer.state == PlayerState.playing) return;
    _bgmRequest++;
    _currentBGM = file;
    await _safely(() async {
      await bgPlayer.stop();
      await bgPlayer.setReleaseMode(ReleaseMode.loop);
      await bgPlayer.play(
        AssetSource('$_folder$file'),
        volume: effectiveMusicVolume,
      );
    });
  }

  Future<void> stopBGM() async {
    if (!_initialized) return;
    _bgmRequest++;
    _currentBGM = null;
    _pendingBGM = null;
    _resumeOnForeground = false;
    await _safely(bgPlayer.stop);
  }

  /// Uygulama arka plana alınınca çağrılır (inactive/paused/hidden/detached).
  /// Art arda gelen çağrılar zararsızdır.
  Future<void> pauseForBackground() async {
    if (!_initialized || _inBackground) return;
    _inBackground = true;
    _resumeOnForeground = bgPlayer.state == PlayerState.playing;
    await _safely(bgPlayer.pause);
    for (final player in effectPlayers) {
      await _safely(player.stop);
    }
  }

  /// Uygulamaya geri dönülünce çağrılır.
  Future<void> resumeFromBackground() async {
    if (!_initialized || !_inBackground) return;
    _inBackground = false;
    final pending = _pendingBGM;
    _pendingBGM = null;
    if (pending != null) {
      _currentBGM = null; // playBGM aynı dosyayı atlamasın.
      await playBGM(pending);
    } else if (_resumeOnForeground) {
      _resumeOnForeground = false;
      await _safely(bgPlayer.resume);
    }
  }

  /// Müziği durdurur, kısa bir sonuç sesi (ör. kazandin/kaybettin) çalar ve
  /// o bitince [sonrakiBGM]'i başlatır.
  ///
  /// Ses, bitişi bildirebilsin diye düşük gecikmeli efekt oyuncusunda değil
  /// müzik oyuncusunda bir kez (döngüsüz) çalınır. Bu arada başka bir
  /// playBGM/stopBGM çağrılırsa [sonrakiBGM] başlatılmaz.
  Future<void> playJingleThenBGM(String dosyaAdi, String sonrakiBGM) async {
    if (!_initialized) return;
    // Arka plandayken sonuç sesi atlanır; sonraki müzik dönüşte başlar.
    if (_inBackground) return playBGM(sonrakiBGM);
    final request = ++_bgmRequest;
    _currentBGM = null;
    final file = _normalize(dosyaAdi);
    await _safely(() async {
      await bgPlayer.stop();
      await bgPlayer.setReleaseMode(ReleaseMode.release);
      final finished = bgPlayer.onPlayerComplete.first;
      // Jingle efekt seviyesinde çalar ama müzik kapalıysa o da susar.
      // Ardından gelen playBGM müzik seviyesini yeniden uygular.
      await bgPlayer.play(
        AssetSource('$_folder$file'),
        volume: _musicMuted ? 0.0 : (_effectVolumes[file] ?? _effectVolume),
      );
      // Bitiş olayı gelmezse menü müziği yine de başlasın.
      // En uzun jingle (tum_balik_heal) ~5,9 sn; sınır payı bırakır.
      await finished.timeout(const Duration(seconds: 10));
    });
    if (request == _bgmRequest) await playBGM(sonrakiBGM);
  }

  /// Kısa efekt çalar. Farklı efektler aynı anda çalabilir; aynı efekt ise
  /// tekrar çalınınca öncekini keser ve baştan başlar (kopyalar üst üste
  /// binip müziği bastırmasın).
  Future<void> playEffect(String dosyaAdi) async {
    if (!_initialized || _inBackground) return;
    final file = _normalize(dosyaAdi);
    var player = _lastPlayerFor[file];
    if (player == null) {
      player = effectPlayers[_nextEffect];
      _nextEffect = (_nextEffect + 1) % effectPlayers.length;
      // Bu oyuncu artık başka dosyanın değil.
      _lastPlayerFor.removeWhere((_, p) => p == player);
      _lastPlayerFor[file] = player;
    }
    final target = player;
    final request = _effectRequest[file] = (_effectRequest[file] ?? 0) + 1;
    await _safely(() async {
      await target.stop();
      if (_effectRequest[file] != request) return;
      await target.play(
        AssetSource('$_folder$file'),
        volume: _effectVolumes[file] ?? _effectVolume,
      );
    });
  }

  /// Çalan (veya başlamak üzere olan) bir efekti durdurur.
  Future<void> stopEffect(String dosyaAdi) async {
    if (!_initialized) return;
    final file = _normalize(dosyaAdi);
    _effectRequest[file] = (_effectRequest[file] ?? 0) + 1;
    final player = _lastPlayerFor[file];
    if (player != null) await _safely(player.stop);
  }

  String _normalize(String name) => name.endsWith('.mp3') ? name : '$name.mp3';

  // Ses hatası (ör. tarayıcının otomatik oynatma engeli) oyunu durdurmamalı.
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('AudioManager: $e');
    }
  }
}
