import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esma_game/main.dart';
import 'package:esma_game/localization/app_localizations.dart';
import 'package:esma_game/game/story_controller.dart';
import 'package:esma_game/services/guardian_rewards.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/qa').create(recursive: true);
    await File('build/qa/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

// Uygulama, giriş yapmış kullanıcı yoksa LoginScreen açar; oyun ekranlarını
// sınamak için kayıtlı bir test kullanıcısıyla başlanır.
const _loggedInUser = <String, Object>{
  'current_user_id': 'test-user',
  'current_user_nickname': 'Test',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalizations.instance.loadInitial(null);
  });
  testWidgets('Main scenes fit mobile and expose real actions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(_loggedInUser);
    final prefs = await SharedPreferences.getInstance();
    final story = StoryController();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: EsmaApp(prefs: prefs, controller: story),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 800)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(tr('home.startAdventure')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, '01_home');
    await tester.tap(find.text(tr('home.startAdventure')));
    await tester.pump();
    // "Maceraya başla" önce hikâye girişini (StoryIntro) açar; atlanınca
    // CH1 girişi gelir.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Atla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(tr('chapter1.start')), findsOneWidget);
    await tester.tap(find.text(tr('chapter1.start')));
    await tester.pump();
    expect(find.text(tr('bins.plastic')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, '02_sorting');
    for (final pair in [
      (Scene.protection, '03_protection'),
      (Scene.inspection, '04_inspection'),
      (Scene.prevention, '05_replay'),
      (Scene.reward, '06_badge'),
    ]) {
      story.go(pair.$1);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await capture(tester, key, pair.$2);
    }
    // Ödül ekranında artık isim alanı yok (isim girişteki takma addan gelir).
    expect(find.byType(GuardianRewardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Animation frames and resizes never notify during build', (
    tester,
  ) async {
    final story = StoryController();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(_loggedInUser);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(EsmaApp(prefs: prefs, controller: story));
    for (final scene in [
      Scene.intro,
      Scene.cleanupFirst,
      Scene.protection,
      Scene.fishing,
    ]) {
      story.go(scene);
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(420, 900);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
    }
    final time = story.worldTime;
    expect(time, greaterThan(0));
    story.setPaused(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(story.worldTime, time);
    await tester.pumpWidget(const SizedBox());
    story.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Leaving the new-game story early resumes the story, '
      'not the old save', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Eski kayıt: CH1 fark bulma oyunu.
    SharedPreferences.setMockInitialValues({
      ..._loggedInUser,
      'chapter': 5,
      'cleanup_count': 12,
    });
    final prefs = await SharedPreferences.getInstance();
    final story = StoryController();
    await tester.pumpWidget(EsmaApp(prefs: prefs, controller: story));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text(tr('home.newAdventure')));
    await tester.pump();
    await tester.tap(find.text(tr('newGame.restart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Atla'), findsOneWidget);
    expect(prefs.getInt('chapter'), StoryController.storyIntroCheckpoint);
    expect(prefs.getInt('cleanup_count'), isNull);

    // Hikâyeyi bitirmeden geri çık.
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(story.scene, Scene.home);

    // Devam: fark bulmaya değil, hikâyeye döner.
    await tester.tap(find.text(tr('home.resume')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(story.scene, isNot(Scene.differencePuzzle));
    expect(find.text('Atla'), findsOneWidget);

    await tester.tap(find.text('Atla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(story.scene, Scene.intro);
    expect(find.text(tr('chapter1.start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Home does not overflow a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EsmaApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
