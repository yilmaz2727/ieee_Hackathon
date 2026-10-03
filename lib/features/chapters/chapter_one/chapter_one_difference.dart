import 'dart:math';

import 'package:flutter/material.dart';

import '../../../audio_manager.dart';
import '../../../game/story_controller.dart';
import '../../../localization/app_localizations.dart';
import '../../../ui/widgets.dart';

class ChapterOneDifferenceGame extends StatefulWidget {
  const ChapterOneDifferenceGame({
    super.key,
    required this.story,
    required this.onComplete,
  });

  final StoryController story;
  final VoidCallback onComplete;

  @override
  State<ChapterOneDifferenceGame> createState() =>
      _ChapterOneDifferenceGameState();
}

class _ChapterOneDifferenceGameState extends State<ChapterOneDifferenceGame> {
  static const double _imageWidth = 1312;
  static const double _imageHeight = 598;
  static const double _imageAspectRatio = _imageWidth / _imageHeight;

  // Hit areas are defined in the original dirty image's pixel coordinate system.
  // Touches are converted back to these coordinates, so the same object is hit
  // accurately on phones, tablets and web layouts.
  static const _targets = <_DifferenceTarget>[
    // 1) Tekne: gövde + kabin. Çevredeki su mümkün olduğunca dışarıda kalır.
    _DifferenceTarget(
      marker: Offset(1138, 351),
      polygons: [
        [
          Offset(936, 301),
          Offset(986, 281),
          Offset(1058, 279),
          Offset(1082, 245),
          Offset(1236, 248),
          Offset(1293, 279),
          Offset(1310, 334),
          Offset(1308, 414),
          Offset(1281, 462),
          Offset(1144, 456),
          Offset(1011, 421),
          Offset(963, 382),
        ],
      ],
    ),

    // 2) Fabrikanın atık su çıkış borusu.
    _DifferenceTarget(
      marker: Offset(738, 220),
      polygons: [
        [
          Offset(699, 177),
          Offset(744, 177),
          Offset(771, 191),
          Offset(781, 218),
          Offset(771, 255),
          Offset(751, 275),
          Offset(716, 271),
          Offset(697, 241),
        ],
      ],
    ),

    // 3) Balıkçının oltası. Hem olta gövdesi hem ince misina alanı kabul edilir.
    _DifferenceTarget(
      marker: Offset(332, 157),
      polygons: [
        [
          Offset(263, 201),
          Offset(328, 116),
          Offset(359, 94),
          Offset(374, 94),
          Offset(380, 106),
          Offset(350, 120),
          Offset(280, 217),
          Offset(268, 216),
        ],
        [Offset(358, 99), Offset(379, 99), Offset(382, 216), Offset(360, 216)],
      ],
    ),

    // 4) Mazgalın yanındaki filtresiz büyük boru.
    _DifferenceTarget(
      marker: Offset(410, 422),
      polygons: [
        [
          Offset(284, 367),
          Offset(391, 369),
          Offset(463, 382),
          Offset(501, 400),
          Offset(516, 427),
          Offset(508, 458),
          Offset(481, 493),
          Offset(432, 477),
          Offset(370, 451),
          Offset(313, 435),
          Offset(286, 410),
        ],
      ],
    ),

    // 5) Kaldırım/mazgal çevresindeki iki çöp. İkisinden birine dokunmak yeterli.
    _DifferenceTarget(
      marker: Offset(245, 482),
      polygons: [
        [
          Offset(178, 413),
          Offset(212, 410),
          Offset(231, 423),
          Offset(225, 443),
          Offset(191, 446),
          Offset(176, 432),
        ],
        [
          Offset(207, 487),
          Offset(265, 491),
          Offset(313, 508),
          Offset(315, 529),
          Offset(267, 534),
          Offset(223, 522),
          Offset(204, 506),
        ],
      ],
    ),
  ];

