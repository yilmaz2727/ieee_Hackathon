import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio_manager.dart';
import '../localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Scene {
  home,
  intro,
  cleanupFirst,
  firstResult,
  differencePuzzle,
  differenceResult,
  underwater,
  protection,
  protectionResult,
  fishHealing,
  fishHealingResult,
  fishing,
  catchWaste,
  inspection,
  discovery,
  rewind,
  fishPuzzle,
  prevention,
  cleanupSecond,
  retry,
  success,
  photo,
  impactMap,
  reward,
}

class Waste {
  Waste(this.id, this.x, this.y, this.kind, this.speed);

  final int id, kind;
  double x, y;
  final double speed;
}

class StoryController extends ChangeNotifier {
  StoryController({Random? random}) : random = random ?? Random();

  final Random random;

  Scene scene = Scene.home;

  double elapsed = 0;
  double spawnClock = 0;
  double worldTime = 0;

  int collected = 0;
  int firstCollected = 0;
  int firstIncoming = 0;
  int incoming = 0;
  int nextId = 0;

  int swallowed = 0;
  int avoided = 0;
  int catches = 0;

  int get chapterOneScore => firstCollected * 10;
  int get chapterTwoScore => avoided - (swallowed * 5);
  int get chapterFourScore => preventionCorrect * 20;
  int get liveTotalScore =>
      chapterOneScore + chapterTwoScore + chapterFourScore;
  // -1: healthy from the start; 0..3: treatment steps for five sick fish.
  final List<int> healingTaps = [];
  static const healingFishCount = 15;
  static const sickFishCount = 5;
  static const healingTapTarget = 3;
  int get healedFish =>
      healingTaps.where((taps) => taps == healingTapTarget).length;
  bool get healingComplete => healedFish == sickFishCount;

  void restoreHealing(List<int> values) {
    if (values.length != healingFishCount ||
        values.any((v) => v < -1 || v > healingTapTarget) ||
        values.where((v) => v >= 0).length != sickFishCount) {
      return;
    }
    healingTaps
      ..clear()
      ..addAll(values);
  }

  void prepareHealing() {
    if (healingTaps.isNotEmpty) return;
    final indices = List.generate(healingFishCount, (i) => i)..shuffle(random);
    final sick = indices.take(sickFishCount).toSet();
    healingTaps.addAll(
      List.generate(healingFishCount, (i) => sick.contains(i) ? 0 : -1),
    );
  }

  bool healFish(int index) {
    if (scene != Scene.fishHealing ||
        paused ||
        index < 0 ||
        index >= healingTaps.length ||
        healingTaps[index] < 0 ||
        healingTaps[index] >= healingTapTarget) {
      return false;
    }
    healingTaps[index]++;
    notifyListeners();
    return true;
  }

  int sortingMistakes = 0;

  bool paused = false;
  bool cast = false;
  bool bite = false;
  bool replaying = false;

  // -------------------------------------------------
  // FİNAL: 5 SENARYOLU DOĞA DOSTU SEÇİM OYUNU
  // -------------------------------------------------

  int preventionStep = 0;
  int preventionCorrect = 0;
  int? preventionSelected;
  bool preventionAnswered = false;

  String preventionFeedback = '';

  // -------------------------------------------------
  // CHAPTER 3 - OLTA
  // -------------------------------------------------

  double fishingTime = 0;
  double fishX = .5;

  // Oyuncunun dokunduğu olta konumu
  double fishingX = .53;
  double fishingY = .45;

  String fishingHint = tr('story.fishing.initial');
  String sortingHint = tr('story.sorting.initial');

  Waste? selectedWaste;

  // Ekranda hareket eden atıklar
  final List<Waste> waste = [];

  final Set<int> sources = {};
  final Set<int> found = {};

  // Chapter 1 fark bulmacasında bulunan noktalar.
  // Controller'da tutulduğu için ana menüye dönüp devam edildiğinde korunur.
  final Set<int> differenceFound = {};

  // Independent visual restoration per location;
  // never a real water-quality measure.
  final List<double> waterClarity = [0, 0, 0];
  final List<double> visibleClarity = [0, 0, 0];

