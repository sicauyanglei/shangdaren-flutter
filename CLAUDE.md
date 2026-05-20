# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**上大人字牌游戏** - A 3-player Mahjong-style Chinese character card game implemented as a Flutter + WebView hybrid. The game logic runs entirely in JavaScript loaded inside a Flutter WebView, with Flutter providing native Android integration (permissions, logging, audio).

## Build Commands

```bash
cd flutter_app
flutter build apk                          # Debug APK
flutter build apk --release               # Release APK
flutter build appbundle --release         # Android App Bundle
flutter run                               # Run on connected device
flutter analyze                          # Dart linting
```

## Architecture

### Hybrid Structure
- **Flutter Layer** (`lib/main.dart`): WebView container, native permissions, file logging, memory monitoring
- **Web Layer** (`assets/html/`): Complete game UI and logic in HTML/CSS/JavaScript

### Key Files
| File | Purpose |
|------|---------|
| `flutter_app/lib/main.dart` | Flutter entry - WebView host, native log file, memory monitoring |
| `flutter_app/assets/html/index.html` | Game HTML/CSS UI (landscape, responsive) |
| `flutter_app/assets/html/game.js` | All game logic - card operations, AI, scoring, tilings |
| `flutter_app/assets/html/sw.js` | Service worker for offline caching |
| `flutter_app/assets/html/audio/` | Sound effects and voice prompts |

### Game Data Structures
- **Characters**: 24 unique characters (上大人丘乙己化三千七十土尔小生八九子佳作亡福禄寿)
- **Card Colors**: Red (`上大人`), Green (`化三千七十`), Black (rest)
- **Sentences**: 8 three-character combinations for matching bonuses

### WebView Communication
Flutter communicates with the WebView via `JavaScriptChannel` named `'FlutterBridge'`:
- `SDR_LOG:*` → native logging
- `AUTOTEST_LOG:*` → test logging
- `TEST_DONE:*` → test completion
- `ROUND_END` → round ended, trigger GC
- `exit` → exit app

### Native Integration
- **Logging**: Writes to `/storage/emulated/0/DCIM/ShangDaRen/game_log_*.txt`
- **Memory**: Monitors RSS, forces JS GC when >350MB
- **Audio**: Initialized on first user interaction