  Set<int> get _found => widget.story.differenceFound;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    if (_found.length == _targets.length) {
      _completing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishPuzzle();
      });
    } else {
      // Önceki müzik (menü veya hikâye) durur, bulmaca müziği başlar.
      AudioManager.instance.playBGM('fark_bulma_oyunu_bg.mp3');
    }
  }

  // CH2 müziği belirlenene kadar bulmacadan sonra menü müziği çalar.
  void _finishPuzzle() {
    AudioManager.instance.playBGM('ana_menu_bg.mp3');
    widget.onComplete();
  }

  void _handleTap(Offset localPosition, Size renderedSize) {
    if (_completing || renderedSize.width <= 0 || renderedSize.height <= 0) {
      return;
    }

    // Map the touch to the original 1312x598 image coordinates. This makes
    // target accuracy independent of the displayed screen size.
    final imagePoint = Offset(
      localPosition.dx * _imageWidth / renderedSize.width,
      localPosition.dy * _imageHeight / renderedSize.height,
    );

    int? hit;
    for (var i = 0; i < _targets.length; i++) {
      if (!_found.contains(i) && _targets[i].contains(imagePoint)) {
        hit = i;
        break;
      }
    }

    if (hit == null) return;

    widget.story.markDifferenceFound(hit);
    AudioManager.instance.playEffect('fark_bulma_bildin.mp3');
    setState(() {
      _completing = _found.length == _targets.length;
    });

    // The animated green check is the feedback. No extra toast is shown.
    if (_completing) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _finishPuzzle();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      child: Column(
        children: [
          Paper(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: ink, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    tr('chapter1.difference.instruction'),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tr('chapter1.difference.counter', {'count': _found.length}),
                    style: const TextStyle(
                      color: cream,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ImageCard(
            label: tr('chapter1.difference.cleanLabel'),
            child: const AspectRatio(
              aspectRatio: _imageAspectRatio,
              child: Image(
                image: AssetImage(
                  'assets/images/chapter1_difference_clean.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ImageCard(
            label: tr('chapter1.difference.dirtyLabel'),
            emphasized: true,
            child: AspectRatio(
              aspectRatio: _imageAspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final renderedSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _handleTap(details.localPosition, renderedSize),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Image(
                          image: AssetImage(
                            'assets/images/chapter1_difference_dirty.png',
                          ),
                          fit: BoxFit.cover,
                        ),
                        for (final index in _found)
                          _FoundMarker(
                            key: ValueKey('difference-$index'),
                            target: _targets[index],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('chapter1.difference.hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ink.withValues(alpha: .80),
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class ChapterOneDifferenceResult extends StatefulWidget {
  const ChapterOneDifferenceResult({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<ChapterOneDifferenceResult> createState() =>
      _ChapterOneDifferenceResultState();
}

class _ChapterOneDifferenceResultState
    extends State<ChapterOneDifferenceResult> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String)>[
      (Icons.factory_outlined, tr('chapter1.difference.fact.factory')),
      (Icons.directions_boat_outlined, tr('chapter1.difference.fact.boat')),
      (Icons.phishing_rounded, tr('chapter1.difference.fact.fishing')),
      (Icons.filter_alt_outlined, tr('chapter1.difference.fact.drain')),
      (Icons.delete_outline_rounded, tr('chapter1.difference.fact.trash')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelHeight = min(constraints.maxHeight * .66, 430.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: constraints.maxHeight < 650 ? 54 : 68,
                child: Image.asset(
                  'assets/images/esma.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SizedBox(
                  height: panelHeight,
                  child: Paper(
                    padding: const EdgeInsets.fromLTRB(16, 15, 10, 12),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('chapter1.difference.resultEyebrow'),
                              style: const TextStyle(
                                color: ink,
                                fontSize: 9,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              tr('chapter1.difference.resultTitle'),
                              style: const TextStyle(
                                fontFamily: 'StorySerif',
                                color: ink,
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              tr('chapter1.difference.resultBody'),
                              style: const TextStyle(
                                color: ink,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.swipe_up_rounded,
                                  size: 16,
                                  color: ink,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    tr('chapter1.difference.scrollHint'),
                                    style: TextStyle(
                                      color: ink.withValues(alpha: .72),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            for (var i = 0; i < facts.length; i++) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffeef2df),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xffd8dfc5),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Color(0xffffe5a8),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Icon(facts[i].$1, color: ink, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        facts[i].$2,
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 10.5,
                                          height: 1.35,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (i != facts.length - 1)
                                const SizedBox(height: 7),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              tr('chapter1.difference.nextBody'),
                              style: const TextStyle(
                                color: ink,
                                fontSize: 11,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StoryButton(
                              tr('chapter1.difference.nextButton'),
                              onPressed: widget.onContinue,
                              icon: Icons.arrow_forward_rounded,
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.label,
    required this.child,
    this.emphasized = false,
  });

  final String label;
  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: emphasized ? gold : const Color(0xffe3d6b7),
        width: emphasized ? 2.2 : 1.3,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24243c32),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: ink,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: emphasized ? .4 : .1,
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class _FoundMarker extends StatelessWidget {
  const _FoundMarker({super.key, required this.target});

  final _DifferenceTarget target;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment(
      (target.marker.dx / _ChapterOneDifferenceGameState._imageWidth) * 2 - 1,
      (target.marker.dy / _ChapterOneDifferenceGameState._imageHeight) * 2 - 1,
    ),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: .15, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xcc2f7d61),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 25),
      ),
    ),
  );
}

class _DifferenceTarget {
  const _DifferenceTarget({required this.marker, required this.polygons});

  final Offset marker;
  final List<List<Offset>> polygons;

  bool contains(Offset point) {
    for (final polygon in polygons) {
      if (_pointInPolygon(point, polygon)) return true;
    }
    return false;
  }

  static bool _pointInPolygon(Offset point, List<Offset> polygon) {
    var inside = false;
    var j = polygon.length - 1;

    for (var i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];

      final crosses =
          ((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) *
                      (point.dy - pi.dy) /
                      ((pj.dy - pi.dy).abs() < .000001
                          ? .000001
                          : (pj.dy - pi.dy)) +
                  pi.dx);

      if (crosses) inside = !inside;
      j = i;
    }

    return inside;
  }
}
