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
    'puzzle_fark_bulma_bildin.mp3',
  ];

  // Aynı anda çalabilecek efekt sayısı.
  static const _effectPoolSize = 4;

  // Oyuncular init() içinde oluşturulur. init() çağrılmadıysa (ör. testlerde,
  // ses eklentisi yokken) tüm çalma fonksiyonları sessizce hiçbir şey yapmaz.
  late final AudioPlayer bgPlayer;
  late final List<AudioPlayer> effectPlayers;

  int _nextEffect = 0;
  String? _currentBGM;
  // Her müzik isteğinde artar; bekleyen bir "sonra çal" isteğinin hâlâ
  // geçerli olup olmadığını anlamak için kullanılır.
  int _bgmRequest = 0;
  bool _initialized = false;

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
        await player.setVolume(1.0);
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
    await _safely(bgPlayer.stop);
  }

  /// Müziği durdurur, kısa bir sonuç sesi (ör. kazandin/kaybettin) çalar ve
  /// o bitince [sonrakiBGM]'i başlatır.
  ///
  /// Ses, bitişi bildirebilsin diye düşük gecikmeli efekt oyuncusunda değil
  /// müzik oyuncusunda bir kez (döngüsüz) çalınır. Bu arada başka bir
  /// playBGM/stopBGM çağrılırsa [sonrakiBGM] başlatılmaz.
  Future<void> playJingleThenBGM(String dosyaAdi, String sonrakiBGM) async {
    if (!_initialized) return;
    final request = ++_bgmRequest;
    _currentBGM = null;
    await _safely(() async {
      await bgPlayer.stop();
      await bgPlayer.setReleaseMode(ReleaseMode.release);
      final finished = bgPlayer.onPlayerComplete.first;
      await bgPlayer.play(
        AssetSource('$_folder${_normalize(dosyaAdi)}'),
        volume: effectiveMusicVolume,
      );
      // Bitiş olayı gelmezse menü müziği yine de başlasın.
      await finished.timeout(const Duration(seconds: 6));
    });
    if (request == _bgmRequest) await playBGM(sonrakiBGM);
  }

  /// Kısa efekt çalar. Oyuncular sırayla kullanıldığı için
  /// art arda gelen efektler birbirini kesmez.
  Future<void> playEffect(String dosyaAdi) async {
    if (!_initialized) return;
    final player = effectPlayers[_nextEffect];
    _nextEffect = (_nextEffect + 1) % effectPlayers.length;
    await _safely(() async {
      await player.stop();
      await player.play(
        AssetSource('$_folder${_normalize(dosyaAdi)}'),
        volume: 1.0,
      );
    });
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
