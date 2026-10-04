import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../audio_manager.dart';
import '../../../game/story_controller.dart';
import '../../../localization/app_localizations.dart';
import '../../../ui/widgets.dart';

/// Five sick fish live among ten healthy fish. All progress belongs to the
/// story controller so opening the book or returning home cannot reset it.
class ChapterTwoHealingGame extends StatefulWidget {
  const ChapterTwoHealingGame({
    super.key,
    required this.story,
    required this.onComplete,
  });

  final StoryController story;
  final VoidCallback onComplete;

  @override
  State<ChapterTwoHealingGame> createState() => _ChapterTwoHealingGameState();
}

class _ChapterTwoHealingGameState extends State<ChapterTwoHealingGame> {
  Timer? _toastTimer;
  String? _toastKey;

  void _toast(String key) {
    _toastTimer?.cancel();
    setState(() => _toastKey = key);
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _toastKey = null);
    });
  }

  void _tap(int index) {
    final story = widget.story;
    if (story.paused || story.scene != Scene.fishHealing) return;
    final audio = AudioManager.instance;
    if (!story.healFish(index)) {
      audio.playEffect('ch1_yanlis_kutu.mp3');
      _toast('chapter2.healing.healthy');
    } else if (story.healingTaps[index] == StoryController.healingTapTarget) {
      // Son balıkta iki uzun ses üst üste binmesin: final_heal yerine
      // yalnızca bitiş jingle'ı çalar, ardından menü müziği gelir.
      if (story.healingComplete) {
        audio.playJingleThenBGM('tum_balik_heal.mp3', 'ana_menu_bg.mp3');
      } else {
        audio.playEffect('final_heal.mp3');
      }
      _toast('chapter2.healing.thanks');
    } else {
      audio.playEffect('dogru_balik_heal.mp3');
    }
  }

  @override
  void initState() {
    super.initState();
    // playBGM önce çalan müziği durdurur.
    AudioManager.instance.playBGM('balik_heal_bg.mp3');
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.story,
    builder: (context, _) {
      final story = widget.story;
      return Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                child: Paper(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('chapter2.healing.title'),
                              style: const TextStyle(
                                color: ink,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              tr('chapter2.healing.counter', {
                                'count': story.healedFish,
                              }),
                              key: const ValueKey('healing-counter'),
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        tr('chapter2.healing.instructions'),
                        style: const TextStyle(
                          color: ink,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Keep all fifteen targets in three columns and five rows.
                    // Short landscape windows can scroll instead of shrinking
                    // the fish below a usable touch target.
                    final height = max(300.0, constraints.maxHeight);
                    return SingleChildScrollView(
                      child: SizedBox(
                        height: height,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              for (var row = 0; row < 5; row++)
                                Expanded(
                                  child: Row(
                                    children: [
                                      for (var col = 0; col < 3; col++)
                                        Expanded(child: _fish(row * 3 + col)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Column(
                  children: [
                    if (story.healingComplete) ...[
                      Text(
                        tr('chapter2.healing.done'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StoryButton(
                        tr('chapter2.healing.continue'),
                        onPressed: widget.onComplete,
                      ),
                    ] else
                      Text(
                        tr('chapter2.healing.note'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: cream, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_toastKey != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: story.healingComplete ? 96 : 40,
              child: IgnorePointer(
                child: Center(
                  child: Material(
                    elevation: 6,
                    color: cream,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          tr(_toastKey!),
                          key: const ValueKey('fish-toast'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _fish(int index) {
    final story = widget.story;
    if (index >= story.healingTaps.length) return const SizedBox.shrink();
    final taps = story.healingTaps[index];
    final recovery = taps < 0 ? 1.0 : taps / StoryController.healingTapTarget;
    return Semantics(
      button: true,
      label: tr('chapter2.healing.fishLabel', {'number': index + 1}),
      value: recovery == 1
          ? tr('chapter2.healing.healthyLabel')
          : tr('chapter2.healing.sickLabel', {'count': taps}),
      child: GestureDetector(
        key: ValueKey('healing-fish-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(index),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('fish-recovery-$index'),
            tween: Tween(begin: recovery, end: recovery),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              painter: HealingFishPainter(
                index: index,
                recovery: value,
                time: story.worldTime,
                treatment: taps,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vector fish share a similar silhouette size, but have individual palettes,
/// three tail shapes, three dorsal fins and five decorative patterns.
class HealingFishPainter extends CustomPainter {
  const HealingFishPainter({
    required this.index,
    required this.recovery,
    required this.time,
    required this.treatment,
  });

  final int index;
  final double recovery, time;
  final int treatment;

  static const palettes = [
    Color(0xffedaa59),
    Color(0xff5fc7de),
    Color(0xffd78fca),
    Color(0xfff28d83),
    Color(0xff8999e1),
    Color(0xffffcd70),
    Color(0xff69c9c2),
    Color(0xffb5a1ef),
    Color(0xffe6a6b2),
    Color(0xff88bde6),
    Color(0xffefb87f),
    Color(0xffd795e5),
    Color(0xff70c6ed),
    Color(0xffe78eac),
    Color(0xffb8beec),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / 126, size.height / 89);
    canvas.save();
    canvas.translate(
      size.width / 2,
      size.height / 2 + sin(time * 1.8 + index * 1.7) * 2,
    );
    canvas.scale(scale);
    if (index.isOdd) canvas.scale(-1, 1);

    final sick = 1 - recovery;
    final color = Color.lerp(
      palettes[index % palettes.length],
      const Color(0xff789d39),
      sick * .78,
    )!;
    final finColor = Color.lerp(color, const Color(0xff374e68), .22)!;
    final outline = Paint()
      ..color = const Color(0xff294f53)
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7;
    void drawPart(Path path, Color fill) {
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, outline);
    }

    final wave = sin(time * 5 + index) * 3;
    final tail = Path()..moveTo(-29, 0);
    switch (index % 3) {
      case 0:
        tail
          ..lineTo(-55, -23 + wave)
          ..quadraticBezierTo(-47, 0, -55, 23 + wave)
          ..close();
        break;
      case 1:
        tail
          ..quadraticBezierTo(-68, -32 + wave, -53, 0)
          ..quadraticBezierTo(-66, 30 + wave, -29, 0)
          ..close();
        break;
      default:
        tail
          ..lineTo(-58, -16 + wave)
          ..lineTo(-49, wave)
          ..lineTo(-58, 17 + wave)
          ..close();
    }
    drawPart(tail, finColor);
    final dorsal = Path()..moveTo(-22, -14);
    switch ((index ~/ 3) % 3) {
      case 0:
        dorsal
          ..lineTo(-8, -36)
          ..lineTo(12, -18)
          ..close();
        break;
      case 1:
        dorsal
          ..quadraticBezierTo(-5, -42, 18, -16)
          ..close();
        break;
      default:
        dorsal
          ..lineTo(-20, -29)
          ..lineTo(-10, -23)
          ..lineTo(-1, -33)
          ..lineTo(7, -21)
          ..lineTo(16, -27)
          ..lineTo(23, -12)
          ..close();
    }
    drawPart(dorsal, finColor);
    drawPart(
      Path()
        ..moveTo(-9, 14)
        ..lineTo(3, 31)
        ..quadraticBezierTo(15, 30, 22, 14)
        ..close(),
      finColor,
    );
    final body = Path()
      ..moveTo(42, 0)
      ..cubicTo(35, -29, -26, -31, -38, 0)
      ..cubicTo(-26, 30, 35, 29, 42, 0)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, .26)!,
            color,
            Color.lerp(color, finColor, .45)!,
          ],
        ).createShader(const Rect.fromLTWH(-40, -25, 84, 50)),
    );
    canvas.save();
    canvas.clipPath(body);
    final pattern = Paint()..color = Colors.white.withValues(alpha: .3);
    if (index % 5 < 2) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-27.0 + i * 13, -24),
          Offset(-20.0 + i * 13, 24),
          pattern..strokeWidth = index.isEven ? 6 : 3,
        );
      }
    } else if (index % 5 < 4) {
      for (var i = 0; i < 7; i++) {
        canvas.drawCircle(
          Offset(-24.0 + (i % 4) * 11, -10.0 + (i ~/ 4) * 18),
          3,
          pattern,
        );
      }
    } else {
      canvas.drawOval(const Rect.fromLTWH(-33, 1, 63, 20), pattern);
    }
    // Semi-transparent green veil, progressively removed by treatment.
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xff789f30).withValues(alpha: sick * .23),
    );
    canvas.restore();
    canvas.drawPath(body, outline);
    drawPart(
      Path()
        ..moveTo(-1, 0)
        ..quadraticBezierTo(-22, -5, -13, 15 + wave / 2)
        ..quadraticBezierTo(-2, 18, 4, 5)
        ..close(),
      Color.lerp(color, Colors.white, .32)!,
    );

    // Eye and lid gradually open, worried brow relaxes into a happy face.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(23, -8),
        width: 12,
        height: 12 - sick * 4,
      ),
      Paint()..color = const Color(0xfffffbe9),
    );
    canvas.drawCircle(
      const Offset(25, -8),
      2.9,
      Paint()..color = const Color(0xff244443),
    );
    canvas.drawCircle(const Offset(26, -9), 1, Paint()..color = Colors.white);
    canvas.drawLine(Offset(18, -17 + sick * 4), const Offset(28, -17), outline);
    final mouth = Path()
      ..moveTo(26, 5)
      ..quadraticBezierTo(32, 5 + (recovery * 2 - 1) * 9, 38, 5);
    canvas.drawPath(mouth, outline);
    if (recovery > .5) {
      canvas.drawOval(
        const Rect.fromLTWH(16, 2, 9, 5),
        Paint()
          ..color = const Color(0xffef8986).withValues(alpha: recovery * .6),
      );
    }
    canvas.restore();

    // Treatment dots belong only to fish that were sick; a completed fish
    // retains three dots to make the outcome visible without relying on color.
    if (treatment > 0) {
      final y = size.height - 5;
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(size.width / 2 + (i - 1) * 10, y),
          3,
          Paint()
            ..color = i < treatment
                ? const Color(0xffffe19d)
                : const Color(0x66fff8e5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant HealingFishPainter oldDelegate) =>
      index != oldDelegate.index ||
      recovery != oldDelegate.recovery ||
      time != oldDelegate.time ||
      treatment != oldDelegate.treatment;
}
