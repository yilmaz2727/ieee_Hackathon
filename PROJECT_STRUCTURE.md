# Esma Game – Project Structure

The project now uses a feature-oriented structure. Game chapters and post-story features live in their own folders, while shared game state and reusable UI stay separate.

```text
lib/
├── main.dart                         # App shell, navigation and scene orchestration
├── game/
│   ├── story_controller.dart         # Central story/game state
│   └── lake_game.dart                # Flame scene/painters used by the lake
├── features/
│   ├── chapters/
│   │   ├── chapters.dart             # Barrel export for all chapters
│   │   ├── chapter_one/
│   │   │   └── chapter_one.dart      # Chapter 1 intro + sorting game
│   │   ├── chapter_two/
│   │   │   └── chapter_two.dart      # Chapter 2 intro + microplastic avoidance
│   │   └── chapter_three/
│   │       └── chapter_three.dart    # Chapter 3 fishing + inspection
│   ├── final_challenge/
│   │   ├── final_challenge.dart      # Barrel export
│   │   ├── prevention_challenge.dart # 5-scenario eco-choice challenge
│   │   └── success_screen.dart       # Final score/result screen
│   ├── book/
│   │   └── book_sheet.dart           # Dedemin Doğa Kitabı
│   └── impact/
│       └── impact_screen.dart        # Real-world impact/photo map flow
├── services/
│   ├── certificate.dart
│   └── impact_store.dart
└── ui/
    ├── water_scene.dart               # Shared water/background layer
    └── widgets.dart                   # Reusable visual components
```

## Architecture rules

- `main.dart` coordinates scenes; it should not contain chapter gameplay implementations.
- Each chapter owns its own UI and interaction code under `features/chapters/`.
- Shared state stays in `game/story_controller.dart` so progress can flow between chapters.
- Reusable UI belongs in `ui/widgets.dart`; feature-specific UI stays in the feature folder.
- Persistent/storage logic belongs in `services/`.
- New features should be added under `features/<feature_name>/` instead of growing `main.dart`.

## Localization

- `lib/localization/app_localizations.dart`: runtime language service
- `assets/i18n/translations.json`: Turkish and English UI text catalog
