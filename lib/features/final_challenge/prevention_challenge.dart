import 'package:flutter/material.dart';

import '../../game/story_controller.dart';
import '../../localization/app_localizations.dart';
import '../../ui/widgets.dart';

class PreventionChallenge extends StatelessWidget {
  const PreventionChallenge({super.key, required this.story});

  final StoryController story;

  List<Map<String, Object>> get scenarios {
    final isTr = AppLocalizations.instance.isTurkish;

    String t(String trText, String enText) => isTr ? trText : enText;

    return [
      {
        'icon': Icons.recycling_rounded,
        'title': t('Şamlar’daki temizlik', 'Cleaning up at Şamlar'),
        'question': t(
          'Kıyıda bir plastik pipet, metal içecek kutusu ve temiz kâğıt buldun. '
              'Bunları nasıl ayırmalısın?',
          'You found a plastic straw, a metal drink can and clean paper on the '
              'shore. How should you sort them?',
        ),
        'options': <String>[
          t(
            'Hepsini kâğıt kutusuna atmalı.',
            'Put everything in the paper bin.',
          ),
          t(
            'Plastiği plastik, metali metal, kâğıdı kâğıt kutusuna atmalı.',
            'Put plastic, metal and paper in their matching bins.',
          ),
          t(
            'Küçük parçaları kıyıda bırakmalı.',
            'Leave the small pieces on the shore.',
          ),
        ],
        'correct': 1,
        'success': t(
          'Doğru! Oyunda yaptığın gibi atıkları türüne göre ayırmak, '
              'geri dönüşüme uygun atıkların işlenmesine yardımcı olur.',
          'Correct! Sorting waste by material helps suitable items '
              'enter the recycling process.',
        ),
      },
      {
        'icon': Icons.water_drop_outlined,
        'title': t('Pipet gerçekten kayboldu mu?', 'Did the straw disappear?'),
        'question': t(
          'Pipetin suda küçük parçalara ayrıldı. '
              'Bu, plastiğin artık zararsız olduğu anlamına gelir mi?',
          'Your straw broke into tiny pieces in the water. '
              'Does that mean the plastic is now harmless?',
        ),
        'options': <String>[
          t(
            'Evet, gözle görülmeyen plastik artık yoktur.',
            'Yes, plastic no longer exists once we cannot see it.',
          ),
          t(
            'Evet, küçük parçalar balıklar için besindir.',
            'Yes, small pieces are food for fish.',
          ),
          t(
            'Hayır, küçük plastik parçaları suda kalabilir ve canlılar tarafından yutulabilir.',
            'No, small plastic pieces can remain in the water and be swallowed by wildlife.',
          ),
        ],
        'correct': 2,
        'success': t(
          'Doğru! Parçalanmak, yok olmak değildir. Mikroplastikler '
              'canlılar tarafından yanlışlıkla yutulabilir.',
          'Correct! Breaking apart does not mean disappearing. '
              'Wildlife can accidentally swallow microplastics.',
        ),
      },
      {
        'icon': Icons.pets_outlined,
        'title': t('Sazlıdere’deki balık', 'The fish at Sazlıdere'),
        'question': t(
          'Sazlıdere’de balığı plastiklerden uzak tuttuk. '
              'Gerçek hayatta bu sorunu en baştan azaltmak için ne yapabiliriz?',
          'At Sazlıdere, we kept the fish away from plastic. '
              'What can we do in real life to reduce the problem at its source?',
        ),
        'options': <String>[
          t(
            'Tek kullanımlık plastiği azaltıp atıkların suya ulaşmasını önleyebiliriz.',
            'Reduce single-use plastic and prevent waste from reaching water.',
          ),
          t(
            'Plastikleri balıkların olmadığı başka bir kıyıya taşıyabiliriz.',
            'Move plastic to another shore where there are no fish.',
          ),
          t(
            'Plastikleri daha küçük parçalara ayırabiliriz.',
            'Break plastic into smaller pieces.',
          ),
        ],
        'correct': 0,
        'success': t(
          'Doğru! Balıkları korumanın önemli bir yolu, '
              'plastiğin suya hiç ulaşmamasını sağlamaktır.',
          'Correct! An important way to protect fish is to prevent '
              'plastic from entering the water in the first place.',
        ),
      },
      {
        'icon': Icons.search_rounded,
        'title': t('Küçükçekmece’deki keşif', 'The discovery at Küçükçekmece'),
        'question': t(
          'Balığın içini incelediğinde küçük plastik parçaları gördün. '
              'Bu keşif bize ne anlatıyor?',
          'When you examined the fish, you saw small plastic pieces inside it. '
              'What does this discovery tell us?',
        ),
        'options': <String>[
          t(
            'Suyun yüzeyi temiz görünüyorsa içinde plastik olamaz.',
            'If the water surface looks clean, there cannot be plastic in it.',
          ),
          t(
            'Kirliliğin bir kısmı dışarıdan görünmese de canlıları etkileyebilir.',
            'Pollution can affect wildlife even when some of it is not visible.',
          ),
          t(
            'Plastik yalnızca kıyıdaki taşları etkiler.',
            'Plastic only affects rocks on the shore.',
          ),
        ],
        'correct': 1,
        'success': t(
          'Doğru! Yalnızca suyun görünüşüne bakarak bütün kirliliği anlayamayız. '
              'Görünmeyen küçük parçalar da önemlidir.',
          'Correct! The appearance of water does not reveal all pollution. '
              'Tiny pieces that are hard to see matter too.',
        ),
      },
      {
        'icon': Icons.volunteer_activism_outlined,
        'title': t('Yeni alışkanlığın', 'Your new habit'),
        'question': t(
          'Bir sonraki pikniğe hazırlanıyorsun. '
              'Pipetin yolculuğunun yeniden yaşanmaması için hangisini seçmelisin?',
          'You are preparing for another picnic. '
              'Which choice can help prevent the straw’s journey from happening again?',
        ),
        'options': <String>[
          t(
            'Tekrar kullanılabilir matarayı almalı ve atıklarını ayrıştırmak için yanında götürmeli.',
            'Bring a reusable bottle and take your waste away for proper sorting.',
          ),
          t(
            'Atıklarını göl kenarındaki taşların altına saklamalı.',
            'Hide your waste under rocks beside the lake.',
          ),
          t(
            'Hafif çöpleri rüzgârın götürmesini beklemeli.',
            'Wait for the wind to carry away light rubbish.',
          ),
        ],
        'correct': 0,
        'success': t(
          'Doğru! Hikâyeyi değiştiren şey günlük seçimlerimizdir: '
              'daha az tek kullanımlık ürün, doğru ayrıştırma ve doğada atık bırakmamak.',
          'Correct! Everyday choices can change the story: fewer single-use '
              'items, proper sorting and leaving no rubbish in nature.',
        ),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) {
        final scenario = scenarios[story.preventionStep];
        final options = scenario['options'] as List<String>;
        final correct = scenario['correct'] as int;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: (story.preventionStep + 1) / 5,
                        minHeight: 8,
                        backgroundColor: cream.withValues(alpha: .65),
                        color: ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('prevention.progress', {
                      'current': story.preventionStep + 1,
                    }),
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Paper(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xffffe5a8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        scenario['icon'] as IconData,
                        size: 36,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StoryEyebrow(tr('prevention.eyebrow')),
                    const SizedBox(height: 8),
                    Text(
                      scenario['title'] as String,
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
                      scenario['question'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    for (var i = 0; i < options.length; i++) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: story.preventionAnswered
                              ? null
                              : () => story.answerPrevention(i, correct),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            backgroundColor:
                                story.preventionAnswered &&
                                    story.preventionSelected == i
                                ? i == correct
                                      ? const Color(0xffdcebd4)
                                      : const Color(0xffffdfd5)
                                : cream,
                            foregroundColor: ink,
                            side: BorderSide(
                              color:
                                  story.preventionAnswered &&
                                      story.preventionSelected == i
                                  ? i == correct
                                        ? const Color(0xff62936b)
                                        : const Color(0xffc87562)
                                  : const Color(0xffd5bd8c),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  options[i],
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (story.preventionAnswered &&
                                  story.preventionSelected == i)
                                Icon(
                                  i == correct
                                      ? Icons.check_circle_rounded
                                      : Icons.close_rounded,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (i != options.length - 1) const SizedBox(height: 10),
                    ],
                    if (story.preventionAnswered) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xffeef2df),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          story.preventionSelected == correct
                              ? scenario['success'] as String
                              : '${tr('prevention.wrongAnswer', {'answer': options[correct]})}'
                                    '\n\n${scenario['success']}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      StoryButton(
                        story.preventionStep == 4
                            ? tr('prevention.finish')
                            : tr('prevention.next'),
                        onPressed: story.nextPreventionScenario,
                        icon: story.preventionStep == 4
                            ? Icons.auto_awesome_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              StoryPill(
                tr('prevention.correctCount', {
                  'count': story.preventionCorrect,
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
