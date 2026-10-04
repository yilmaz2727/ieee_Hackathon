import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esma_game/features/chapters/chapter_one/chapter_one.dart';
import 'package:esma_game/game/story_controller.dart';
import 'package:esma_game/localization/app_localizations.dart';
import 'package:esma_game/ui/widgets.dart';

// CH1 ilk turu (20 sn, sürükle-bırak ayırma) ChapterOne ekranında çalışır;
// süresi package:clock ile ölçüldüğü için tester.pump sahte zamanı ilerletir.

Future<StoryController> _pumpChapterOne(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final story = StoryController()..go(Scene.cleanupFirst);
  await tester.pumpWidget(
    MaterialApp(
      // Sabit tohum: atıklar her çalıştırmada aynı yerde, üst üste binmez.
      home: Scaffold(
        body: ChapterOne(story: story, random: Random(7)),
      ),
    ),
  );
  return story;
}

Future<void> _advance(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 10).round(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _bins = ['bins.plastic', 'bins.metal', 'bins.paper'];

Future<void> _dragToBin(WidgetTester tester, Finder item, int bin) async {
  final gesture = await tester.startGesture(tester.getCenter(item));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(find.text(tr(_bins[bin]))));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.instance.loadInitial(null);
  });

  testWidgets('Wrong bin cannot award points; the right bin clears water', (
    tester,
  ) async {
    final story = await _pumpChapterOne(tester);
    final items = find.byType(Draggable<int>);
    expect(items, findsWidgets);
    final item = items.first;
    final id = tester.widget<Draggable<int>>(item).data;
    final kind = tester
        .widget<WasteIcon>(
          find.descendant(of: item, matching: find.byType(WasteIcon)),
        )
        .kind;
    Finder sameItem() =>
        find.byWidgetPredicate((w) => w is Draggable<int> && w.data == id);

    await _dragToBin(tester, sameItem(), (kind + 1) % 3);
    expect(story.sortingMistakes, 1);
    expect(story.waterClarity[0], 0);
    expect(sameItem(), findsOneWidget);
    expect(find.text(tr('chapter1.score', {'score': 0})), findsOneWidget);

    await _dragToBin(tester, sameItem(), kind);
    expect(sameItem(), findsNothing);
    expect(story.waterClarity[0], closeTo(.1, 1e-9));
    expect(find.text(tr('chapter1.score', {'score': 10})), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Round lasts 20 seconds and the book pause stops the clock', (
    tester,
  ) async {
    final story = await _pumpChapterOne(tester);

    await _advance(tester, 10);
    expect(story.scene, Scene.cleanupFirst);

    // Kitap/duraklatma açıkken süre işlemez.
    story.setPaused(true);
    await _advance(tester, 30);
    expect(story.scene, Scene.cleanupFirst);
    story.setPaused(false);

    await _advance(tester, 9);
    expect(story.scene, Scene.cleanupFirst);
    await _advance(tester, 1.5);
    expect(story.scene, Scene.firstResult);
    expect(story.firstIncoming, greaterThan(5));

    await tester.pumpWidget(const SizedBox());
  });
}
