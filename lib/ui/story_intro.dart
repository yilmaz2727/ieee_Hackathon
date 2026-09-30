import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

class StoryIntro extends StatefulWidget {
  const StoryIntro({super.key});

  @override
  State<StoryIntro> createState() => _StoryIntroState();
}

class _StoryIntroState extends State<StoryIntro> {
  int _page = 0;
  bool _closing = false;

  static const _images = [
    'assets/images/intro_1.png',
    'assets/images/intro_2.png',
    'assets/images/intro_3.png',
  ];

  static const _titlesTr = [
    'Suyun kıyısında bir gün',
    'Küçük bir pipet, büyük bir yolculuk',
    'Kitabın içindeki dünya',
  ];

  static const _titlesEn = [
    'A day by the water',
    'A little straw, a big journey',
    'The world inside the book',
  ];

  static const _textsTr = [
    'Esma, dedesiyle su kıyısında vakit geçirmeyi çok severdi. '
        'Dedesi o gün yanında eski, yeşil kitabını getirmişti.\n\n'
        '“Bu sularda ne kadar çok canlının yaşadığını biliyor musun?”',

    'Esma pipetini içeceğinden çıkardığı anda rüzgâr esti. '
        'Pipet elinden uçtu, suya düştü ve uzaklaşmaya başladı.\n\n'
        '“Yetişemedim… Bir pipet çok zarar verir mi ki?”',

    'Dedesi kitabı açtı: “Plastikler zamanla küçük parçalara '
        'ayrılabilir. Suda yaşayan canlılar da bunları yutabilir.”\n\n'
        'Esma: “Peki, onlara yardım edebilir miyiz?”\n'
        'Dedesi: “Elbette. Önce kıyıdaki çöplerden başlayalım!”',
  ];

  static const _textsEn = [
    'Esma loved spending time by the water with her grandfather. '
        'That day, he had brought his old green book.\n\n'
        '“Do you know how many creatures live in these waters?”',

    'Just as Esma took the straw out of her drink, a gust of wind '
        'carried it away. It fell into the water and began to drift.\n\n'
        '“I couldn’t catch it… Can one straw really cause harm?”',

    'Her grandfather opened the book. “Over time, plastics can '
        'break into small pieces. Aquatic animals may swallow them.”\n\n'
        'Esma: “Can we help them?”\n'
        'Grandfather: “Of course. Let’s start with the litter on the shore!”',
  ];

  void _finish() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(true);
  }

  void _next() {
    if (_page == _images.length - 1) {
      _finish();
    } else {
      setState(() => _page++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocalizations.instance,
      builder: (context, _) {
        final isTr = AppLocalizations.instance.isTurkish;
        final titles = isTr ? _titlesTr : _titlesEn;
        final texts = isTr ? _textsTr : _textsEn;
        final lastPage = _page == _images.length - 1;
        final reduceMotion = MediaQuery.of(context).disableAnimations;

        return ColoredBox(
          color: const Color(0xFFE1EADB),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Scaffold(
                backgroundColor: const Color(0xFFF7F3E8),
                appBar: AppBar(
                  backgroundColor: const Color(0xFFF7F3E8),
                  foregroundColor: const Color(0xFF244B43),
                  elevation: 0,
                  title: Text(
                    isTr
                        ? 'Esma ve Pipetin Yolculuğu'
                        : 'Esma and the Straw’s Journey',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: _finish,
                      child: Text(isTr ? 'Atla' : 'Skip'),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: Duration(
                                milliseconds: reduceMotion ? 0 : 350,
                              ),
                              child: SingleChildScrollView(
                                key: ValueKey(_page),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: AspectRatio(
                                        aspectRatio: 4 / 3,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(
                                            begin: 1,
                                            end: reduceMotion ? 1 : 1.035,
                                          ),
                                          duration: Duration(
                                            milliseconds: reduceMotion
                                                ? 0
                                                : 4500,
                                          ),
                                          builder: (context, scale, child) {
                                            return Transform.scale(
                                              scale: scale,
                                              child: child,
                                            );
                                          },
                                          child: Image.asset(
                                            _images[_page],
                                            fit: _page == 1
                                                ? BoxFit.contain
                                                : BoxFit.cover,
                                            alignment: Alignment.centerLeft,
                                            errorBuilder: (context, error, stack) {
                                              return ColoredBox(
                                                color: const Color(0xFFE1EADB),
                                                child: Center(
                                                  child: Text(
                                                    isTr
                                                        ? 'Görsel bulunamadı:\n${_images[_page]}'
                                                        : 'Image not found:\n${_images[_page]}',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Text(
                                      titles[_page],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF244B43),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      texts[_page],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        height: 1.6,
                                        color: Color(0xFF354A43),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _page == 0
                                      ? null
                                      : () => setState(() => _page--),
                                  child: Text(isTr ? 'Geri' : 'Back'),
                                ),
                                Expanded(
                                  child: Text(
                                    '${_page + 1} / ${_images.length}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF244B43),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 2,
                                  fit: FlexFit.tight,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: _next,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF244B43),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                    ),
                                    child: Text(
                                      lastPage
                                          ? (isTr
                                                ? 'Yolculuğa Başla'
                                                : 'Start Journey')
                                          : (isTr ? 'Devam' : 'Next'),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ), // Scaffold
            ), // ConstrainedBox
          ), // Center
        ); // ColoredBox
      },
    );
  }
}
