import 'dart:math';

import 'package:flutter/material.dart';

import '../audio_manager.dart';
import '../game/lake_game.dart';

const ink = Color(0xff214e43),
    cream = Color(0xfffff8e9),
    gold = Color(0xffeecb72),
    coral = Color(0xffe88770);

/// Parmak ekrana değdiği anda (onTapDown) tıklama sesini çalıp eylemi
/// tetikler; parmağın kalkması beklenmez.
///
/// Görünüm [builder] içindeki butondan gelir ve aynen korunur. Buton işaretçi
/// olaylarını almaz (yalnızca bu sarmalayıcı alır); klavye ve ekran okuyucu
/// ise butonun onPressed'i üzerinden yine aynı eylemi çalıştırır. Ripple
/// yerine basılıyken buton hafifçe (%95) küçülür.
class TapDownButton extends StatefulWidget {
  const TapDownButton({
    super.key,
    required this.onTap,
    required this.builder,
    this.sound = clickSound,
  });

  static const clickSound = 'bubble_button_click.mp3';

  /// Dedemin Doğa Kitabı'nı açan ve kitabın içindeki butonlar için.
  static const bookSound = 'dedenin_kitabi_click.mp3';

  /// null ise buton pasif görünür ve dokunuşa tepki vermez.
  final VoidCallback? onTap;
  final Widget Function(VoidCallback? onPressed) builder;

  /// null ise tıklama sesi çalmaz (eylem kendi sesini çalıyorsa).
  final String? sound;

  @override
  State<TapDownButton> createState() => _TapDownButtonState();
}

class _TapDownButtonState extends State<TapDownButton> {
  bool _down = false;

  void _setDown(bool value) {
    if (mounted && _down != value) setState(() => _down = value);
  }

  @override
  void didUpdateWidget(TapDownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Basılıyken pasifleşen buton küçük kalmasın.
    if (widget.onTap == null) _down = false;
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.onTap;
    final pressed = action == null
        ? null
        : () {
            final sound = widget.sound;
            if (sound != null) AudioManager.instance.playEffect(sound);
            action();
          };

    return MouseRegion(
      cursor: pressed == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: pressed == null
            ? null
            : (_) {
                _setDown(true);
                pressed();
              },
        // Buton pasifleşse bile parmak kalkınca eski boyutuna dönebilsin diye
        // bu ikisi her zaman bağlı.
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        child: AnimatedScale(
          scale: _down ? .95 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: IgnorePointer(child: widget.builder(pressed)),
        ),
      ),
    );
  }
}

class StoryButton extends StatelessWidget {
  const StoryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.secondary = false,
    this.loading = false,
    this.sound = TapDownButton.clickSound,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool secondary;
  final bool loading;
  final String? sound;

  @override
  Widget build(BuildContext context) {
    final background = secondary ? const Color(0xfff3e5c8) : ink;
    final foreground = secondary ? ink : cream;

    return SizedBox(
      width: double.infinity,
      child: TapDownButton(
        onTap: loading ? null : onPressed,
        sound: sound,
        builder: (pressed) => FilledButton(
          onPressed: pressed,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: loading
                ? background
                : ink.withValues(alpha: .15),
            disabledForegroundColor: loading
                ? foreground
                : ink.withValues(alpha: .45),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 20,
                height: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: loading
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: foreground,
                            semanticsLabel: label,
                          ),
                        )
                      : Icon(icon, key: const ValueKey('icon'), size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xffe3d6b7), width: 1.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24243c32),
          blurRadius: 25,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class Badge extends StatelessWidget {
  const Badge({super.key, this.size = 130});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _BadgePainter()),
  );
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.translate(s.width / 2, s.height / 2);
    final r = s.width * .40;
    for (final sign in [-1, 1]) {
      final p = Path()
        ..moveTo(sign * r * .2, r * .5)
        ..lineTo(sign * r * .8, r * 1.25)
        ..lineTo(sign * r * .8, r * .92)
        ..lineTo(sign * r * 1.07, r * .93)
        ..lineTo(sign * r * .63, r * .37)
        ..close();
      c.drawPath(p, Paint()..color = coral);
    }
    final p = Path();
    for (var i = 0; i < 40; i++) {
      final a = i * pi / 20;
      final rr = i.isEven ? r : r * .91;
      final pt = Offset(cos(a) * rr, sin(a) * rr);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = gold);
    c.drawCircle(Offset.zero, r * .8, Paint()..color = ink);
    c.drawCircle(
      Offset.zero,
      r * .72,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final drop = Path()
      ..moveTo(0, -r * .5)
      ..cubicTo(-r * .7, r * .1, -r * .4, r * .5, 0, r * .48)
      ..cubicTo(r * .4, r * .5, r * .7, r * .1, 0, -r * .5)
      ..close();
    c.drawPath(drop, Paint()..color = const Color(0xffa5e2d7));
    c.drawArc(
      Rect.fromCircle(center: Offset(0, r * .12), radius: r * .15),
      0,
      pi,
      false,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FishPicture extends StatelessWidget {
  const FishPicture({super.key, this.scan = false});
  final bool scan;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _FishPainter(scan), size: const Size(340, 210));
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.scan);
  final bool scan;
  @override
  void paint(Canvas c, Size s) {
    drawFish(
      c,
      Offset(s.width * .54, s.height * .51),
      s.width * .73,
      scan ? const Color(0xff84cfc5) : const Color(0xffe8b362),
      1,
    );
    if (scan) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s.width * .52, s.height * .56),
          width: s.width * .30,
          height: s.height * .23,
        ),
        Paint()..color = const Color(0x6641716b),
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(s.width * .52, s.height * .56),
          width: s.width * .30,
          height: s.height * .23,
        ),
        Paint()
          ..color = const Color(0xffdcfff2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_FishPainter oldDelegate) => oldDelegate.scan != scan;
}