  double get clarity => waterClarity[chapter - 1];

  String get backgroundAsset =>
      'assets/images/${['samlar', 'sazlidere', 'kucukcekmece'][chapter - 1]}.png';

  void resetWater(int index) {
    waterClarity[index] = 0;
    visibleClarity[index] = 0;
  }

  final Set<int> pages = {0};

  String? lastDiscovery;

  bool completed = false;
  DateTime? completedAt;

  static const firstRoundSeconds = 20.0;
  static const roundSeconds = 45.0;
  static const secondTarget = 10;

  // Chapter 2 artık 30 saniye
  static const protectionSeconds = 30.0;

  // -------------------------------------------------
  // CHAPTER 2 ZORLUK
  // -------------------------------------------------

  double get protectionProgress =>
      (elapsed / protectionSeconds).clamp(0.0, 1.0);

  double get protectionSpawnInterval => .72 - (.32 * protectionProgress);

  bool get cleaning =>
      scene == Scene.cleanupFirst || scene == Scene.cleanupSecond;

  int get secondsLeft {
    final total = switch (scene) {
      Scene.cleanupFirst => firstRoundSeconds,
      Scene.protection => protectionSeconds,
      _ => roundSeconds,
    };

    return max(0, (total - elapsed).ceil());
  }

  double get spawnInterval =>
      scene == Scene.cleanupFirst ? 1.05 : 1.8 + sources.length * 1.4;

  int get chapter => switch (scene) {
    Scene.home ||
    Scene.intro ||
    Scene.cleanupFirst ||
    Scene.firstResult ||
    Scene.differencePuzzle ||
    Scene.differenceResult ||
    Scene.prevention ||
    Scene.cleanupSecond ||
    Scene.retry ||
    Scene.rewind ||
    Scene.success => 1,

    Scene.underwater ||
    Scene.protection ||
    Scene.protectionResult ||
    Scene.fishHealing ||
    Scene.fishHealingResult => 2,

    _ => 3,
  };

  String get location => switch (chapter) {
    1 => tr('chapter.location.1'),
    2 => tr('chapter.location.2'),
    _ => tr('chapter.location.3'),
  };

  // -------------------------------------------------
  // SAHNE GEÇİŞLERİ
  // -------------------------------------------------

  void go(Scene target) {
    // Chapter 1'de en az 10 atık şartı
    if (target == Scene.underwater &&
        scene == Scene.firstResult &&
        firstCollected < secondTarget) {
      return;
    }

    if (target == Scene.fishHealingResult && !healingComplete) return;
    if (target == Scene.fishHealing) prepareHealing();

    scene = target;

    elapsed = 0;
    paused = false;
    lastDiscovery = null;
    selectedWaste = null;

    // -------------------------------------------------
    // CHAPTER 1
    // -------------------------------------------------

    if (cleaning) {
      resetWater(0);

      collected = 0;
      incoming = 0;
      spawnClock = 0;

      waste.clear();

      sortingHint = tr('story.sorting.initial');

      final initialCount = target == Scene.cleanupFirst ? 5 : 6;

      for (var i = 0; i < initialCount; i++) {
        spawn(initial: true);
      }
    }

    // -------------------------------------------------
    // CHAPTER 2
    // -------------------------------------------------

    if (target == Scene.protection) {
      healingTaps.clear();
      resetWater(1);

      swallowed = 0;
      avoided = 0;
      spawnClock = 0;

      fishX = .5;

      waste.clear();
    }

    // -------------------------------------------------
    // FİNAL 5 SENARYO
    // -------------------------------------------------

    if (target == Scene.prevention) {
      preventionStep = 0;
      preventionCorrect = 0;
      preventionSelected = null;
      preventionAnswered = false;
      preventionFeedback = '';

      replaying = true;
    }

    // -------------------------------------------------
    // CHAPTER 3 - OLTA
    // -------------------------------------------------

    if (target == Scene.fishing) {
      cast = false;
      bite = false;

      fishingTime = 0;

      fishingX = .53;
      fishingY = .45;

      fishingHint = tr('story.fishing.initial');
    }

    if (target == Scene.inspection) {
      found.clear();
      pages.add(2);
    }

    if (target == Scene.underwater) {
      pages.add(1);
    }

    if (target == Scene.discovery) {
      pages.add(3);
    }

    if (target == Scene.success) {
      completed = true;
      completedAt ??= DateTime.now();

      pages.add(4);
    }

    notifyListeners();
  }

