import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esma_game/features/impact/fish_puzzle_screen.dart';
import 'package:esma_game/game/story_controller.dart';
import 'package:esma_game/localization/app_localizations.dart';

Future<SharedPreferences> _pumpPuzzle(
  WidgetTester tester, {
  VoidCallback? onFinish,
}) async {
  // Tahta ve tüm parçalar kaydırmadan görünsün.
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await SharedPreferences.getInstance();
  final story = StoryController()..go(Scene.fishPuzzle);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FishPuzzleScreen(story: story, onFinish: onFinish),
      ),
    ),
  );
  // Görsel gerçek asenkron işlemle (rootBundle + codec) yüklenir.
  await tester.runAsync(() async {
    for (
      var i = 0;
      i < 50 && find.byType(Draggable<int>).evaluate().isEmpty;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();
    }
  });
  await tester.pump();
  expect(find.byType(Draggable<int>), findsNWidgets(9));
  return prefs;
}

Future<void> _drop(WidgetTester tester, int piece, int slot) async {
  final from = tester.getCenter(find.byKey(ValueKey('puzzle-piece-$piece')));
  final to = tester.getCenter(find.byKey(ValueKey('puzzle-slot-$slot')));
  final gesture = await tester.startGesture(from);
  await tester.pump();
  for (var step = 1; step <= 5; step++) {
    await gesture.moveTo(Offset.lerp(from, to, step / 5)!);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.instance.loadInitial(null);
  });

  testWidgets('A piece is accepted only in its own slot', (tester) async {
    await _pumpPuzzle(tester);
    expect(find.textContaining('0/9'), findsOneWidget);

    await _drop(tester, 0, 4);
    expect(find.textContaining('0/9'), findsOneWidget);
    expect(find.byKey(const ValueKey('puzzle-piece-0')), findsOneWidget);

    await _drop(tester, 0, 0);
    expect(find.textContaining('1/9'), findsOneWidget);
    expect(find.byKey(const ValueKey('puzzle-piece-0')), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Placing all nine pieces finishes and saves the score', (
    tester,
  ) async {
    var finished = false;
    final prefs = await _pumpPuzzle(tester, onFinish: () => finished = true);

    for (var i = 0; i < 9; i++) {
      await _drop(tester, i, i);
    }
    await tester.pump();
    expect(find.text('Göl yeniden bir bütün!'), findsOneWidget);
    expect(prefs.getInt('puzzle_score'), greaterThanOrEqualTo(20));

    await tester.tap(find.text('Hikâyeye devam et'));
    await tester.pump();
    expect(finished, isTrue);

    await tester.pumpWidget(const SizedBox());
  });
}
