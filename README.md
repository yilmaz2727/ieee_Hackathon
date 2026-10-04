# Guardian of the Water

### The Straw’s Journey · Suyun Koruyucusu — Pipetin Yolculuğu

**Discover the problem. Protect aquatic life. Turn learning into action.**

An interactive environmental education game by **Team Moon**, developed for the **OneAquaHealth IEEE Global Hackathon 2026**.

Guardian of the Water follows the story of a discarded straw through three water settings in Türkiye. Through illustrated storytelling, hands-on mini-games, everyday choices, and an optional real-world cleanup mission, it helps young players explore how their actions connect to aquatic ecosystems.

**Built with Flutter and Flame · Turkish and English interfaces · Web and Android targets**

## Why this project exists

A piece of litter can leave our sight without leaving the environment. For children, the connection between a discarded object, pollution in water, and its consequences for living things can be difficult to see.

Our game makes that connection tangible. Players sort waste, identify pollution sources, protect fish from microplastics, and choose ways to prevent litter from reaching water. An optional cleanup mission then connects the learning experience to participation beyond the screen.

The intended audience is children and young learners, with opportunities for guided use by educators and families. Learning outcomes and long-term behavior change remain goals to evaluate through user studies.

## OneAquaHealth alignment

The project is designed around **Awareness & Storytelling**, supported by community and gamification mechanics.

It introduces the **One Health** perspective: environmental conditions, animal health, and human well-being are connected. The story focuses on pollution prevention and aquatic life, while the real-world mission encourages participation in caring for shared water environments.

The experience follows four stages:

| Stage | Player experience | Intended learning outcome |
| --- | --- | --- |
| Notice | Compare clean and polluted scenes | Recognize sources of water pollution |
| Understand | Follow plastic fragmentation and protect fish | Connect discarded waste with risks to aquatic life |
| Choose | Respond to everyday environmental scenarios | Practice preventing waste before it reaches water |
| Participate | Complete an optional cleanup mission | Connect environmental learning with responsible action |

## Explore the journey

### Chapter 1 — Şamlar Nature Park

Sort incoming waste into plastic, metal, and paper bins. Then compare two scenes and find five differences linked to pollution sources.

**Learning focus:** waste separation, observation, and the ways litter and other pollutants can reach water.

### Chapter 2 — Sazlıdere Reservoir

Guide a fish away from microplastic particles, then find five distressed fish and help them through a symbolic recovery activity. Grandpa’s illustrated book connects the mini-games to the story of plastic breaking into smaller pieces over time.

**Learning focus:** plastic fragmentation, aquatic life, and empathy for affected animals.

### Chapter 3 — Küçükçekmece

Cast a fishing line, encounter discarded waste, and explore a stylized inspection scene that makes otherwise hard-to-see pollution visible.

**Learning focus:** the difference between visible litter and less visible pollution.

### Change the ending

Make five everyday choices about preventing litter and complete a nine-piece picture puzzle. Scores, badges, and downloadable achievement certificates recognize progress through the experience.

**Learning focus:** applying the story’s lessons to daily decisions.

### Take action beyond the game

The optional real-world mission combines:

1. Device location and a nearby water-source lookup.
2. A cleanup-related photo captured or selected by the player.
3. AI-assisted assessment of visible cleanup evidence.
4. A contribution marker saved to the local map after approval and confirmation.
5. An achievement reward linked to the completed mission.

Players can also continue without submitting a photo. Children should undertake real-world activities with adult supervision, stay out of the water, and avoid sharp or unknown waste.

## Key features

- **Story-driven progression:** an illustrated book connects the activities across three locations.
- **Varied interactions:** drag-and-drop sorting, spot-the-difference, fish protection, symbolic recovery, fishing, quizzes, and a picture puzzle.
- **Bilingual interface:** Turkish and English translations with an in-app language selector.
- **Audio experience:** background music, sound effects, and adjustable music volume.
- **Player progression:** local profiles, scores, badges, and a local leaderboard.
- **Achievement certificates:** downloadable PDF certificates with Turkish and English options.
- **Real-world participation:** location lookup, AI-assisted photo assessment, and a local contribution map.

## Technical overview

| Component | Implementation |
| --- | --- |
| Application and interface | Flutter / Dart |
| Game rendering and interactions | Flutter widgets, custom drawing, and Flame |
| Shared game state | `StoryController` |
| Photo assessment | Gemini through `google_generative_ai` |
| Device location | `geolocator` |
| Water-source lookup | OpenStreetMap data through the Overpass API |
| Map rendering | `flutter_map` and OpenStreetMap tiles |
| Local persistence | `shared_preferences` and browser local storage |
| Audio | `audioplayers` |
| PDF generation | `pdf` and `printing` |
| Localization | JSON translations in `assets/i18n/` |

Game chapters and the real-world mission are organized into separate feature modules. The app shell manages navigation, shared services handle persistence and rewards, and the story controller coordinates game progress.