  // -------------------------------------------------
  // YENİ OYUN
  // -------------------------------------------------

  void startNew() {
    sources.clear();
    found.clear();
    differenceFound.clear();
    healingTaps.clear();

    waste.clear();

    for (var i = 0; i < 3; i++) {
      resetWater(i);
    }

    pages
      ..clear()
      ..add(0);

    firstCollected = 0;
    firstIncoming = 0;

    completed = false;
    completedAt = null;

    catches = 0;
    replaying = false;
    sortingMistakes = 0;

    swallowed = 0;
    avoided = 0;

    preventionStep = 0;
    preventionCorrect = 0;
    preventionSelected = null;
    preventionAnswered = false;
    preventionFeedback = '';

    go(Scene.intro);
  }

  // -------------------------------------------------
  // KALDIĞI YERDEN DEVAM
  // -------------------------------------------------

  void resumeChapter(int checkpoint) {
    // Menü müziği kesin olarak durur. CH1 kayıtlarında (1, 5, 6) hikâye
    // müziği başlar; playBGM önce çalanı durdurur. CH2, CH3 ve final şimdilik
    // bilinçli olarak sessiz.
    // 2 = CH2, 3 = CH3, 4 = final; aşağıdaki else dalı da CH1 girişine gider.
    final resumesChapterOne =
        checkpoint < 2 || checkpoint == 5 || checkpoint == 6;
    if (resumesChapterOne) {
      AudioManager.instance.playBGM('chapter_hikaye_bg.mp3');
    } else {
      AudioManager.instance.stopBGM();
    }

    // 6 = Chapter 1 fark bulmaca sonuç ekranı
    // 5 = Chapter 1 fark bulmaca checkpoint'i
    if (checkpoint == 7 || checkpoint == 8) {
      pages.addAll([0, 1]);
      prepareHealing();
      go(healingComplete ? Scene.fishHealingResult : Scene.fishHealing);
    } else if (checkpoint == 6) {
      pages.add(0);
      go(Scene.differenceResult);
    } else if (checkpoint == 5) {
      pages.add(0);
      go(Scene.differencePuzzle);
    } else if (checkpoint == 4) {
      pages.addAll([0, 1, 2, 3]);

      replaying = true;

      sources.clear();

      go(Scene.prevention);
    } else if (checkpoint == 3) {
      pages.addAll([0, 1, 2]);

      catches = 0;

      resetWater(2);

      go(Scene.fishing);
    } else if (checkpoint == 2) {
      pages.addAll([0, 1]);

      go(Scene.underwater);
    } else {
      resetWater(0);

      go(Scene.intro);
    }
  }

  // -------------------------------------------------
  // DURAKLAT
  // -------------------------------------------------

  void setPaused(bool value) {
    paused = value;

    notifyListeners();
  }

  // -------------------------------------------------
  // CHAPTER 1 ATIK OLUŞTUR
  // -------------------------------------------------

  void spawn({bool initial = false}) {
    waste.add(
      Waste(
        nextId++,
        .10 + random.nextDouble() * .8,
        initial ? .20 + random.nextDouble() * .40 : .14,
        random.nextInt(3),
        .025 + random.nextDouble() * .018,
      ),
    );

    incoming++;
  }

  // -------------------------------------------------
  // CHAPTER 1 ATIK SEÇ
  // -------------------------------------------------

  void selectWaste(int id) {
    if (!cleaning || paused) return;

    final match = waste.where((w) => w.id == id);

    if (match.isEmpty) return;

    selectedWaste = match.first;

    final itemName = [
      tr('story.item.straw'),
      tr('story.item.can'),
      tr('story.item.paper'),
    ][selectedWaste!.kind];
    sortingHint = tr('story.sorting.question', {'item': itemName});

    notifyListeners();
  }

