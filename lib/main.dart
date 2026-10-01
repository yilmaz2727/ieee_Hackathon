import 'dart:math';
import 'ui/story_intro.dart';
import 'features/book/book_sheet.dart';
import 'features/chapters/chapters.dart';
import 'features/final_challenge/final_challenge.dart';
import 'features/impact/impact_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'ui/water_scene.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'game/lake_game.dart';
import 'game/story_controller.dart';
import 'localization/app_localizations.dart';
import 'services/certificate.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    /* Play without persistence. */
  }
  await AppLocalizations.instance.loadInitial(prefs);
  runApp(EsmaApp(prefs: prefs));
}

class EsmaApp extends StatelessWidget {
  const EsmaApp({super.key, this.prefs, this.controller});
  final StoryController? controller;
  final SharedPreferences? prefs;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppLocalizations.instance,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: tr('app.title'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'StorySans',
        colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: cream),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.5),
        ),
      ),
      home: StoryScreen(prefs: prefs, controller: controller),
    ),
  );
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, this.prefs, this.controller});
  final StoryController? controller;
  final SharedPreferences? prefs;
  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final StoryController story;
  late final LakeGame game;
  late final Ticker storyTicker;
  Duration? previousFrame;
  final nameController = TextEditingController();
  final nameForm = GlobalKey<FormState>();
  bool exporting = false, lifecyclePaused = false;
  String? exportingLanguage;
  int savedChapter = 0;
  String _savedDifferenceSignature = '';
  Scene lastScene = Scene.home;
  Future<void> saveQueue = Future.value();
  bool get atHome => story.scene == Scene.home;
  @override
  void initState() {
    super.initState();
    story = widget.controller ?? StoryController();
    WidgetsBinding.instance.addObserver(this);
    game = LakeGame(story);
    savedChapter = widget.prefs?.getInt('chapter') ?? 0;

    final savedDifferences =
        widget.prefs?.getStringList('chapter1_difference_found') ?? const <String>[];
    story.differenceFound.addAll(
      savedDifferences
          .map(int.tryParse)
          .whereType<int>()
          .where((index) => index >= 0 && index < 5),
    );
    _savedDifferenceSignature = _differenceSignature();

    story.completed = widget.prefs?.getBool('completed') ?? false;
    story.completedAt = DateTime.tryParse(
      widget.prefs?.getString('completedAt') ?? '',
    );
    if (story.completed) story.pages.addAll([0, 1, 2, 3, 4]);
    story.addListener(onStory);
    AppLocalizations.instance.addListener(_onLanguageChanged);
    storyTicker = createTicker((elapsed) {
      final previous = previousFrame;
      previousFrame = elapsed;
      if (previous != null) {
        story.tick((elapsed - previous).inMicroseconds / 1000000);
      }
    })..start();
  }

  String _differenceSignature() {
    final values = story.differenceFound.toList()..sort();
    return values.join(',');
  }

  void onStory() {
    final current = story.scene;

    // Fark bulmacasında bulunan noktaları ayrıca sakla. Böylece ana menüye
    // dönüldüğünde ve uygulama yeniden açıldığında bulunan farklar korunur.
    final differenceSignature = _differenceSignature();
    if (differenceSignature != _savedDifferenceSignature) {
      _savedDifferenceSignature = differenceSignature;
      final values = story.differenceFound.map((e) => '$e').toList()..sort();
      saveQueue = saveQueue
          .then((_) async {
            await widget.prefs?.setStringList(
              'chapter1_difference_found',
              values,
            );
          })
          .catchError((Object _) {});
    }

    if (lastScene == current) return;

    lastScene = current;

    final chapterOneDifferenceCheckpoint =
        current == Scene.differencePuzzle ||
        (current == Scene.firstResult && story.firstCollected >= 10);

    // Mevcut kayıt sistemi + Chapter 1 içi fark bulmaca checkpoint'i.
    if (current == Scene.intro ||
        current == Scene.underwater ||
        current == Scene.fishing ||
        current == Scene.prevention ||
        current == Scene.success ||
        chapterOneDifferenceCheckpoint ||
        current == Scene.differenceResult) {
      if (current == Scene.differenceResult) {
        savedChapter = 6;
      } else if (chapterOneDifferenceCheckpoint) {
        savedChapter = 5;
      } else {
        savedChapter = current == Scene.prevention ? 4 : story.chapter;
      }

      final chapter = savedChapter,
          complete = story.completed,
          date = story.completedAt?.toIso8601String();

      saveQueue = saveQueue
          .then((_) async {
            await widget.prefs?.setInt('chapter', chapter);
            await widget.prefs?.setBool('completed', complete);

            if (date != null) {
              await widget.prefs?.setString('completedAt', date);
            }
          })
          .catchError((Object _) {});
    }

    // -------------------------------------------------
    // CHAPTER BİTİNCE KİTABI OTOMATİK AÇ
    // -------------------------------------------------

    final int? automaticBookPage;

    // Chapter 1'de atık ayrıştırma başarıyla tamamlandı.
    // Kitabın ilk sayfası fark bulmacasından ÖNCE açılır.
    if (current == Scene.firstResult && story.firstCollected >= 10) {
      automaticBookPage = 0;
    }
    // Chapter 2 tamamlandı.
    else if (current == Scene.protectionResult) {
      automaticBookPage = 1;
    }
    // Chapter 3 tamamlandı.
    else if (current == Scene.discovery) {
      automaticBookPage = 3;
    } else {
      automaticBookPage = null;
    }

    if (automaticBookPage != null) {
      final int pageToOpen = automaticBookPage;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Önce sonuç ekranının çizilmesine izin veriyoruz.
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // Kullanıcı başka ekrana geçtiyse açma.
        if (!mounted || story.scene != current) return;

        await book(initial: pageToOpen);
      });
    }
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    story.fishingHint = tr('story.fishing.initial');
    story.sortingHint = tr('story.sorting.initial');
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    previousFrame = null;
    if (state != AppLifecycleState.resumed && !story.paused) {
      lifecyclePaused = true;
      story.setPaused(true);
    } else if (state == AppLifecycleState.resumed && lifecyclePaused) {
      lifecyclePaused = false;
      story.setPaused(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    story.removeListener(onStory);
    AppLocalizations.instance.removeListener(_onLanguageChanged);
    storyTicker.dispose();
    if (widget.controller == null) story.dispose();
    nameController.dispose();
    super.dispose();
  }

  void next(Scene s) => story.go(s);
  Future<void> book({int? initial}) async {
    story.setPaused(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookSheet(pages: story.pages, initial: initial),
    );
    if (mounted) story.setPaused(false);
  }

  Future<void> pauseMenu() async {
    story.setPaused(true);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        title: Text(tr('pause.title')),
        content: Text(tr('pause.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('common.home')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('common.continue')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      next(Scene.home);
    } else {
      story.setPaused(false);
    }
  }

  Future<void> newGame() async {
    if (savedChapter > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('newGame.title')),
          content: Text(tr('newGame.body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('newGame.restart')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;

    final start = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const StoryIntro()));

    if (!mounted || start != true) return;

    story.startNew();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffe6eddf),
    body: LayoutBuilder(
      builder: (context, outer) {
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: story,
                      child: GameWidget(game: game),
                      builder: (context, gameView) => Stack(
                        fit: StackFit.expand,
                        children: [
                          WaterScene(story: story),
                          if (story.scene == Scene.underwater ||
                              story.scene == Scene.inspection)
                            const ColoredBox(color: Color(0xb5195e69)),
                          if (story.scene == Scene.fishing)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) {
                                    story.castFishingAt(
                                      details.localPosition.dx /
                                          constraints.maxWidth,
                                      details.localPosition.dy /
                                          constraints.maxHeight,
                                    );
                                  },
                                  child: gameView!,
                                );
                              },
                            )
                          else
                            gameView!,
                          if (atHome || story.scene == Scene.intro)
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xdffff9e9),
                                    Colors.transparent,
                                    Color(0x99234331),
                                  ],
                                  stops: [0, .38, 1],
                                ),
                              ),
                            ),
                          SafeArea(
                            child: Column(
                              children: [
                                header(),
                                if (!atHome &&
                                    story.scene != Scene.rewind &&
                                    story.scene != Scene.prevention &&
                                    story.scene != Scene.success &&
                                    story.scene != Scene.reward &&
                                    story.scene != Scene.photo &&
                                    story.scene != Scene.impactMap)
                                  chapterBar(),
                                if (story.scene == Scene.intro ||
                                    story.scene == Scene.cleanupFirst ||
                                    story.scene == Scene.firstResult)
                                  waterStatus(),
                                Expanded(child: body()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget header() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
    child: Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: cream.withValues(alpha: .95),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.water_drop_rounded, size: 20, color: ink),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            tr('brand.name'),
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.bold,
              fontSize: 9,
              letterSpacing: 1.3,
              height: 1.55,
            ),
          ),
        ),
        if (atHome) languageButton(),
        if (!atHome && story.scene != Scene.cleanupFirst)
          circleButton(
            Icons.menu_book_rounded,
            tr('header.book'),
            () => book(),
          ),
        const SizedBox(width: 6),
        if (!atHome && story.scene != Scene.cleanupFirst)
          circleButton(Icons.pause_rounded, tr('header.pause'), pauseMenu),
      ],
    ),
  );
  Widget languageButton() => PopupMenuButton<String>(
    tooltip: AppLocalizations.instance.isTurkish
        ? tr('language.turkish')
        : tr('language.english'),
    onSelected: (code) =>
        AppLocalizations.instance.setLanguage(code, prefs: widget.prefs),
    itemBuilder: (context) => [
      PopupMenuItem(value: 'tr', child: Text(tr('language.turkish'))),
      PopupMenuItem(value: 'en', child: Text(tr('language.english'))),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language_rounded, color: ink, size: 18),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.instance.languageCode.toUpperCase(),
            style: const TextStyle(
              color: ink,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget circleButton(IconData icon, String label, VoidCallback action) =>
      IconButton.filledTonal(
        tooltip: label,
        onPressed: action,
        style: IconButton.styleFrom(
          backgroundColor: cream,
          foregroundColor: ink,
        ),
        icon: Icon(icon, size: 20),
      );
  Widget chapterBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Row(
      children: [
        for (var i = 1; i <= 3; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: story.chapter == i ? ink : cream.withValues(alpha: .90),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$i  ${tr('chapter.short.$i')}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: story.chapter == i ? cream : ink,
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget waterStatus() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cream.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, size: 15, color: ink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr('water.progress', {
                    'percent': (story.clarity * 100).round(),
                  }),
                  style: const TextStyle(fontSize: 10, color: ink),
                ),
              ),
              Text(
                story.clarity >= 1 ? tr('water.clear') : tr('water.murky'),
                style: const TextStyle(fontSize: 10, color: ink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: story.clarity,
            minHeight: 4,
            color: ink,
            backgroundColor: const Color(0xffded8bc),
          ),
        ],
      ),
    ),
  );
  Widget body() => switch (story.scene) {
    Scene.home => home(),
    Scene.intro => ChapterOneIntro(onStart: () => next(Scene.cleanupFirst)),
    Scene.cleanupFirst => ChapterOne(story: story),
    Scene.cleanupSecond => cleanup(),
    Scene.firstResult =>
      story.firstCollected >= 10
          ? storyCard(
              tr('chapter1.result.successTitle', {
                'count': story.firstCollected,
              }),
              tr('chapter1.result.successBody', {
                'score': story.firstCollected * 10,
              }),
              tr('chapter1.result.continue'),
              () => next(Scene.differencePuzzle),
              eyebrow: tr('chapter1.result.successEyebrow'),
              bookPage: 0,
            )
          : storyCard(
              tr('chapter1.result.failTitle', {'count': story.firstCollected}),
              tr('chapter1.result.failBody'),
              tr('common.retry'),
              () => next(Scene.cleanupFirst),
              eyebrow: tr('chapter1.result.failEyebrow'),
            ),
    Scene.differencePuzzle => ChapterOneDifferenceGame(
      story: story,
      onComplete: () => next(Scene.differenceResult),
    ),
    Scene.differenceResult => ChapterOneDifferenceResult(
      onContinue: () => next(Scene.underwater),
    ),
    Scene.underwater => ChapterTwoIntro(onStart: () => next(Scene.protection)),
    Scene.protection => ChapterTwoGame(story: story),
    Scene.protectionResult => storyCard(
      tr('chapter2.result.title'),
      tr('chapter2.result.body', {
        'avoided': story.avoided,
        'swallowed': story.swallowed,
      }),
      tr('chapter2.result.button'),
      () => next(Scene.fishing),
      eyebrow: tr('chapter2.result.eyebrow'),
      bookPage: 1,
    ),
    Scene.fishing => ChapterThreeFishing(story: story),
    Scene.catchWaste => storyCard(
      tr('chapter3.catch.title'),
      tr('chapter3.catch.body', {
        'item': story.catches == 1
            ? tr('chapter3.catch.straw')
            : tr('chapter3.catch.can'),
      }),
      tr('chapter3.catch.button'),
      () => next(Scene.fishing),
      eyebrow: tr('chapter3.catch.eyebrow', {'count': story.catches}),
    ),
    Scene.inspection => ChapterThreeInspection(
      story: story,
      onOpenBook: () => book(initial: 2),
      onComplete: () => next(Scene.discovery),
    ),
    Scene.discovery => storyCard(
      tr('chapter3.discovery.title'),
      tr('chapter3.discovery.body'),
      tr('chapter3.discovery.button'),
      () => next(Scene.rewind),
      eyebrow: tr('chapter3.discovery.eyebrow'),
      bookPage: 3,
    ),
    Scene.rewind => rewind(),
    Scene.prevention => PreventionChallenge(story: story),
    Scene.retry => storyCard(
      tr('legacy.retry.title'),
      tr('legacy.retry.body'),
      tr('legacy.retry.button'),
      () => next(Scene.cleanupSecond),
      eyebrow: tr('legacy.retry.eyebrow'),
    ),
    Scene.success => FinalSuccessScreen(
      story: story,
      onContinue: () => next(Scene.photo),
    ),
    Scene.reward => reward(),
    Scene.photo => ImpactScreen(
      prefs: widget.prefs,
      allowCreate: true,
      onFinish: () => next(Scene.impactMap),
    ),
    Scene.impactMap => ImpactScreen(
      prefs: widget.prefs,
      allowCreate: false,
      onFinish: () => next(story.completed ? Scene.reward : Scene.home),
    ),
  };
  Widget home() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: Column(
              children: [
                const SizedBox(height: 9),
                Text(
                  tr('home.title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'StorySerif',
                    fontSize: 42,
                    height: 1.07,
                    color: Color(0xfffff4d6),
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  tr('home.subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xfffff4d6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Color(0xaa000000),
                        blurRadius: 5,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Paper(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('home.cardTitle'),
                        style: TextStyle(
                          fontFamily: 'StorySerif',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('home.cardBody'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, height: 1.6, color: ink),
                      ),
                      const SizedBox(height: 16),
                      StoryButton(
                        savedChapter > 0
                            ? tr('home.newAdventure')
                            : tr('home.startAdventure'),
                        onPressed: newGame,
                      ),
                      if (savedChapter > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: StoryButton(
                            story.completed
                                ? tr('home.realWorldMission')
                                : tr('home.resume'),
                            secondary: true,
                            icon: story.completed
                                ? Icons.workspace_premium
                                : Icons.play_arrow,
                            onPressed: () => story.completed
                                ? next(Scene.photo)
                                : story.resumeChapter(savedChapter),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => next(Scene.impactMap),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(
                          tr('home.impactMap'),
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('home.motto'),
                  style: TextStyle(color: cream, fontSize: 9, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget cleanup() => LayoutBuilder(
    builder: (context, c) {
      return Stack(
        children: [
          Positioned(
            top: 6,
            left: 20,
            right: 20,
            child: Row(
              children: [
                stat(
                  Icons.timer_outlined,
                  tr('common.seconds', {'count': story.secondsLeft}),
                ),
                const Spacer(),
                stat(
                  Icons.recycling_rounded,
                  story.scene == Scene.cleanupSecond
                      ? '${story.collected} / 10'
                      : tr('cleanup.collected', {'count': story.collected}),
                ),
              ],
            ),
          ),
          for (final w in story.waste)
            Positioned(
              left: w.x * (c.maxWidth - 58),
              top: w.y * (c.maxHeight - 230) + 45,
              child: Semantics(
                button: true,
                label: tr('cleanup.collectTrash'),
                child: GestureDetector(
                  onTap: () {
                    story.selectWaste(w.id);
                    HapticFeedback.selectionClick();
                  },
                  child: Transform.rotate(
                    angle: sin(story.worldTime + w.id) * .18,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: story.selectedWaste?.id == w.id
                            ? gold.withValues(alpha: .8)
                            : Colors.white.withValues(alpha: .15),
                        boxShadow: const [
                          BoxShadow(color: Color(0x225dc5cb), blurRadius: 8),
                        ],
                      ),
                      child: WasteIcon(w.kind),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Paper(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          story.sortingHint,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var bin = 0; bin < 3; bin++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: FilledButton(
                              onPressed: story.selectedWaste == null
                                  ? null
                                  : () => story.sortWaste(bin),
                              style: FilledButton.styleFrom(
                                backgroundColor: [
                                  const Color(0xffcb8a38),
                                  const Color(0xff537f8c),
                                  ink,
                                ][bin],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                [
                                  tr('bins.plastic'),
                                  tr('bins.metal'),
                                  tr('bins.paper'),
                                ][bin],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (story.elapsed / StoryController.roundSeconds)
                          .clamp(0, 1),
                      minHeight: 7,
                      color: ink,
                      backgroundColor: const Color(0xffe2dfcb),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.selectedWaste != null
                        ? tr('cleanup.pausedSorting')
                        : story.scene == Scene.cleanupFirst
                        ? tr('cleanup.current')
                        : tr('cleanup.return'),
                    style: const TextStyle(color: ink, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
  Widget rewind() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Paper(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -story.worldTime * .55,
              child: const Icon(Icons.history_rounded, size: 70, color: ink),
            ),
            const SizedBox(height: 20),
            eyebrow(tr('rewind.eyebrow')),
            const SizedBox(height: 12),
            heading(tr('rewind.title')),
            const SizedBox(height: 14),
            Text(
              tr('rewind.body'),
              textAlign: TextAlign.center,
              style: TextStyle(color: ink, fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 22),
            StoryButton(
              tr('rewind.start'),
              onPressed: () => next(Scene.prevention),
              icon: Icons.replay_rounded,
            ),
          ],
        ),
      ),
    ),
  );
  Widget reward() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Paper(
      child: Column(
        children: [
          const Badge(size: 120),
          heading(tr('reward.title')),
          const SizedBox(height: 8),
          Text(tr('reward.badge'), style: const TextStyle(color: ink)),
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameController,
            builder: (context, value, _) => Text(
              value.text.trim().isEmpty
                  ? tr('reward.yourName')
                  : value.text.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'StorySerif',
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: ink,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: nameForm,
            child: TextFormField(
              controller: nameController,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: tr('reward.nameLabel'),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? tr('reward.nameValidation')
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('reward.namePrivacy'),
            style: TextStyle(color: ink, fontSize: 10, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          StoryButton(
            'Türkçe PDF',
            icon: Icons.download_rounded,
            loading: exporting && exportingLanguage == 'tr',
            onPressed: exporting ? null : () => export(languageCode: 'tr'),
          ),
          const SizedBox(height: 10),
          StoryButton(
            'English PDF',
            secondary: true,
            icon: Icons.download_rounded,
            loading: exporting && exportingLanguage == 'en',
            onPressed: exporting ? null : () => export(languageCode: 'en'),
          ),
          const SizedBox(height: 10),
          StoryButton(
            tr('common.home'),
            secondary: true,
            icon: Icons.home_outlined,
            onPressed: () => next(Scene.home),
          ),
        ],
      ),
    ),
  );
  Future<void> export({String? languageCode}) async {
    if (exporting) return;
    if (!(nameForm.currentState?.validate() ?? false)) return;

    final selectedLanguage =
        languageCode ?? AppLocalizations.instance.languageCode;

    final name = nameController.text.trim();
    final date = story.completedAt ?? DateTime.now();

    setState(() {
      exporting = true;
      exportingLanguage = selectedLanguage;
    });

    try {
      await CertificateService.download(
        name,
        date,
        languageCode: selectedLanguage,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('reward.pdfError'))));
      }
    } finally {
      if (mounted) {
        setState(() {
          exporting = false;
          exportingLanguage = null;
        });
      }
    }
  }

  Widget storyCard(
    String title,
    String text,
    String button,
    VoidCallback action, {
    required String eyebrow,
    int? bookPage,
  }) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            height: min(190, c.maxHeight * .31),
            child: Transform.translate(
              offset: Offset(0, sin(story.worldTime * 1.5) * 3),
              child: Image.asset('assets/images/esma.png', fit: BoxFit.contain),
            ),
          ),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 10),
                heading(title),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
                if (bookPage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton.icon(
                      onPressed: () => book(initial: bookPage),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: Text(tr('book.open')),
                    ),
                  ),
                const SizedBox(height: 14),
                StoryButton(button, onPressed: action),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget stat(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: ink, size: 19),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: ink,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'StorySerif',
      fontWeight: FontWeight.bold,
      fontSize: 25,
      color: ink,
      height: 1.22,
    ),
  );
  Widget eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 9,
      letterSpacing: 1.3,
      fontWeight: FontWeight.bold,
      color: ink,
    ),
  );
}
