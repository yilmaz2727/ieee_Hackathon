import 'package:flutter/material.dart';

import '../../game/story_controller.dart';
import '../../localization/app_localizations.dart';
import '../../ui/widgets.dart';

class PreventionChallenge extends StatelessWidget {
  const PreventionChallenge({super.key, required this.story});

  final StoryController story;

  List<Map<String, Object>> get scenarios => [
    {
      'icon': Icons.local_drink_outlined,
      'title': tr('prevention.1.title'),
      'question': tr('prevention.1.question'),
      'options': [tr('prevention.1.option1'), tr('prevention.1.option2')],
      'correct': 1,
      'success': tr('prevention.1.success'),
    },
    {
      'icon': Icons.fastfood_outlined,
      'title': tr('prevention.2.title'),
      'question': tr('prevention.2.question'),
      'options': [tr('prevention.2.option1'), tr('prevention.2.option2')],
      'correct': 1,
      'success': tr('prevention.2.success'),
    },
    {
      'icon': Icons.air_rounded,
      'title': tr('prevention.3.title'),
      'question': tr('prevention.3.question'),
      'options': [tr('prevention.3.option1'), tr('prevention.3.option2')],
      'correct': 0,
      'success': tr('prevention.3.success'),
    },
    {
      'icon': Icons.delete_outline_rounded,
      'title': tr('prevention.4.title'),
      'question': tr('prevention.4.question'),
      'options': [tr('prevention.4.option1'), tr('prevention.4.option2')],
      'correct': 0,
      'success': tr('prevention.4.success'),
    },
    {
      'icon': Icons.backpack_outlined,
      'title': tr('prevention.5.title'),
      'question': tr('prevention.5.question'),
      'options': [tr('prevention.5.option1'), tr('prevention.5.option2')],
      'correct': 0,
      'success': tr('prevention.5.success'),
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                tr('prevention.progress', {'current': story.preventionStep + 1}),
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
                  style: const TextStyle(color: ink, fontSize: 14, height: 1.5),
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
                          : tr('prevention.wrongAnswer', {'answer': options[correct]}),
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
          StoryPill(tr('prevention.correctCount', {'count': story.preventionCorrect})),
        ],
      ),
    );
  }
}
