import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../audio_manager.dart';
import '../../../game/story_controller.dart';
import '../../../localization/app_localizations.dart';
import '../../../ui/widgets.dart';

class ChapterOne extends StatefulWidget {
  const ChapterOne({super.key, required this.story});

  final StoryController story;

  @override
  State<ChapterOne> createState() => _ChapterOneState();
}

class _ChapterOneState extends State<ChapterOne> {
  final clock = Stopwatch();
  final random = Random();
  final items = <Waste>[];

  late final Timer timer;
  int nextId = 0;
  int collected = 0;
  double previousTime = 0;
  double spawnTime = 0;
  bool finished = false;
  String message = tr('chapter1.message.initial');

  double get seconds => clock.elapsedMilliseconds / 1000;
  int get remaining => max(0, (20 - seconds).ceil());

  @override
  void initState() {
    super.initState();

    // "Temizliğe başlayalım" / "Tekrar oyna" ile oyun açılır: hikâye müziği
    // yerini oyun müziğine bırakır.
    AudioManager.instance.playBGM('ch1_oyun_bg.mp3');

    widget.story.waterClarity[0] = 0;
    widget.story.visibleClarity[0] = 0;
    widget.story.firstCollected = 0;

    for (var i = 0; i < 5; i++) {
      spawn(initial: true);
    }

    clock.start();

    timer = Timer.periodic(const Duration(milliseconds: 33), (_) => update());
  }

  void spawn({bool initial = false}) {
    items.add(
      Waste(
        nextId++,
        .08 + random.nextDouble() * .84,
        initial ? .12 + random.nextDouble() * .34 : .02,
        random.nextInt(3),
        .078 + random.nextDouble() * .030,
      ),
    );
  }

  void update() {
    if (!mounted || finished) return;

    if (seconds >= 20) {
      finish();
      return;
    }

    final dt = (seconds - previousTime).clamp(0.0, .1);
    previousTime = seconds;

    setState(() {
      spawnTime += dt;

      if (spawnTime >= 1.05) {
        spawnTime -= 1.05;
        spawn();
      }

      for (final item in items) {
        // Her parça akıntıyla farklı bir kıyı noktasına yaklaşır. Sabit sıra
        // yerine küçük salınımlar kullanmak hareketi daha doğal gösterir.
        final shoreY = .76 + ((sin(item.id * 1.73) + 1) / 2) * .12;
        final shoreX = .08 + ((sin(item.id * 2.41 + .7) + 1) / 2) * .80;

        if (item.y < shoreY) {
          item.y = min(shoreY, item.y + item.speed * dt);

          final approach = ((item.y - .28) / .48).clamp(0.0, 1.0);
          final current = sin(seconds * 1.05 + item.id * 1.4) * .016;
          final ripple = cos(seconds * .72 + item.id * .8) * .006;

          item.x += (shoreX - item.x) * dt * (.35 + approach * 1.15);
          item.x += (current + ripple) * dt * (1 - approach * .65);
          item.x = item.x.clamp(.02, .98);
        } else {
          item.x += (shoreX - item.x) * min(1.0, dt * 2.2);
        }
      }
    });
  }

  void drop(int id, int bin) {
    if (!mounted || finished) return;

    // Süre dolduktan sonraki bırakmalar puan kazandırmaz.
    if (seconds >= 20) {
      finish();
      return;
    }

    final matches = items.where((item) => item.id == id);
    if (matches.isEmpty) return;

    final item = matches.first;

    // Efektler ayrı oyuncularda çalar; oyun müziği kesilmez.
    AudioManager.instance.playEffect(
      item.kind == bin ? 'ch1_dogru_kutu.mp3' : 'ch1_yanlis_kutu.mp3',
    );

    setState(() {
      if (item.kind != bin) {
        message = tr('chapter1.message.wrongBin');
        return;
      }

      items.remove(item);
      collected++;
      message = collected >= 10
          ? tr('chapter1.message.targetDone')
          : tr('chapter1.message.target');
      widget.story.waterClarity[0] = (collected / 10).clamp(0.0, 1.0);
    });
  }