### How photo assessment works

The application optimizes the selected image and sends it to Gemini with criteria for visible cleanup evidence. The service requests a structured acceptance decision and a short explanation. An unsuccessful API request does not automatically approve the mission.

This is **AI-assisted evidence screening**, not proof of who performed a cleanup, when it happened, or whether the image was captured at the reported location. Device location and photo assessment are separate checks.

## Run locally

### Prerequisites

- Flutter SDK with a Dart version compatible with `>=3.8.0 <4.0.0`.
- Chrome for the web target, or an Android SDK and an Android device/emulator.
- Internet access for dependency installation, map services, water-source lookup, and AI assessment.
- A Gemini API key with access to a model supported by your account, if testing photo assessment.

### 1. Open the project

Clone or download this repository and open the directory containing `pubspec.yaml`.

### 2. Configure the local environment

Create a `.env` file in the project root:

```dotenv
GEMINI_API_KEY=your_api_key_here
```

The current project declares `.env` as an asset, so create the file before running the app. If you are only exploring the game, leave the value empty; AI photo approval will remain unavailable.

Model identifiers are configured in:

```text
lib/features/cleanup_verification/data/services/gemini_vision_service.dart
```

Check that the configured models are available to your API account before demonstrating this feature.

**API key handling:** keep `.env` out of version control. The prototype currently loads the key from a client asset; this does not protect the key in a distributed build. Public deployment should route AI requests through a server that holds the credentials.

### 3. Install dependencies and launch

```bash
flutter pub get
flutter run -d chrome
```

For Android, list available devices and use the desired device ID:

```bash
flutter devices
flutter run -d <device-id>
```

Allow location access when testing the real-world mission. Browser geolocation requires a secure context such as localhost or HTTPS.

### Build

```bash
# Web
flutter build web --release

# Android
flutter build apk --release
```

### Development checks

```bash
flutter analyze
flutter test
```

The repository includes tests for areas such as story state, sorting, fish recovery, the picture puzzle, localization, certificates, and local contribution storage. Run these checks against the version you intend to submit; this README does not assert a current passing result.

## Project structure

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | App shell and scene navigation |
| `lib/game/` | Shared story state and game components |
| `lib/features/chapters/` | Chapter gameplay and learning activities |
| `lib/features/book/` | Illustrated storybook |
| `lib/features/final_challenge/` | Everyday choices and completion screens |
| `lib/features/impact/` | Picture puzzle and impact-related screens |
| `lib/features/cleanup_verification/` | Real-world mission, AI assessment, location, map, and leaderboard |
| `lib/features/auth/` | Local player onboarding |
| `lib/services/` | Rewards, certificates, and supporting services |
| `lib/localization/` | Translation loading |
| `assets/` | Illustrations, audio, fonts, and translations |
| `test/` | Automated tests |

## Prototype scope and data handling

- **Local records:** profiles, scores, leaderboard entries, and contribution markers are stored on the current device/browser. They are not synchronized between devices or shared through an online community backend.
- **External services:** photo assessment sends the selected image to Gemini; water-source lookup sends coordinates to Overpass; the map requests OpenStreetMap tiles. These features require connectivity.
- **Local progress is not a cloud backup:** clearing application or browser data can remove saved records.
- **Location precision:** the current water-source query searches within 10 km, while some messages still refer to 100 m. This inconsistency must be resolved before claiming precise proximity verification.
- **Educational simulation:** fish recovery and the inspection view are symbolic teaching activities, not treatment or diagnostic tools. Game scores are not measurements of environmental quality.
- **Geographic storytelling:** locations, scale, and time are used illustratively. The chapters do not claim a continuous real-world flow route; Küçükçekmece is a lagoon setting.
- **Achievement recognition:** downloadable certificates acknowledge in-game progress; they are not official IEEE certificates.

## Next steps

1. **Pilot with learners and educators:** evaluate usability, comprehension, and age-appropriate presentation.
2. **Measure learning:** compare pre/post activity responses and track mission completion without treating game scores as proof of real-world impact.
3. **Build a shared backend:** introduce authenticated accounts, synchronized contribution records, and community leaderboards.
4. **Strengthen participation safeguards:** add moderation, clearer consent flows, and controls suited to young users.
5. **Harden external integrations:** move AI credentials server-side, align location thresholds and messages, and improve evidence review.
6. **Expand educational content:** add water settings, languages, and teacher-guided activities based on pilot feedback.

## Team and acknowledgments

Created by **Team Moon** for the **OneAquaHealth IEEE Global Hackathon 2026**.

Built using Flutter, Flame, Gemini, and the OpenStreetMap ecosystem. Map data is credited to [OpenStreetMap contributors](https://www.openstreetmap.org/copyright). See [SOURCES.md](SOURCES.md) for the repository’s educational references.

**Every piece of litter has a journey. Every player can help change its ending.**
