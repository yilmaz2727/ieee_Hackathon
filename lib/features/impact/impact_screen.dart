import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/story_controller.dart';
import 'fish_puzzle_screen.dart';
import '../cleanup_verification/presentation/screens/final_mission_screen.dart';

class ImpactScreen extends StatelessWidget {
  const ImpactScreen({
    super.key,
    this.prefs,
    this.allowCreate = false,
    required this.story,
    required this.beforeVerify,
    required this.onFinish,
  });

  final SharedPreferences? prefs;
  final bool allowCreate;
  final StoryController story;
  final Future<void> Function() beforeVerify;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    if (allowCreate) {
      return FinalMissionScreen(
        beforeVerify: beforeVerify,
        onComplete: onFinish,
      );
    }

    return FishPuzzleScreen(
      story: story,
      onFinish: onFinish,
    );
  }
}