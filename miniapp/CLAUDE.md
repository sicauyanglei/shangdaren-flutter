# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**上大人字牌游戏** - A 3-player Mahjong-style Chinese character card game mini-program built with Taro (React) + TypeScript, targeting WeChat Mini-Program. State managed via Zustand.

## Build Commands

```bash
cd miniapp
npm install                     # Install dependencies
npm run dev:weapp              # Dev build for WeChat Mini-Program (watch mode)
npm run build:weapp            # Production build for WeChat Mini-Program
npm run build:h5               # Build for H5 (browser)
```

## Architecture

### Tech Stack
- **Framework**: Taro 4.x (React) + TypeScript
- **State**: Zustand (`useGameStore` in `src/store/gameStore.ts`)
- **Routing**: Taro router (via `pages/` directory convention)
- **Styling**: Sass modules (`.module.scss`)

### Entry Point
- `src/app.tsx` - Root React component
- `src/app.config.ts` - Mini-program pages, tabBar, window config

### Page Structure
| Page | Path | Purpose |
|------|------|---------|
| 大厅 (Home) | `src/pages/home/index.tsx` | Entry, start game with settings |
| 游戏 (Game) | `src/pages/game/index.tsx` | Core gameplay board |
| 设置 (Settings) | `src/pages/settings/index.tsx` | Volume, difficulty |
| 战绩 (Records) | `src/pages/records/index.tsx` | Game history |
| 我的 (Mine) | `src/pages/mine/index.tsx` | Player profile |

### State Management (`src/store/gameStore.ts`)
- `useGameStore` - Zustand store with game state and actions
- Phases: `idle` → `piao` (optional) → `playing` → `settlement`
- 3 players: index 0=human, 1=AI left, 2=AI right
- Dealer rotates on dianpao, 8 rounds max
- AI logic: `aiDecideDiscard`, `aiDecideChi`, `aiDecidePeng`, `aiDecideZhao` from `src/utils/aiStrategy.ts`

### Core Types (`src/types/`)
| File | Purpose |
|------|---------|
| `card.ts` | 24 unique characters, 8 sentences × 4 copies = 96 deck |
| `player.ts` | Player, Meld, HuResult, GameState, PendingAction types |
| `game.ts` | Game config params |
| `settlement.ts` | Settlement results |

### Utils
- `src/utils/huCalculator.ts` - `calculateTotalHu`, `canHu`, `canZimo`
- `src/utils/tingChecker.ts` - `isTing` ready-hand detection
- `src/utils/scoreCalculator.ts` - `calculateScoreChanges`, `getHuMultiplier`
- `src/utils/aiStrategy.ts` - AI decision-making

### Components
- `CardTile` - Renders individual card (lg/md/sm sizes)
- `ActionButtons` - Chi/Peng/Zhao/Hu/Zimo/Pass buttons
- `RoundInfo` - Round number and dealer display
- `HuPanel` - Hu result overlay with score changes

### Card System
- **24 characters**: 上大人丘乙己化三千七十土尔小生八九子佳作亡福禄寿
- **8 sentences** (1-8): three-character combinations, 4 copies each = 96 total
- **Color classification**: Red (上大人), Green (化三千七十), Black (others)
- **Jing cards**: 上 or 福

### Game Flow
```
startGame() → piao phase (optional) → 8 rounds
  each round:
    dealCards() → playing phase
      drawCard() → discardCard() loop
      check responses (chi/peng/zhao/hu) after each discard
    round end → settlement after round 8
```

### Taro Build Output
- Build output goes to `dist/` directory (per `project.config.json` `miniprogramRoot`)
- `dist/app.json` must exist for IDE to recognize the mini-program

### Key Differences from Flutter App
- This is a Taro/React mini-program, NOT the Flutter Flame game
- The Flutter app (`../flutter_app/`) is a separate game implementation
- This miniapp uses simplified game logic in `gameStore.ts` vs the Flutter's `GameController`