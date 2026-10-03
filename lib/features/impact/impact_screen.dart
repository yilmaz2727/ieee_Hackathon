import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fish_puzzle_screen.dart';
import '../cleanup_verification/presentation/screens/final_mission_screen.dart';

class ImpactScreen extends StatelessWidget {
  final SharedPreferences? prefs;
  final bool allowCreate;
  final VoidCallback onFinish;

  const ImpactScreen({
    super.key,
    this.prefs,
    this.allowCreate = false,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    if (allowCreate) {
      return const FinalMissionScreen();
    }
    return FishPuzzleScreen(onFinish: onFinish);
  }
}
