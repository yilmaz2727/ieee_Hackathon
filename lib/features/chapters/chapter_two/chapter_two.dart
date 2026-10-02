import 'dart:math';

import 'package:flutter/material.dart';

import '../../../audio_manager.dart';
import '../../../game/story_controller.dart';
import '../../../localization/app_localizations.dart';
//import '../../../ui/water_scene.dart';
import '../../../ui/widgets.dart';

class ChapterTwoIntro extends StatefulWidget {
  const ChapterTwoIntro({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<ChapterTwoIntro> createState() => _ChapterTwoIntroState();
}

class _ChapterTwoIntroState extends State<ChapterTwoIntro> {
  @override
  void initState() {
    super.initState();
    // CH2 hikâye ekranı: önceki müzik (menü) yerini hikâye müziğine bırakır.
    AudioManager.instance.playBGM('chapter_hikaye_bg.mp3');
  }

  void _start() {
    // Hikâye müziği durur, oyun müziği başlar.
    AudioManager.instance.playBGM('ch2_oyun_bg.mp3');
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 12),
      StoryPill(tr('chapter2.eyebrowTop')),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Paper(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryEyebrow(tr('chapter2.eyebrow')),
              const SizedBox(height: 8),
              StoryHeading(tr('chapter2.title')),
              const SizedBox(height: 12),
              Text(
                tr('chapter2.intro'),
                style: TextStyle(color: ink, height: 1.6, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                tr('chapter2.note'),
                style: TextStyle(color: ink, fontSize: 9),
              ),
              const SizedBox(height: 18),
              StoryButton(tr('chapter2.start'), onPressed: _start),
            ],
          ),
        ),
      ),
    ],
  );
}

class ChapterTwoGame extends StatelessWidget {
  const ChapterTwoGame({super.key, required this.story});

  final StoryController story;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxWidth < 600 || c.maxHeight < 500;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                StatChip(
                  Icons.timer_outlined,
                  tr('common.seconds', {'count': story.secondsLeft}),
                ),
                const Spacer(),
                StatChip(
                  Icons.warning_amber_rounded,
                  tr('chapter2.swallowedShort', {'count': story.swallowed}),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, arena) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    story.moveFish(d.localPosition.dx / arena.maxWidth),
                onPanUpdate: (d) =>
                    story.moveFish(d.localPosition.dx / arena.maxWidth),
                child: Stack(
                  children: [
                    for (final piece in story.waste)
                      Positioned(
                        left: piece.x * arena.maxWidth - 15,
                        top: piece.y * arena.maxHeight,
                        child: Transform.rotate(
                          angle: sin(story.worldTime * 2 + piece.id) * .35,
                          child: MicroplasticIcon(piece.kind, size: 30),
                        ),
                      ),
                    Positioned(
                      left: story.fishX * arena.maxWidth - 55,
                      top: arena.maxHeight * .72 - 25,
                      child: const SizedBox(
                        width: 110,
                        height: 66,
                        child: FishPicture(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 18,
              compact ? 6 : 18,
              compact ? 10 : 18,
              compact ? 8 : 18,
            ),
            child: Paper(
              padding: EdgeInsets.all(compact ? 10 : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('chapter2.gameTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 12 : 14,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 7),
                  Text(
                    tr('chapter2.instructions'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: compact ? 10 : 11,
                      height: compact ? 1.25 : 1.5,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  LinearProgressIndicator(
                    value: (story.elapsed / StoryController.protectionSeconds)
                        .clamp(0.0, 1.0),
                    minHeight: compact ? 3 : 4,
                    color: ink,
                    backgroundColor: const Color(0xffdfdfc4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ); // Column
    }, // builder
  ); // LayoutBuilder
}
