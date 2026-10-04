import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:clock/clock.dart' as time;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../audio_manager.dart';
import '../../game/story_controller.dart';
import '../../localization/app_localizations.dart';
import '../../ui/widgets.dart';

class FishPuzzleScreen extends StatefulWidget {
  const FishPuzzleScreen({
    super.key,
    required this.story,
    this.onFinish,
  });

  final StoryController story;
  final VoidCallback? onFinish;

  @override
  State<FishPuzzleScreen> createState() => _FishPuzzleScreenState();
}

class _FishPuzzleScreenState extends State<FishPuzzleScreen>
    with WidgetsBindingObserver {
  static const _asset = 'assets/images/kucukcekmece.png';

  final _clock = time.clock.stopwatch();
  final _placed = <int>{};
  late final List<int> _order;

  Duration _previousElapsed = Duration.zero;

  ui.Image? _image;
  Timer? _timer;

  bool _background = false;
  bool _finished = false;
  bool _saving = false;
  bool _saved = false;
  bool _loadFailed = false;

  int _score = 0;

  Duration get _elapsed => _previousElapsed + _clock.elapsed;

  bool get _tr => AppLocalizations.instance.isTurkish;

  bool get _paused => widget.story.paused || _background;

  @override
  void initState() {
    super.initState();

    final story = widget.story;

    _placed.addAll(story.fishPuzzlePlaced);
    _previousElapsed = story.fishPuzzleElapsed;
    _score = story.fishPuzzleScore;
    _finished = _placed.length == 9;

    _order = story.fishPuzzleOrder.length == 9
        ? List<int>.from(story.fishPuzzleOrder)
        : (List<int>.generate(9, (i) => i)..shuffle());

    WidgetsBinding.instance.addObserver(this);
    story.addListener(_syncClock);

    AudioManager.instance.playBGM('puzzle_bg.mp3');

    _loadImage();

    if (_finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _saveResult();
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused && !_finished && _image != null) {
        setState(() {});
      }
    });
  }

  void _rememberProgress() {
    final story = widget.story;

    story.fishPuzzlePlaced
      ..clear()
      ..addAll(_placed);

    story.fishPuzzleOrder
      ..clear()
      ..addAll(_order);

    story.fishPuzzleElapsed = _elapsed;
    story.fishPuzzleScore = _score;
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() => _loadFailed = false);

    try {
      final data = await rootBundle.load(_asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ),
      );

      late final ui.FrameInfo frame;

      try {
        frame = await codec.getNextFrame();
      } finally {
        codec.dispose();
      }

      if (!mounted) {
        frame.image.dispose();
        return;
      }

      setState(() => _image = frame.image);
      _syncClock();
    } catch (_) {
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    }
  }

  void _syncClock() {
    if (_paused ||
        _finished ||
        _image == null ||
        widget.story.scene != Scene.fishPuzzle) {
      _clock.stop();
    } else {
      _clock.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _syncClock();
  }

  void _place(int index) {
    if (_paused ||
        _finished ||
        index < 0 ||
        index >= 9 ||
        _placed.contains(index)) {
      return;
    }

    setState(() {
      _placed.add(index);

      if (_placed.length == 9) {
        _clock.stop();
        _score = max(20, 100 - _elapsed.inSeconds);
        _finished = true;
      }
    });

    _rememberProgress();

    if (_finished) {
      AudioManager.instance.playEffect('kazandin.mp3');
      _saveResult();
    } else {
      AudioManager.instance.playEffect('ch1_dogru_kutu.mp3');
    }
  }

  void _missed() {
    if (!mounted || _paused || _finished) return;

    AudioManager.instance.playEffect('ch1_yanlis_kutu.mp3');
  }

  Future<void> _saveResult() async {
    if (!mounted || _saving || _saved) return;

    setState(() => _saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setInt('puzzle_score', _score);

      if (!success) {
        throw StateError('Puzzle score could not be saved.');
      }

      if (mounted) {
        setState(() => _saved = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr
                  ? 'Puan kaydedilemedi. Kaydetmeyi tekrar dene.'
                  : 'Could not save your score. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    widget.story.removeListener(_syncClock);
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
    _clock.stop();
    _rememberProgress();

    _image?.dispose();
    super.dispose();
  }

  Widget _piece(int index, double cell) {
    return SizedBox(
      width: cell * 1.5,
      height: cell * 1.5,
      child: CustomPaint(
        painter: _PiecePainter(
          image: _image!,
          index: index,
          cell: cell,
        ),
      ),
    );
  }

  Widget _result() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Paper(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/esma.png',
                      height: 145,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tr
                          ? 'Göl yeniden bir bütün!'
                          : 'The lake is whole again!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'StorySerif',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _tr
                          ? '“Parçaları birleştirince Küçükçekmece Gölü’nü '
                              'yeniden gördük. Doğada da su, balıklar ve insanlar '
                              'birbirine bağlı. Plastik küçülse bile yok olmaz; '
                              'suya ulaşmadan atıkları doğru kutuya atalım!”'
                          : '“Putting the pieces together revealed Küçükçekmece '
                              'Lake. Water, fish and people are connected too. '
                              'Plastic does not disappear when it breaks into '
                              'smaller pieces. Let’s sort waste before it reaches water!”',
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.6, color: ink),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _tr
                          ? '9/9 parça • ${_elapsed.inSeconds} saniye\n'
                              'Puzzle puanı: $_score'
                          : '9/9 pieces • ${_elapsed.inSeconds} seconds\n'
                              'Puzzle score: $_score',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 18),
                    StoryButton(
                      _saved
                          ? (_tr ? 'Hikâyeye devam et' : 'Continue the story')
                          : (_tr ? 'Puanı kaydet' : 'Save score'),
                      loading: _saving,
                      onPressed: _saving
                          ? null
                          : _saved
                              ? widget.onFinish
                              : _saveResult,
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.story,
        AppLocalizations.instance,
      ]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = min(330.0, constraints.maxWidth - 40);
            final cell = boardSize / 3;
            final pad = cell * .25;

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(_asset, fit: BoxFit.cover),
                const ColoredBox(color: Color(0x66234331)),
                if (_loadFailed)
                  Center(
                    child: FilledButton(
                      onPressed: _loadImage,
                      child: Text(
                        _tr ? 'Görseli tekrar yükle' : 'Reload image',
                      ),
                    ),
                  )
                else if (_image == null)
                  const Center(child: CircularProgressIndicator())
                else
                  IgnorePointer(
                    ignoring: _paused || _finished,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        children: [
                          Paper(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Text(
                                  _tr
                                      ? 'Gölün parçalarını birleştir'
                                      : 'Piece the lake together',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'StorySerif',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _tr
                                      ? 'Parçaları aşağıdan alıp uygun boşluğa bırak.'
                                      : 'Drag each piece into its matching space.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_placed.length}/9  •  '
                                  '${_elapsed.inSeconds} ${_tr ? 'sn' : 's'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: cream,
                              border: Border.all(color: cream, width: 4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: boardSize,
                              height: boardSize,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: .2,
                                      child: Image.asset(
                                        _asset,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  for (final index in _placed)
                                    Positioned(
                                      left: (index % 3) * cell - pad,
                                      top: (index ~/ 3) * cell - pad,
                                      child: IgnorePointer(
                                        child: _piece(index, cell),
                                      ),
                                    ),
                                  for (var index = 0; index < 9; index++)
                                    Positioned(
                                      left: (index % 3) * cell,
                                      top: (index ~/ 3) * cell,
                                      width: cell,
                                      height: cell,
                                      child: DragTarget<int>(
                                        key: ValueKey('puzzle-slot-$index'),
                                        onWillAcceptWithDetails: (details) =>
                                            !_paused &&
                                            !_finished &&
                                            !_placed.contains(index) &&
                                            details.data == index,
                                        onAcceptWithDetails: (details) =>
                                            _place(details.data),
                                        builder: (
                                          context,
                                          candidates,
                                          rejected,
                                        ) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: candidates.isNotEmpty
                                                  ? Colors.green.withValues(
                                                      alpha: .18,
                                                    )
                                                  : Colors.transparent,
                                              border: _placed.contains(index)
                                                  ? null
                                                  : Border.all(
                                                      color: ink.withValues(
                                                        alpha: .15,
                                                      ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cream.withValues(alpha: .95),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final index in _order)
                                  if (!_placed.contains(index))
                                    Draggable<int>(
                                      key: ValueKey('puzzle-piece-$index'),
                                      data: index,
                                      maxSimultaneousDrags: _paused ? 0 : 1,
                                      rootOverlay: true,
                                      onDraggableCanceled: (_, _) => _missed(),
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: _piece(index, cell),
                                      ),
                                      childWhenDragging: SizedBox(
                                        width: cell * 1.5,
                                        height: cell * 1.5,
                                      ),
                                      child: Listener(
                                        onPointerDown: (_) {
                                          AudioManager.instance.playEffect(
                                            'puzzle_tutus.mp3',
                                          );
                                        },
                                        child: _piece(index, cell),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_finished) _result(),
              ],
            );
          },
        );
      },
    );
  }
}

class _PiecePainter extends CustomPainter {
  const _PiecePainter({
    required this.image,
    required this.index,
    required this.cell,
  });

  final ui.Image image;
  final int index;
  final double cell;

  Path _shape() {
    final row = index ~/ 3;
    final col = index % 3;
    final pad = cell * .25;

    double sign(int a, int b) => (a + b).isEven ? 1 : -1;

    final top = row == 0 ? 0.0 : sign(row, col);
    final right = col == 2 ? 0.0 : sign(row, col);
    final bottom = row == 2 ? 0.0 : -sign(row + 1, col);
    final left = col == 0 ? 0.0 : -sign(row, col - 1);

    final path = Path()..moveTo(pad, pad);

    void edge(
      Offset start,
      Offset end,
      Offset normal,
      double direction,
    ) {
      final delta = end - start;

      Offset p(double t, double depth) =>
          start + delta * t + normal * (cell * depth * direction);

      void line(Offset point) => path.lineTo(point.dx, point.dy);

      void curve(Offset a, Offset b, Offset c) {
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
      }

      if (direction == 0) {
        line(end);
        return;
      }

      line(p(.35, 0));
      curve(p(.44, 0), p(.35, .08), p(.36, .13));
      curve(p(.37, .25), p(.63, .25), p(.64, .13));
      curve(p(.65, .08), p(.56, 0), p(.65, 0));
      line(end);
    }

    final a = Offset(pad, pad);
    final b = Offset(pad + cell, pad);
    final c = Offset(pad + cell, pad + cell);
    final d = Offset(pad, pad + cell);

    edge(a, b, const Offset(0, -1), top);
    edge(b, c, const Offset(1, 0), right);
    edge(c, d, const Offset(0, 1), bottom);
    edge(d, a, const Offset(-1, 0), left);

    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shape();
    final side = min(image.width, image.height).toDouble();
    final pad = cell * .25;

    final source = Rect.fromLTWH(
      (image.width - side) / 2,
      (image.height - side) / 2,
      side,
      side,
    );

    final destination = Rect.fromLTWH(
      pad - (index % 3) * cell,
      pad - (index ~/ 3) * cell,
      cell * 3,
      cell * 3,
    );

    canvas.drawShadow(path, Colors.black54, 3, true);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF4D6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _PiecePainter oldDelegate) {
    return image != oldDelegate.image ||
        index != oldDelegate.index ||
        cell != oldDelegate.cell;
  }
}