/// A deliberately non-food-looking microplastic symbol for Chapter 2.
/// Shapes represent a hard fragment, a synthetic fibre and a thin film scrap.
class MicroplasticIcon extends StatelessWidget {
  const MicroplasticIcon(this.kind, {super.key, this.size = 28});
  final int kind;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MicroplasticPainter(kind));
}

class _MicroplasticPainter extends CustomPainter {
  const _MicroplasticPainter(this.kind);
  final int kind;

  @override
  void paint(Canvas c, Size s) {
    final scale = s.width / 30;
    c.scale(scale);
    final outline = Paint()
      ..color = const Color(0xff5a2f2a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = const Color(0xffe56f5c);
    final highlight = Paint()
      ..color = const Color(0xffffd0b7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    if (kind == 0) {
      final p = Path()
        ..moveTo(5, 7)
        ..lineTo(17, 4)
        ..lineTo(25, 10)
        ..lineTo(21, 23)
        ..lineTo(10, 26)
        ..lineTo(4, 17)
        ..close();
      c.drawPath(p, fill);
      c.drawPath(p, outline);
      c.drawLine(const Offset(10, 10), const Offset(18, 8), highlight);
      c.drawLine(const Offset(9, 17), const Offset(17, 20), highlight);
    } else if (kind == 1) {
      final fibre = Path()
        ..moveTo(4, 22)
        ..cubicTo(8, 4, 18, 27, 26, 7);
      c.drawPath(
        fibre,
        Paint()
          ..color = const Color(0xffd95663)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(fibre, outline..strokeWidth = 1.5);
    } else {
      final p = Path()
        ..moveTo(5, 8)
        ..lineTo(12, 5)
        ..lineTo(18, 9)
        ..lineTo(25, 6)
        ..lineTo(23, 22)
        ..lineTo(16, 25)
        ..lineTo(10, 21)
        ..lineTo(5, 23)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0xffef906e));
      c.drawPath(p, outline);
      c.drawLine(const Offset(10, 12), const Offset(20, 16), highlight);
    }

    // Tiny crossed bite mark: reinforces that this object is waste, not food.
    final noEat = Paint()
      ..color = const Color(0xff7a231f)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(22, 22), const Offset(28, 28), noEat);
    c.drawLine(const Offset(28, 22), const Offset(22, 28), noEat);
  }

  @override
  bool shouldRepaint(_MicroplasticPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class WasteIcon extends StatelessWidget {
  const WasteIcon(this.kind, {super.key, this.size = 50});
  final int kind;
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _WastePainter(kind));
}

class _WastePainter extends CustomPainter {
  _WastePainter(this.kind);
  final int kind;
  @override
  void paint(Canvas c, Size s) {
    c.scale(s.width / 56);
    final outline = Paint()
      ..color = const Color(0xff376964)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    if (kind == 0) {
      final straw = Path()
        ..moveTo(20, 49)
        ..lineTo(20, 21)
        ..lineTo(38, 9);
      c.drawPath(
        straw,
        Paint()
          ..color = const Color(0xff923e36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      c.drawPath(
        straw,
        Paint()
          ..color = coral
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (var i = 0; i < 4; i++) {
        c.drawLine(
          Offset(17, 29.0 + i * 5),
          Offset(23, 26.0 + i * 5),
          Paint()
            ..color = cream
            ..strokeWidth = 2,
        );
      }
    } else if (kind == 1) {
      final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 9, 28, 39),
        const Radius.circular(7),
      );
      c.drawRRect(body, Paint()..color = const Color(0xffe99570));
      c.drawRRect(body, outline);
      c.drawOval(
        const Rect.fromLTWH(14, 7, 28, 9),
        Paint()..color = const Color(0xffc3cdcb),
      );
      c.drawOval(const Rect.fromLTWH(14, 7, 28, 9), outline);
      c.drawOval(const Rect.fromLTWH(25, 9, 8, 4), outline);
      c.drawRect(const Rect.fromLTWH(15, 24, 26, 11), Paint()..color = gold);
    } else {
      final p = Path()
        ..moveTo(12, 7)
        ..lineTo(36, 7)
        ..lineTo(45, 17)
        ..lineTo(45, 48)
        ..lineTo(12, 48)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0xfffaf6df));
      c.drawPath(p, outline);
      c.drawPath(
        Path()
          ..moveTo(36, 7)
          ..lineTo(36, 18)
          ..lineTo(45, 18),
        outline,
      );
      for (var i = 0; i < 4; i++) {
        c.drawLine(
          Offset(18, (24 + i * 5).toDouble()),
          Offset(37, (24 + i * 5).toDouble()),
          outline,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WastePainter oldDelegate) => kind != oldDelegate.kind;
}

class StoryHeading extends StatelessWidget {
  const StoryHeading(this.text, {super.key, this.color = ink});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontFamily: 'StorySerif',
      fontWeight: FontWeight.bold,
      fontSize: 25,
      color: color,
      height: 1.22,
    ),
  );
}

class StoryEyebrow extends StatelessWidget {
  const StoryEyebrow(this.text, {super.key, this.color = ink});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 9,
      letterSpacing: 1.3,
      fontWeight: FontWeight.bold,
      color: color,
    ),
  );
}

class StoryPill extends StatelessWidget {
  const StoryPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: ink,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: .7,
      ),
    ),
  );
}

class StatChip extends StatelessWidget {
  const StatChip(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: ink, size: 17),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
