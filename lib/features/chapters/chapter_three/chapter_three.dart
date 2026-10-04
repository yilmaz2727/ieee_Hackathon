import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../audio_manager.dart';
import '../../../game/story_controller.dart';
import '../../../localization/app_localizations.dart';
import '../../../ui/widgets.dart';

class ChapterThreeFishing extends StatefulWidget {
  const ChapterThreeFishing({super.key, required this.story});

  final StoryController story;

  @override
  State<ChapterThreeFishing> createState() => _ChapterThreeFishingState();
}

class _ChapterThreeFishingState extends State<ChapterThreeFishing>
    with SingleTickerProviderStateMixin {
  // "Oltayı çek" butonu bu süre boyunca basılı tutulmalı.
  static const _holdDuration = Duration(seconds: 3);

  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: _holdDuration,
  )..addStatusListener(_onHoldStatus);

  bool _wasBite = false;
  bool _pulled = false;

  StoryController get story => widget.story;

  @override
  void initState() {
    super.initState();
    _wasBite = story.bite;
    story.addListener(_onStory);
  }

  @override
  void didUpdateWidget(covariant ChapterThreeFishing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story != widget.story) {
      oldWidget.story.removeListener(_onStory);
      widget.story.addListener(_onStory);
    }
  }

  @override
  void dispose() {
    story.removeListener(_onStory);
    story.setReeling(false);
    // Basılı tutarken ekrandan çıkılırsa (ör. ana menü) çekiş sesi susar.
    if (_hold.isAnimating) {
      AudioManager.instance.stopEffect('oltayi_cek.mp3');
    }
    _hold.dispose();
    super.dispose();
  }

  void _onStory() {
    // Şamandıra battı, buton aktifleşti: hafif titreşim.
    if (story.bite && !_wasBite && !story.paused) {
      HapticFeedback.vibrate();
    }
    _wasBite = story.bite;

    // Kitap/duraklatma açılırsa ya da balık kaçarsa bar sıfırlanır.
    if ((story.paused || !story.bite) && _hold.value > 0) _cancelHold();
  }

  void _startHold() {
    if (!story.bite || story.paused || _pulled) return;
    story.setReeling(true);
    // Oyuncu oltayı sardığını hissetsin: çekiş sesi bar dolmaya başlarken.
    AudioManager.instance.playEffect('oltayi_cek.mp3');
    _hold.forward(from: 0);
  }

  // Parmak 3 saniye dolmadan kalkarsa bar sıfırlanır, çekiş sesi susar.
  void _cancelHold() {
    if (_pulled || (_hold.value == 0 && !_hold.isAnimating)) return;
    story.setReeling(false);
    AudioManager.instance.stopEffect('oltayi_cek.mp3');
    _hold
      ..stop()
      ..value = 0;
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _pulled) return;
    _pulled = true;
    // Çekiş sesinin kalan kısmı sonuç sesiyle (çöp/balık) çakışmasın.
    AudioManager.instance.stopEffect('oltayi_cek.mp3');
    story.fishingAction();
    // Çekiş bir sebeple gerçekleşmediyse buton yeniden kullanılabilsin.
    if (mounted && story.scene == Scene.fishing) {
      _pulled = false;
      _hold.value = 0;
    }
  }

  Widget _holdButton() => Semantics(
    button: true,
    label: tr('chapter3.holdToPull'),
    child: Listener(
      onPointerDown: (_) => _startHold(),
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _hold,
          builder: (context, _) => Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: ink)),
              // Soldan sağa dolan bar.
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _hold.value,
                  child: ColoredBox(color: gold.withValues(alpha: .55)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _hold.value > 0
                            ? tr('chapter3.holding')
                            : tr('chapter3.holdToPull'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cream,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.phishing_rounded, color: cream, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 12),
      StoryPill(tr('chapter3.eyebrow')),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Paper(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryHeading(
                story.bite ? tr('chapter3.pullNow') : tr('chapter3.waitTitle'),
              ),
              const SizedBox(height: 10),
              Text(
                story.fishingHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ink, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (story.bite)
                SizedBox(width: double.infinity, child: _holdButton())
              else
                StoryButton(
                  !story.cast ? tr('chapter3.cast') : tr('chapter3.waitFloat'),
                  icon: Icons.phishing_rounded,
                  // Olta sesi castFishingAt'te çalar; tıklama sesi üst üste
                  // binmesin.
                  sound: null,
                  onPressed: story.cast
                      ? null
                      : () =>
                            story.castFishingAt(story.fishingX, story.fishingY),
                ),
              const SizedBox(height: 8),
              Text(
                tr('chapter3.lagoonNote'),
                style: TextStyle(color: ink, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class ChapterThreeInspection extends StatelessWidget {
  const ChapterThreeInspection({
    super.key,
    required this.story,
    required this.onOpenBook,
    required this.onComplete,
  });

  final StoryController story;
  final VoidCallback onOpenBook;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        StoryPill(tr('chapter3.scanEyebrow')),
        const SizedBox(height: 15),
        Text(
          tr('chapter3.scanTitle'),
          style: TextStyle(
            fontFamily: 'StorySerif',
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: cream,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          tr('chapter3.scanNote'),
          style: TextStyle(color: cream, fontSize: 12),
        ),
        // Balığa yapılan her dokunuşta tıklama sesi (izlere dokunuş dahil).
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) =>
              AudioManager.instance.playEffect(TapDownButton.clickSound),
          child: SizedBox(
            height: 240,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  const Positioned.fill(child: FishPicture(scan: true)),
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: c.maxWidth * (.40 + i * .08),
                      top: 115 + (i == 1 ? 12 : 0),
                      child: Semantics(
                        button: true,
                        label: tr('chapter3.microplastic', {'index': i + 1}),
                        child: GestureDetector(
                          onTap: () => story.discover(i),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: story.found.contains(i)
                                  ? gold
                                  : coral.withValues(alpha: .4),
                              border: Border.all(color: cream, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: gold.withValues(alpha: .5),
                                  blurRadius: 12 + sin(story.worldTime * 3) * 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              story.found.contains(i)
                                  ? Icons.check
                                  : i == 1
                                  ? Icons.gesture
                                  : Icons.scatter_plot,
                              size: 18,
                              color: story.found.contains(i) ? ink : cream,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryEyebrow(tr('chapter3.found', {'count': story.found.length})),
              const SizedBox(height: 10),
              Text(
                story.lastDiscovery ?? tr('chapter3.quote'),
                style: const TextStyle(color: ink, height: 1.6, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TapDownButton(
                onTap: onOpenBook,
                sound: TapDownButton.bookSound,
                builder: (pressed) => TextButton.icon(
                  onPressed: pressed,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(tr('chapter3.research')),
                ),
              ),
              const SizedBox(height: 8),
              StoryButton(
                tr('chapter3.complete'),
                onPressed: story.found.length == 3 ? onComplete : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
