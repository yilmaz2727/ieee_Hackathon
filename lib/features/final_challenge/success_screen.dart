import 'package:flutter/material.dart' hide Badge;

import '../../game/story_controller.dart';
import '../../localization/app_localizations.dart';
import '../../ui/widgets.dart';

class FinalSuccessScreen extends StatelessWidget {
  const FinalSuccessScreen({
    super.key,
    required this.story,
    required this.onContinue,
  });

  final StoryController story;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) {
        final finalQuizScore = story.preventionCorrect * 20;
        final collectedTrashScore = story.firstCollected;
        final savedFromMicroplastics = story.avoided;
        final totalMicroplastics = story.avoided + story.swallowed;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Paper(
            child: Column(
              children: [
                const Badge(size: 150),
                StoryEyebrow(tr('success.eyebrow')),
                const SizedBox(height: 10),
                StoryHeading(tr('success.title')),
                const SizedBox(height: 12),
                _MiniResult(
                  title: tr('success.finalScore'),
                  value: '$finalQuizScore',
                  note: tr('success.correct', {
                    'count': story.preventionCorrect,
                  }),
                ),
                const SizedBox(height: 18),
                Text(
                  tr('success.body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink, fontSize: 14, height: 1.7),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _MiniResult(
                        title: tr('success.collected'),
                        value: '$collectedTrashScore',
                        note: tr('success.collectedNote'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniResult(
                        title: tr('success.protected'),
                        value: '$savedFromMicroplastics',
                        note: tr('success.protectedNote', {
                          'total': totalMicroplastics,
                          'saved': savedFromMicroplastics,
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  tr('success.note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ink, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 22),
                StoryButton(
                  tr('success.realWorld'),
                  onPressed: onContinue,
                  icon: Icons.photo_camera_outlined,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniResult extends StatelessWidget {
  const _MiniResult({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xffe3ebd8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 9,
            color: ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            color: ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          note,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: ink),
        ),
      ],
    ),
  );
}
