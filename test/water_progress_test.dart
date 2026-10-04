import 'package:flutter_test/flutter_test.dart';
import 'package:esma_game/game/story_controller.dart';

void main() {
  test('Each location starts dirty and has a distinct image', () {
    final c = StoryController();
    final assets = <String>{};
    for (final scene in [Scene.intro, Scene.underwater, Scene.fishing]) {
      c.go(scene);
      assets.add(c.backgroundAsset);
      expect(c.clarity, 0);
    }
    expect(assets.length, 3);
  });
  test('Only correct sorting clears water, and a new run resets it', () {
    final c = StoryController()..go(Scene.cleanupFirst);
    final w = c.waste.first;
    c.selectWaste(w.id);
    c.sortWaste((w.kind + 1) % 3);
    expect(c.clarity, 0);
    c.sortWaste(w.kind);
    expect(c.clarity, .1);
    c.tick(.05);
    expect(c.visibleClarity[0], greaterThan(0));
    expect(c.visibleClarity[0], lessThan(c.clarity));
    c.go(Scene.firstResult);
    expect(c.clarity, .1);
    c.startNew();
    expect(c.waterClarity, [0, 0, 0]);
    expect(c.visibleClarity, [0, 0, 0]);
  });
  test('Swallowed plastic cannot clean water; net captures can', () {
    final c = StoryController()..go(Scene.protection);
    c.waste.add(Waste(900, .5, .72, 0, .2));
    c.tick(.05);
    expect(c.swallowed, 1);
    expect(c.clarity, 0);
    c.waste.add(Waste(901, .1, .86, 0, .2));
    c.tick(.05);
    expect(c.avoided, 1);
    expect(c.clarity, .05);
    c.go(Scene.protectionResult);
    expect(c.clarity, .05);
  });
  test('Two litter catches restore the lagoon and persist between casts', () {
    final c = StoryController()..go(Scene.fishing);
    for (var i = 1; i <= 2; i++) {
      c.castFishingAt(.5, .5);
      // ~3,1 sn: şamandıra batar (bite).
      for (var j = 0; j < 62; j++) {
        c.tick(.05);
      }
      c.fishingAction();
      expect(c.scene, Scene.catchWaste);
      expect(c.clarity, i / 2);
      c.go(Scene.fishing);
      expect(c.clarity, i / 2);
    }
    c.resumeChapter(3);
    expect(c.clarity, 0);
    expect(c.catches, 0);
  });
  test('Return and success show Samlar, keeping its restoration', () {
    final c = StoryController();
    c.waterClarity[0] = 1;
    c.go(Scene.success);
    expect(c.chapter, 1);
    expect(c.backgroundAsset, endsWith('samlar.png'));
    expect(c.clarity, 1);
  });
}
