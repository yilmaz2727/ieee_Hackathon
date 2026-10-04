import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esma_game/features/chapters/chapter_two/chapter_two_healing.dart';
import 'package:esma_game/game/story_controller.dart';
import 'package:esma_game/localization/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    return AppLocalizations.instance.loadInitial(null);
  });

  test(
    'Exactly five patients require three taps; healthy fish never score',
    () {
      final story = StoryController(random: Random(42))..go(Scene.fishHealing);
      expect(story.chapter, 2);
      expect(story.healingTaps.length, 15);
      expect(story.healingTaps.where((v) => v == 0).length, 5);
      expect(story.healingTaps.where((v) => v == -1).length, 10);
      final sick = [
        for (var i = 0; i < 15; i++)
          if (story.healingTaps[i] == 0) i,
      ];
      final healthy = story.healingTaps.indexOf(-1);
      expect(story.healFish(healthy), isFalse);
      expect(story.healFish(-1), isFalse);
      expect(story.healFish(15), isFalse);
      story.go(Scene.fishHealingResult);
      expect(story.scene, Scene.fishHealing);
      story.setPaused(true);
      expect(story.healFish(sick.first), isFalse);
      story.setPaused(false);
      for (var n = 0; n < sick.length; n++) {
        for (var tap = 1; tap <= 3; tap++) {
          expect(story.healFish(sick[n]), isTrue);
          expect(story.healingTaps[sick[n]], tap);
          expect(story.healedFish, n + (tap == 3 ? 1 : 0));
        }
        expect(story.healFish(sick[n]), isFalse);
      }
      expect(story.healingComplete, isTrue);
      story.go(Scene.fishHealingResult);
      expect(story.chapter, 2);
      expect(story.scene, Scene.fishHealingResult);
      story.go(Scene.fishing);
      expect(story.chapter, 3);
      story.startNew();
      expect(story.healingTaps, isEmpty);
      story.dispose();
    },
  );

  test('Progress survives home, restore and both healing checkpoints', () {
    final story = StoryController(random: Random(2))..go(Scene.fishHealing);
    final sick = story.healingTaps.indexOf(0);
    story.healFish(sick);
    final saved = List<int>.of(story.healingTaps);
    story.go(Scene.home);
    story.resumeChapter(7);
    expect(story.healingTaps, saved);
    final restored = StoryController()..restoreHealing(saved);
    restored.resumeChapter(7);
    expect(restored.scene, Scene.fishHealing);
    expect(restored.healingTaps, saved);
    for (var i = 0; i < 15; i++) {
      for (var t = 0; t < 3; t++) {
        restored.healFish(i);
      }
    }
    final completed = StoryController()..restoreHealing(restored.healingTaps);
    completed.resumeChapter(8);
    expect(completed.scene, Scene.fishHealingResult);
    completed.go(Scene.protection);
    expect(completed.healingTaps, isEmpty);
    final invalid = StoryController()..restoreHealing(List.filled(15, 0));
    expect(invalid.healingTaps, isEmpty);
    for (final c in [story, restored, completed, invalid]) {
      c.dispose();
    }
  });

  for (final size in [
    const Size(390, 660),
    const Size(320, 420),
    const Size(500, 250),
  ]) {
    testWidgets('Fish grid, toast and completion at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final story = StoryController(random: Random(42))..go(Scene.fishHealing);
      final captureKey = GlobalKey();
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xff1c6571),
            body: RepaintBoundary(
              key: captureKey,
              child: ChapterTwoHealingGame(
                story: story,
                onComplete: () => completed = true,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('healing-counter')), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
      final healthy = story.healingTaps.indexOf(-1);
      final healthyFinder = find.byKey(ValueKey('healing-fish-$healthy'));
      await tester.ensureVisible(healthyFinder);
      await tester.tap(healthyFinder);
      await tester.pump();
      expect(find.text(tr('chapter2.healing.healthy')), findsOneWidget);
      expect(story.healedFish, 0);
      for (var i = 0; i < 15; i++) {
        if (story.healingTaps[i] < 0) continue;
        final fish = find.byKey(ValueKey('healing-fish-$i'));
        await tester.ensureVisible(fish);
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(fish);
          await tester.pump(const Duration(milliseconds: 400));
        }
      }
      expect(story.healedFish, 5);
      expect(
        find.text(tr('chapter2.healing.counter', {'count': 5})),
        findsOneWidget,
      );
      final button = find.text(tr('chapter2.healing.continue'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      story.dispose();
    });
  }

  testWidgets('Capture healing appearance before and after treatment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 660);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final story = StoryController(random: Random(42))..go(Scene.fishHealing);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xff1c6571),
          body: RepaintBoundary(
            key: key,
            child: ChapterTwoHealingGame(story: story, onComplete: () {}),
          ),
        ),
      ),
    );
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/qa').create(recursive: true);
        await File(
          'build/qa/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('healing-before');
    for (var i = 0; i < 15; i++) {
      for (var t = 0; t < 3; t++) {
        story.healFish(i);
      }
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await capture('healing-after');
    await tester.pumpWidget(const SizedBox());
    story.dispose();
  });
}