  // -------------------------------------------------
  // CHAPTER 1 AYRIŞTIR
  // -------------------------------------------------

  void sortWaste(int bin) {
    final selected = selectedWaste;

    if (!cleaning || selected == null || paused) {
      return;
    }

    if (selected.kind != bin) {
      sortingMistakes++;

      sortingHint = tr('story.sorting.wrong');

      notifyListeners();

      return;
    }

    waste.removeWhere((w) => w.id == selected.id);

    collected++;

    waterClarity[0] = (collected / secondTarget).clamp(0.0, 1.0);

    selectedWaste = null;

    sortingHint = tr('story.sorting.correct');

    notifyListeners();
  }

  // -------------------------------------------------
  // YENİ FİNAL OYUNU
  // 5 DOĞA DOSTU SENARYO
  // -------------------------------------------------

  void answerPrevention(int selected, int correctAnswer) {
    if (scene != Scene.prevention || paused || preventionAnswered) {
      return;
    }

    preventionSelected = selected;
    preventionAnswered = true;

    if (selected == correctAnswer) {
      preventionCorrect++;

      preventionFeedback = tr('story.prevention.correct');
    } else {
      preventionFeedback = tr('story.prevention.wrong');
    }

    notifyListeners();
  }

  void nextPreventionScenario() {
    if (scene != Scene.prevention || paused || !preventionAnswered) {
      return;
    }
    // 0, 1, 2, 3, 4 = toplam 5 senaryo
    if (preventionStep >= 4) {
      replaying = true;

      go(Scene.success);

      return;
    }

    preventionStep++;

    preventionSelected = null;
    preventionAnswered = false;
    preventionFeedback = '';

    notifyListeners();
  }

  // -------------------------------------------------
  // ESKİ FİNAL AKIŞI
  //
  // Şimdilik main.dart'ın eski sürümü hata vermesin
  // diye bırakıyoruz.
  // Yeni prevention() ekranı tamamlanınca bunlar
  // kullanılmayacak.
  // -------------------------------------------------

  void prevent(int index) {
    if (scene != Scene.prevention || index < 0 || index > 2) {
      return;
    }

    sources.add(index);

    notifyListeners();
  }

  void startSecond() {
    if (sources.length == 3) {
      replaying = true;

      go(Scene.cleanupSecond);
    }
  }

  // -------------------------------------------------
  // CHAPTER 1 - FARK BULMACASI
  // -------------------------------------------------

  void markDifferenceFound(int index) {
    if (scene != Scene.differencePuzzle || index < 0 || index >= 5) return;
    if (differenceFound.add(index)) {
      notifyListeners();
    }
  }

  // -------------------------------------------------
  // CHAPTER 2 - BALIĞI HAREKET ETTİR
  // -------------------------------------------------

  void moveFish(double x) {
    if (scene == Scene.protection && !paused) {
      fishX = x.clamp(.09, .91);

      notifyListeners();
    }
  }

  // -------------------------------------------------
  // CHAPTER 3 - KEŞİF
  // -------------------------------------------------

  void discover(int index) {
    if (scene != Scene.inspection || index < 0 || index > 2) {
      return;
    }

    found.add(index);

    lastDiscovery = [
      tr('story.discovery.1'),
      tr('story.discovery.2'),
      tr('story.discovery.3'),
    ][index];

    notifyListeners();
  }

  // -------------------------------------------------
  // CHAPTER 3 - DOKUNULAN YERE OLTA AT
  // -------------------------------------------------

  void castFishingAt(double x, double y) {
    if (scene != Scene.fishing || paused || cast) {
      return;
    }

    fishingX = x.clamp(.10, .90);
    fishingY = y.clamp(.20, .72);

    cast = true;
    bite = false;

    fishingTime = 0;

    fishingHint = tr('story.fishing.wait');

    notifyListeners();
  }