  void finish() {
    if (finished || !mounted) return;

    finished = true;
    timer.cancel();
    clock.stop();

    // Oyun müziği durur, sonuç sesi çalar, ardından menü müziği gelir.
    AudioManager.instance.playJingleThenBGM(
      collected >= 10 ? 'kazandin.mp3' : 'kaybettin.mp3',
      'ana_menu_bg.mp3',
    );

    widget.story.firstCollected = collected;
    widget.story.firstIncoming = nextId;
    widget.story.collected = collected;
    widget.story.go(Scene.firstResult);
  }

  @override
  void dispose() {
    timer.cancel();
    clock.stop();
    super.dispose();
  }

  Widget wastePicture(int kind) =>
      SizedBox(width: 48, height: 48, child: WasteIcon(kind));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaHeight = max(40.0, constraints.maxHeight - 200);

        return Stack(
          children: [
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Paper(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '⏱ ${tr('common.seconds', {'count': remaining})}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    Text(
                      tr('chapter1.score', {'score': collected * 10}),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            for (final item in items)
              Positioned(
                key: ValueKey(item.id),
                left: item.x * max(0.0, constraints.maxWidth - 48),
                top: 62 + item.y * areaHeight,
                child: Draggable<int>(
                  data: item.id,
                  maxSimultaneousDrags: 1,
                  onDragStarted: () => AudioManager.instance.playEffect(
                    'ch1_nesne_tutma_effect.mp3',
                  ),
                  feedback: Material(
                    color: Colors.transparent,
                    child: wastePicture(item.kind),
                  ),
                  childWhenDragging: const SizedBox(width: 48, height: 48),
                  child: Transform.rotate(
                    angle: item.y < .78 ? sin(seconds * 2 + item.id) * .15 : 0,
                    child: wastePicture(item.kind),
                  ),
                ),
              ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ink, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var bin = 0; bin < 3; bin++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: DragTarget<int>(
                              onWillAcceptWithDetails: (_) => !finished,
                              onAcceptWithDetails: (details) {
                                drop(details.data, bin);
                              },
                              builder: (context, candidates, rejected) {
                                final baseColor = [
                                  const Color(0xffc88635),
                                  const Color(0xff537f8c),
                                  ink,
                                ][bin];
                                final active = candidates.isNotEmpty;
                                final bodyColor = active ? gold : baseColor;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  height: 92,
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Geri dönüşüm kutusunun kapak kısmı.
                                      Positioned(
                                        top: 0,
                                        left: 7,
                                        right: 7,
                                        child: Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Color.lerp(
                                              bodyColor,
                                              Colors.black,
                                              .12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            border: Border.all(
                                              color: cream,
                                              width: active ? 2.5 : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 28,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: cream.withValues(
                                                  alpha: .9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Kutunun gövdesi.
                                      Positioned(
                                        top: 13,
                                        left: 11,
                                        right: 11,
                                        bottom: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: bodyColor,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(7),
                                                  topRight: Radius.circular(7),
                                                  bottomLeft: Radius.circular(
                                                    14,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    14,
                                                  ),
                                                ),
                                            border: Border.all(
                                              color: cream,
                                              width: active ? 3 : 1.4,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x26000000),
                                                blurRadius: 5,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.recycling_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                [
                                                  tr('bins.plastic'),
                                                  tr('bins.metal'),
                                                  tr('bins.paper'),
                                                ][bin],
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ChapterOneIntro extends StatelessWidget {
  const ChapterOneIntro({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Paper(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoryEyebrow(tr('chapter1.eyebrow')),
            const SizedBox(height: 8),
            StoryHeading(tr('chapter1.title')),
            const SizedBox(height: 10),
            Text(
              tr('chapter1.story'),
              style: TextStyle(color: ink, fontSize: 14, height: 1.65),
            ),
            const SizedBox(height: 14),
            _HintRow(
              icon: Icons.touch_app_rounded,
              text: tr('chapter1.instructions'),
            ),
            const SizedBox(height: 16),
            StoryButton(tr('chapter1.start'), onPressed: onStart),
          ],
        ),
      ),
    ),
  );
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: ink, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: ink, fontSize: 11, height: 1.5),
        ),
      ),
    ],
  );
}
