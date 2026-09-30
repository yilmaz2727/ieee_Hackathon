import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:esma_game/game/story_controller.dart';
import 'package:esma_game/localization/app_localizations.dart';

void advance(StoryController c, double seconds) {
  for (var i = 0; i < (seconds * 20).ceil(); i++) {
    c.tick(.05);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppLocalizations.instance.loadInitial(null);
  });
  test('Three places map to the intended chapters', () {
    final c = StoryController(random: Random(1));
    c.go(Scene.cleanupFirst);
    expect(c.chapter, 1);
    expect(c.location, tr('chapter.location.1'));
    c.go(Scene.protection);
    expect(c.chapter, 2);
    expect(c.location, tr('chapter.location.2'));
    c.go(Scene.fishing);
    expect(c.chapter, 3);
    expect(c.location, tr('chapter.location.3'));
  });
  test('Wrong sorting cannot award points; sorting and book pause time', () {
    final c = StoryController(random: Random(2));
    c.go(Scene.cleanupFirst);
    final w = c.waste.first;
    c.selectWaste(w.id);
    c.sortWaste((w.kind + 1) % 3);
    expect(c.collected, 0);
    expect(c.selectedWaste, isNotNull);
    advance(c, 5);
    expect(c.elapsed, 0);
    c.sortWaste(w.kind);
    expect(c.collected, 1);
    expect(c.selectedWaste, isNull);
    c.setPaused(true);
    advance(c, 5);
    expect(c.elapsed, 0);
    c.setPaused(false);
    advance(c, 1);
    expect(c.elapsed, closeTo(1, .001));
  });
  test('First round runs 20 seconds with reduced incoming waste', () {
    final c = StoryController(random: Random(3));
    c.go(Scene.cleanupFirst);
    advance(c, 19);
    expect(c.scene, Scene.cleanupFirst);
    expect(c.incoming, lessThan(30));
    advance(c, 1.1);
    expect(c.scene, Scene.firstResult);
    expect(c.firstIncoming, lessThan(30));
  });
  test('Chapter 2 stays locked when fewer than 10 items were collected', () {
    final c = StoryController();
    c.firstCollected = 9;
    c.go(Scene.firstResult);
    c.go(Scene.underwater);
    expect(c.scene, Scene.firstResult);

    c.firstCollected = 10;
    c.go(Scene.underwater);
    expect(c.scene, Scene.underwater);
  });
  test('Protection is playable for 30 seconds and counts real collisions', () {
    final c = StoryController(random: Random(4));
    c.go(Scene.protection);
    c.waste.add(Waste(999, .5, .719, 0, 1));
    c.tick(.05);
    expect(c.swallowed, 1);
    c.moveFish(.9);
    c.waste.add(Waste(1000, .1, .859, 0, 1));
    c.tick(.05);
    expect(c.avoided, 1);
    advance(c, 29);
    expect(c.scene, Scene.protection);
    advance(c, 1.1);
    expect(c.scene, Scene.protectionResult);
  });
  test('Fishing yields litter twice then a fish; early input cannot win', () {
    final c = StoryController();
    c.go(Scene.fishing);
    for (var catchNo = 1; catchNo <= 3; catchNo++) {
      c.fishingAction();
      c.fishingAction();
      expect(c.scene, Scene.fishing);
      advance(c, 3.1);
      expect(c.bite, isTrue);
      c.fishingAction();
      expect(c.scene, catchNo < 3 ? Scene.catchWaste : Scene.inspection);
      if (catchNo < 3) c.go(Scene.fishing);
    }
    c.discover(0);
    c.discover(0);
    expect(c.found.length, 1);
    c.discover(1);
    c.discover(2);
    expect(c.found.length, 3);
  });
  test('Replay requires prevention and its target is actually attainable', () {
    final c = StoryController(random: Random(5));
    c.go(Scene.prevention);
    c.startSecond();
    expect(c.scene, Scene.prevention);
    for (var i = 0; i < 3; i++) {
      c.prevent(i);
    }
    c.startSecond();
    expect(c.scene, Scene.cleanupSecond);
    for (var tick = 0; tick < 920 && c.scene == Scene.cleanupSecond; tick++) {
      for (final w in List<Waste>.from(c.waste)) {
        c.selectWaste(w.id);
        c.sortWaste(w.kind);
      }
      c.tick(.05);
    }
    expect(c.scene, Scene.success);
    expect(c.completed, isTrue);
    expect(c.collected, greaterThanOrEqualTo(StoryController.secondTarget));
    expect(c.incoming, lessThan(20));
  });
  test('No collection in replay must not grant completion', () {
    final c = StoryController();
    c.go(Scene.prevention);
    for (var i = 0; i < 3; i++) {
      c.prevent(i);
    }
    c.startSecond();
    advance(c, 45.1);
    expect(c.scene, Scene.retry);
    expect(c.completed, isFalse);
  });
}