  // -------------------------------------------------
  // CHAPTER 3 - OLTAYI ÇEK
  // -------------------------------------------------

  void fishingAction() {
    if (scene != Scene.fishing || paused || !cast) {
      return;
    }

    if (bite) {
      catches++;

      if (catches <= 2) {
        waterClarity[2] = catches / 2;
      }

      go(catches < 3 ? Scene.catchWaste : Scene.inspection);

      return;
    }

    fishingHint = tr('story.fishing.tooEarly');

    notifyListeners();
  }

  // -------------------------------------------------
  // OYUN DÖNGÜSÜ
  // -------------------------------------------------

  void tick(double dt) {
    if (paused) return;

    dt = dt.clamp(0, .1);

    worldTime += dt;

    // Suyun berraklık geçişi
    for (var i = 0; i < 3; i++) {
      visibleClarity[i] +=
          (waterClarity[i] - visibleClarity[i]) * min(1.0, dt * 4);
    }

    // -------------------------------------------------
    // ESKİ İKİNCİ TEMİZLİK OYUNU
    //
    // Yeni finalde artık kullanılmayacak.
    // Eski main.dart uyumluluğu için duruyor.
    // -------------------------------------------------

    if (scene == Scene.cleanupSecond && selectedWaste == null) {
      elapsed += dt;
      spawnClock += dt;

      if (spawnClock >= spawnInterval) {
        spawnClock -= spawnInterval;

        spawn();
      }

      for (final w in waste) {
        w.y += w.speed * dt;

        w.x += sin(worldTime + w.id) * dt * .007;
      }

      waste.removeWhere((w) => w.y > .75);

      final roundDuration = scene == Scene.cleanupFirst
          ? firstRoundSeconds
          : roundSeconds;

      if (elapsed >= roundDuration) {
        if (scene == Scene.cleanupFirst) {
          firstCollected = collected;
          firstIncoming = incoming;

          go(Scene.firstResult);
        } else {
          go(collected >= secondTarget ? Scene.success : Scene.retry);
        }

        return;
      }
    }

    // -------------------------------------------------
    // CHAPTER 2
    // -------------------------------------------------

    if (scene == Scene.protection) {
      elapsed += dt;
      spawnClock += dt;

      final interval = protectionSpawnInterval;

      if (spawnClock >= interval) {
        spawnClock -= interval;

        final progress = protectionProgress;

        waste.add(
          Waste(
            nextId++,
            .10 + random.nextDouble() * .8,
            .10,
            random.nextInt(3),
            .145 + random.nextDouble() * .055 + progress * .085,
          ),
        );
      }

      final removed = <int>[];

      for (final w in waste) {
        w.y += w.speed * dt;

        // Akıntı nedeniyle hafif sağ-sol hareket
        w.x = (w.x + sin(worldTime * 1.7 + w.id) * dt * .012).clamp(.06, .94);

        // Balığa çarptı -> yutuldu
        if (w.y >= .72 && w.y <= .82 && (w.x - fishX).abs() < .095) {
          swallowed++;

          removed.add(w.id);
        }
        // Balığı geçti -> toplama ağına ulaştı
        else if (w.y >= .86) {
          avoided++;

          waterClarity[1] = (avoided / 20).clamp(0.0, 1.0);

          removed.add(w.id);
        }
      }

      waste.removeWhere((w) => removed.contains(w.id));

      if (elapsed >= protectionSeconds) {
        go(Scene.protectionResult);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('healing_score', chapterTwoScore);
          prefs.setInt('chapter2_score', chapterTwoScore);
        });
        return;
      }
    }

    // -------------------------------------------------
    // CHAPTER 3 - OLTA ZAMANLAMASI
    // -------------------------------------------------

    if (scene == Scene.fishing && cast) {
      fishingTime += dt;

      if (fishingTime >= 3 && fishingTime < 6) {
        bite = true;

        fishingHint = tr('story.fishing.now');
      }

      if (fishingTime >= 6) {
        cast = false;
        bite = false;

        fishingTime = 0;

        fishingHint = tr('story.fishing.missed');
      }
    }

    notifyListeners();
  }
}
