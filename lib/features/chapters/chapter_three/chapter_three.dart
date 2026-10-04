import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game/story_controller.dart';
import '../../../localization/app_localizations.dart';
import '../../../ui/widgets.dart';

class ChapterThreeFishing extends StatelessWidget {
  const ChapterThreeFishing({super.key, required this.story});

  final StoryController story;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 12),
      StoryPill(tr('chapter3.eyebrow')),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Paper(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryHeading(story.bite ? tr('chapter3.pullNow') : tr('chapter3.waitTitle')),
              const SizedBox(height: 10),
              Text(
                story.fishingHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ink, fontSize: 13),
              ),
              const SizedBox(height: 16),
              StoryButton(
                !story.cast
                    ? tr('chapter3.cast')
                    : story.bite
                    ? tr('chapter3.pull')
                    : tr('chapter3.waitFloat'),
                icon: Icons.phishing_rounded,
                onPressed: story.bite ? story.fishingAction : null,
              ),
              const SizedBox(height: 8),
              Text(
                tr('chapter3.lagoonNote'),
                style: TextStyle(color: ink, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class ChapterThreeInspection extends StatelessWidget {
  const ChapterThreeInspection({
    super.key,
    required this.story,
    required this.onOpenBook,
    required this.onComplete,
  });

  final StoryController story;
  final VoidCallback onOpenBook;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        StoryPill(tr('chapter3.scanEyebrow')),
        const SizedBox(height: 15),
        Text(
          tr('chapter3.scanTitle'),
          style: TextStyle(
            fontFamily: 'StorySerif',
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: cream,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          tr('chapter3.scanNote'),
          style: TextStyle(color: cream, fontSize: 12),
        ),
        SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                const Positioned.fill(child: FishPicture(scan: true)),
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: c.maxWidth * (.40 + i * .08),
                    top: 115 + (i == 1 ? 12 : 0),
                    child: Semantics(
                      button: true,
                      label: tr('chapter3.microplastic', {'index': i + 1}),
                      child: GestureDetector(
                        onTap: () => story.discover(i),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: story.found.contains(i)
                                ? gold
                                : coral.withValues(alpha: .4),
                            border: Border.all(color: cream, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: .5),
                                blurRadius: 12 + sin(story.worldTime * 3) * 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            story.found.contains(i)
                                ? Icons.check
                                : i == 1
                                ? Icons.gesture
                                : Icons.scatter_plot,
                            size: 18,
                            color: story.found.contains(i) ? ink : cream,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StoryEyebrow(tr('chapter3.found', {'count': story.found.length})),
              const SizedBox(height: 10),
              Text(
                story.lastDiscovery ?? tr('chapter3.quote'),
                style: const TextStyle(color: ink, height: 1.6, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TapDownButton(
                onTap: onOpenBook,
                sound: TapDownButton.bookSound,
                builder: (pressed) => TextButton.icon(
                  onPressed: pressed,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(tr('chapter3.research')),
                ),
              ),
              const SizedBox(height: 8),
              StoryButton(
                tr('chapter3.complete'),
                onPressed: story.found.length == 3 ? onComplete : null,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
