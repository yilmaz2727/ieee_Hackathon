import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';

import 'story_controller.dart';

// Rendering only. Flutter Ticker advances the story before build/layout.
class LakeGame extends FlameGame {
  LakeGame(this.story);
  final StoryController story;
  @override
  Color backgroundColor() => const Color(0x00000000);
  @override
  void update(double dt) {
    super.update(dt);
    // Flame may call update(0) during layout; never notify Flutter here.
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final t = story.worldTime;
    if (story.scene == Scene.intro) {
      final breaking = story.scene == Scene.underwater;
      final phase = (t % 9) / 9;
      canvas.save();
      canvas.translate(size.x * .55, size.y * .38);
      canvas.rotate(sin(t * .5) * .15);
      final red = Paint()
        ..color = const Color(0xffe88770)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (!breaking || phase < .4) {
        canvas.drawPath(
          Path()
            ..moveTo(-15, 38)
            ..lineTo(-15, -20)
            ..lineTo(18, -38),
          red,
        );
      } else {
        for (var i = 0; i < 7; i++) {
          final spread = (phase - .4) * 85;
          final x = sin(i * 9.0) * spread;
          final y = -30 + i * 10.0 + cos(i * 3.0) * spread * .5;
          canvas.drawLine(Offset(x, y), Offset(x + 5, y + 6), red);
        }
      }
      canvas.restore();
    }
    // Subtle moving glints keep the illustrated water alive.
    for (var i = 0; i < 18; i++) {
      final x = (sin(i * 19.2) * .5 + .5) * size.x;
      final y = (.22 + (i % 7) * .074) * size.y;
      final a = (sin(t * 1.6 + i) + 1) * .09;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + sin(t + i) * 5, y),
          width: (12 + i % 4 * 5).toDouble(),
          height: 2,
        ),
        Paint()..color = Color.fromRGBO(255, 255, 239, a),
      );
    }
    if (story.scene == Scene.fishing) {
      for (var i = 0; i < 3; i++) {
        final x = ((t * .04 + i * .32) % 1) * size.x;
        drawFish(
          canvas,
          Offset(x, size.y * (.4 + i * .09)),
          48,
          const Color(0xffdcac61),
          .48,
        );
      }
      if (story.cast) {
        final center = Offset(
          size.x * story.fishingX,
          size.y *
              (story.fishingY +
                  (story.bite ? sin(t * 22) * .015 : sin(t * 2) * .003)),
        );
        final rodPoint = Offset(size.x * .88, size.y * .83);

        final controlPoint = Offset(
          (rodPoint.dx + center.dx) / 2,
          min(rodPoint.dy, center.dy) - size.y * .18,
        );

        final line = Path()
          ..moveTo(rodPoint.dx, rodPoint.dy)
          ..quadraticBezierTo(
            controlPoint.dx,
            controlPoint.dy,
            center.dx,
            center.dy,
          );
        canvas.drawPath(
          line,
          Paint()
            ..color = const Color(0xfff3eedc)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        for (var i = 0; i < 3; i++) {
          final r = ((t * .5 + i / 3) % 1) * 43;
          canvas.drawOval(
            Rect.fromCenter(center: center, width: r * 2, height: r * .65),
            Paint()
              ..color = const Color(0x88ffffff)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 12, height: 24),
            const Radius.circular(6),
          ),
          Paint()
            ..color = story.bite
                ? const Color(0xffffb84d)
                : const Color(0xffec765b),
        );
        canvas.drawLine(
          center - const Offset(0, 20),
          center - const Offset(0, 10),
          Paint()
            ..color = const Color(0xff3c544c)
            ..strokeWidth = 2,
        );
      }
    }
    if (story.scene == Scene.underwater) {
      // 9 saniyelik döngü:
      // Pipet → parçalanma → parçanın ağza yaklaşması → yutma.
      final phase = t % 9.0;

      double smooth(double value) {
        final p = value.clamp(0.0, 1.0).toDouble();
        return p * p * (3.0 - 2.0 * p);
      }

      final fishLength = min(size.x * .28, 130.0);
      final scale = fishLength / 100.0;

      final fishPosition = Offset(
        size.x * (.43 + sin(t * .85) * .025),
        size.y * .48 + sin(t * 1.8) * 4,
      );

      // Ağız parça yaklaşırken açılır, yutunca kapanır.
      final biteProgress = ((phase - 5.2) / 1.2).clamp(0.0, 1.0).toDouble();
      final mouthOpen = sin(biteProgress * pi);

      final mouthPosition = fishPosition + Offset(39 * scale, 0);

      final strawPosition = Offset(
        size.x * .69 + sin(t * .8) * 5,
        size.y * .29,
      );

      // Arka plandaki küçük hava kabarcıkları.
      for (var i = 0; i < 10; i++) {
        final x = size.x * (.08 + (i * .137) % .84);
        final y = size.y * (1 - ((t * .045 + i * .11) % 1));

        canvas.drawCircle(
          Offset(x + sin(t + i) * 5, y),
          2.0 + i % 3,
          Paint()
            ..color = const Color(0x45ddffff)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      // Pipet ilk iki saniye bütün görünür.
      if (phase < 2) {
        final opacity = smooth(phase / .5);

        canvas.save();
        canvas.translate(strawPosition.dx, strawPosition.dy);
        canvas.rotate(-.2 + sin(t) * .08);

        final strawPath = Path()
          ..moveTo(-10, 30)
          ..lineTo(-10, -20)
          ..lineTo(13, -34);

        canvas.drawPath(
          strawPath,
          Paint()
            ..color = const Color(0xffe88770).withValues(alpha: opacity)
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );

        canvas.restore();
      }

      // Parçalanan pipet. Yalnızca bir parça ağza ulaşır.
      if (phase >= 2) {
        final spread = smooth((phase - 2) / 1.2);

        for (var i = 0; i < 6; i++) {
          final start =
              strawPosition +
              Offset(
                -10 + sin(i * 2.1) * 24 * spread,
                -20 + i * 10 + (phase - 2) * 7,
              );

          var position = start;
          var pieceScale = 1.0;
          var opacity = 1.0 - smooth((phase - 8) / 1.0);

          if (i == 2) {
            // Parça, eğri bir akıntı rotasıyla ağza ilerler.
            final travel = ((phase - 3) / 3).clamp(0.0, 1.0).toDouble();
            final progress = smooth(travel);

            final control = Offset(
              strawPosition.dx + 18,
              mouthPosition.dy - 38,
            );

            position =
                start * ((1 - progress) * (1 - progress)) +
                control * (2 * (1 - progress) * progress) +
                mouthPosition * (progress * progress);

            // Ağzın içinde kaybolur; balığın içinden geçmez.
            pieceScale = 1 - smooth((travel - .88) / .12);
            opacity *= pieceScale;
          }

          if (opacity <= .01) continue;

          canvas.save();
          canvas.translate(position.dx, position.dy);
          canvas.rotate(t * .7 + i);
          canvas.scale(pieceScale);

          // Düzensiz şekil: yem yerine plastik kırıntısı.
          final fragment = Path()
            ..moveTo(-5, -3)
            ..lineTo(2, -5)
            ..lineTo(6, 0)
            ..lineTo(2, 4)
            ..lineTo(-4, 3)
            ..close();

          canvas.drawPath(
            fragment,
            Paint()..color = const Color(0xffed806c).withValues(alpha: opacity),
          );

          canvas.restore();
        }
      }

      // Hareketli balık.
      canvas.save();
      canvas.translate(fishPosition.dx, fishPosition.dy);
      canvas.scale(scale);

      final tailWave = sin(t * 9) * 7;
      final finWave = sin(t * 7) * 4;
      final mouthGap = mouthOpen * 9;

      final outline = Paint()
        ..color = const Color(0xff667b57)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round;

      final bodyPaint = Paint()
        ..shader = Gradient.linear(const Offset(0, -24), const Offset(0, 24), [
          const Color(0xffffd77b),
          const Color(0xffdfa24c),
        ]);

      final finPaint = Paint()..color = const Color(0xffefb75e);

      final tail = Path()
        ..moveTo(-32, 0)
        ..lineTo(-58, -20 + tailWave)
        ..quadraticBezierTo(-50, tailWave, -58, 20 + tailWave)
        ..close();

      canvas.drawPath(tail, finPaint);
      canvas.drawPath(tail, outline);

      final upperFin = Path()
        ..moveTo(-18, -18)
        ..quadraticBezierTo(-6, -37 + finWave, 10, -20)
        ..close();

      canvas.drawPath(upperFin, finPaint);
      canvas.drawPath(upperFin, outline);

      // Açılan ağzın koyu iç kısmı.
      if (mouthGap > .1) {
        canvas.drawPath(
          Path()
            ..moveTo(40, -mouthGap)
            ..lineTo(29, 0)
            ..lineTo(40, mouthGap)
            ..close(),
          Paint()..color = const Color(0xff70422f),
        );
      }

      // Ağız açıklığı balığın siluetinin bir parçasıdır.
      final body = Path()
        ..moveTo(41, -mouthGap)
        ..cubicTo(35, -30, -33, -31, -41, 0)
        ..cubicTo(-33, 31, 35, 30, 41, mouthGap)
        ..lineTo(30, 0)
        ..close();

      canvas.drawPath(body, bodyPaint);
      canvas.drawPath(body, outline);

      // Yan yüzgeç.
      canvas.save();
      canvas.translate(-3, 7);
      canvas.rotate(sin(t * 7) * .25);

      canvas.drawPath(
        Path()
          ..moveTo(5, -5)
          ..quadraticBezierTo(-18, -7, -12, 9)
          ..quadraticBezierTo(0, 13, 5, -5),
        Paint()..color = const Color(0xfff9d48c),
      );

      canvas.restore();

      // Göz.
      canvas.drawCircle(
        const Offset(23, -10),
        6,
        Paint()..color = const Color(0xfffffff0),
      );
      canvas.drawCircle(
        const Offset(25, -10),
        3,
        Paint()..color = const Color(0xff24463b),
      );
      canvas.drawCircle(
        const Offset(26, -11),
        1,
        Paint()..color = const Color(0xffffffff),
      );

      // Solungaç.
      canvas.drawArc(
        const Rect.fromLTWH(6, -14, 15, 29),
        -1.1,
        2.2,
        false,
        outline,
      );

      canvas.restore();
    }

    if (story.scene == Scene.success || story.scene == Scene.reward) {
      for (var i = 0; i < 35; i++) {
        final x = ((i * 47.0) % size.x) + sin(t + i) * 10;
        final y = ((t * 35 + i * 29) % size.y);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(t + i);
        canvas.drawRect(
          const Rect.fromLTWH(-2, -4, 4, 8),
          Paint()
            ..color = [
              const Color(0xffeac66c),
              const Color(0xff74c8b1),
              const Color(0xffef957b),
            ][i % 3].withValues(alpha: .8),
        );
        canvas.restore();
      }
    }
  }
}

