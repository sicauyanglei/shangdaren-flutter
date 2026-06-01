# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**上大人字牌游戏** - A 3-player Mahjong-style Chinese character card game built with Flutter and the Flame game engine. The game renders via Flame components and all logic is in Dart.

## Build Commands

```bash
cd flutter_app
flutter pub get                  # Install dependencies
flutter build apk                # Debug APK
flutter build apk --release      # Release APK
flutter build appbundle --release # Android App Bundle
flutter run                      # Run on connected device
flutter analyze                  # Dart linting
flutter test                     # Run all tests
flutter test test/widget_test.dart  # Run single test file
```

## Architecture

### Entry Point
- `lib/main.dart` - `ShangdarenApp` widget, `GameHomePage` stateful widget, overlays management

### Flame Game (`lib/game/shangdaren_game.dart`)
- `ShangdarenGame extends FlameGame` - orchestrates all subsystems
- Camera: fixed 1280×720, centered in viewport
- Calls `_gameController.startGame()` / `startRound()` to begin
- Bridges Flame rendering with Flutter UI via callbacks (`onGameStateChanged`, `onShowHu`, `onShowSettlement`)

### State Machine (`lib/game/logic/game_controller.dart`)
- `GameController` - central game flow controller
- States: dealing → player turns → responses (chi/peng/zhao/hu) → round end → settlement
- 3 players: index 0=AI left, 1=human (player 1), 2=AI right
- Dealer starts at index 0 (AI left player), rotates on dianpao
- 8 rounds per game; after 8 rounds shows settlement
- Priority order for responses: hu > zhao > peng > chi
- Uses `AIController` for AI decision-making (`lib/game/logic/ai/ai_controller.dart`)

### Flame-to-Flutter Bridge (`lib/game/shangdaren_game.dart`)
- `ShangdarenGame extends FlameGame` orchestrates all subsystems
- Camera: fixed 1280×720, centered in viewport via `StretchViewport`
- Bridges Flame rendering with Flutter UI via callbacks passed from `GameHomePage`
- Supports card drag-and-drop via `handleDragStart/Move/End`
- Loads atlas.webp and individual card PNGs from assets

### Models (`lib/game/models/`)
| File | Purpose |
|------|---------|
| `card.dart` | 24 unique characters, 8 sentences × 4 copies = 96 deck |
| `player.dart` | hand, discards, melds, score, isTing, tingCards |
| `meld.dart` | kan/ju/zhao meld types |
| `game_state.dart` | deck, players, currentPlayerIndex, dealerIndex, roundHistory |

### Rendering Pipeline
```
AtlasLoader (loads atlas.webp)
  → CardRender (draws cards from atlas by character)
  → GameBoard (positions hands, discards, melds on table)
  → AnimationSystem (flyCard, drawCardAnim for deal/draw/discard)
  → GameTicker (drives animation timers via TimerComponent)
```

### Card System
- **24 characters**: 上大人丘乙己化三千七十土尔小生八九子佳作亡福禄寿
- **8 sentences** (1-8): three-character combinations, 4 copies each = 96 total
- **Color classification**:
  - Red: 上大人
  - Green: 化三千七十
  - Black: all others
- **Jing cards**: 上 or 福

### Critical Files for Reference
| Path | Purpose |
|------|---------|
| `lib/game/shangdaren_game.dart` | FlameGame, callback wiring, animation dispatch |
| `lib/game/logic/game_controller.dart` | State machine, AI turn dispatch, response handling |
| `lib/game/render/card_render.dart` | Card drawing, selection highlight, last-discard blink |
| `lib/game/render/game_board.dart` | Layout for all player hands/discards/melds |
| `lib/game/render/animation_system.dart` | Flying card animations |
| `lib/game/core/atlas_loader.dart` | Sprite sheet parsing for atlas.webp |
| `lib/game/logic/hu_calculator.dart` | Hu pattern extraction (extractJu, extractZhao, extractKan, extractDuiAndKao) |
| `lib/game/logic/ting_checker.dart` | Ting (ready hand) detection |

### Visual Consistency Note
A detailed `docs/visual_diff_report.md` documents differences between the original WebView implementation and the current Flame implementation. Key gaps include:
- Card background gradients (red/green/black)
- Hand card stack overlap (24px current vs ~130px target)
- Selected card scale(1.1) + gold shadow
- Last-discard pulse animation
- Deal animation rotation stages

### Image Assets (`assets/images/`)
- `s/*.png` - small variant (hand cards)
- `v/*.png` - vertical variant
- `s/*C.png` - cardback
- `s/*F.png` - face card
- `atlas.webp` - sprite sheet for Flame rendering (loaded via `Flame.images.load`)

### Audio (`assets/audio/`)
- `female/` and `male/` subdirectories
- Initialized on first user interaction

### Game Flow
```
startGame()
  → startRound() (8 rounds max)
      → _dealCardsAnimated() [deals 20 to dealer, 19 to others]
      → _startTurn()
          → AI: _processAITurn() → selectDiscard() → _doDiscard()
          → Human: _drawCardForHuman() → wait for discardCard(index)
      → _checkResponses() [hu > zhao > peng > chi priority]
      → respondHu/Zhao/Peng/Chi/Pass
      → _nextTurn() or _handleHu() / _handleLiuju()
  → onShowSettlement() after round 8
```