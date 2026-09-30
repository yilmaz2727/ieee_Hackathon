import 'dart:math';

import 'package:flutter/material.dart';

import '../game/story_controller.dart';

/// Pollution is a separate water-only layer: banks and sky keep their colours.
class WaterScene extends StatelessWidget {
  const WaterScene({super.key, required this.story});
  final StoryController story;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(story.backgroundAsset, fit: BoxFit.cover),
      if (story.scene == Scene.intro ||
          story.scene == Scene.cleanupFirst ||
          story.scene == Scene.firstResult)
        IgnorePointer(
          child: CustomPaint(
            painter: _PollutionPainter(
              story.chapter,
              story.visibleClarity[story.chapter - 1],
              story.worldTime,
            ),
          ),
        ),
    ],
  );
}

class _PollutionPainter extends CustomPainter {
  const _PollutionPainter(this.chapter, this.clarity, this.time);

  final int chapter;
  final double clarity;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final dirt = (1 - clarity).clamp(0.0, 1.0);
    if (dirt < .002) return;

    final bounds = Offset.zero & size;

    // Kirlilik tüm arka planı kaplar.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(111, 109, 65, dirt * .62),
            Color.fromRGBO(106, 91, 57, dirt * .74),
            Color.fromRGBO(126, 120, 71, dirt * .62),
          ],
        ).createShader(bounds),
    );

    for (var i = 0; i < 24; i++) {
      final x =
          (sin(i * 73.1) * .5 + .5) * size.width + sin(time * .2 + i) * 10;
      final y = ((i * .137) % 1) * size.height;

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: size.width * .4,
          height: 45,
        ),
        Paint()
          ..color = Color.fromRGBO(74, 77, 43, dirt * .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  @override
  bool shouldRepaint(_PollutionPainter old) =>
      clarity != old.clarity || time != old.time;
}

class CollectionNetPainter extends CustomPainter {
  const CollectionNetPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xffe9dfb7)
      ..strokeWidth = 1.5;
    for (var x = 0.0; x <= size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x + 14, size.height), line);
      canvas.drawLine(Offset(x, 0), Offset(x - 14, size.height), line);
    }
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, 0),
      Paint()
        ..color = const Color(0xff214e43)
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(CollectionNetPainter old) => false;
}