void drawFish(Canvas c, Offset p, double length, Color color, double alpha) {
  c.save();
  c.translate(p.dx, p.dy);
  c.scale(length / 100);
  final fill = Paint()..color = color.withValues(alpha: alpha);
  final outline = Paint()
    ..color = const Color(0xff537568).withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final tail = Path()
    ..moveTo(-30, 0)
    ..lineTo(-57, -23)
    ..quadraticBezierTo(-48, 0, -57, 23)
    ..close();
  c.drawPath(tail, fill);
  c.drawPath(tail, outline);
  final body = Rect.fromCenter(center: Offset.zero, width: 83, height: 47);
  c.drawOval(body, fill);
  c.drawOval(body, outline);
  final fin = Path()
    ..moveTo(-14, -20)
    ..lineTo(-2, -37)
    ..lineTo(14, -22)
    ..close();
  c.drawPath(fin, fill);
  c.drawPath(fin, outline);
  c.drawOval(
    const Rect.fromLTWH(-5, 0, 17, 17),
    Paint()..color = const Color(0xffefd19b).withValues(alpha: alpha),
  );
  c.drawCircle(
    const Offset(24, -7),
    6,
    Paint()..color = Color.fromRGBO(255, 255, 247, alpha),
  );
  c.drawCircle(
    const Offset(26, -7),
    3,
    Paint()..color = const Color(0xff203e38).withValues(alpha: alpha),
  );
  c.drawArc(const Rect.fromLTWH(2, -16, 18, 32), -1.2, 2.4, false, outline);
  c.restore();
}
