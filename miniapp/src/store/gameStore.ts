import { create } from 'zustand';
import { Card, createDeck, shuffleDeck } from '../types/card';
import { GameState, Player, Meld, HuResult, GamePhase, PendingAction } from '../types/player';
import { calculateTotalHu, canHu, canZimo } from '../utils/huCalculator';
import { isTing } from '../utils/tingChecker';
import { calculateScoreChanges, HuTypeResult } from '../utils/scoreCalculator';
import { aiDecideDiscard, aiDecideChi, aiDecidePeng, aiDecideZhao } from '../utils/aiStrategy';

interface GameStore extends GameState {
  // 游戏控制
  startGame: (baseScore: number, multiplierBase: number, difficulty: string, piaoEnabled: boolean) => void;
  setPiao: (value: number) => void;
  discardCard: (cardId: number) => void;
  doAction: (action: PendingAction) => void;
  passAction: () => void;
  nextRound: () => void;
  closeHuResult: () => void;
  closeLiujuResult: () => void;
  setVolume: (v: number) => void;
  setDifficulty: (d: string) => void;
  selectZhaoCharacter: (char: string) => void;
}

const initialState: GameState = {
  phase: 'idle',
  players: [],
  deck: [],
  currentPlayerIndex: 0,
  dealerIndex: 0,
  roundNumber: 0,
  lastDiscard: null,
  lastDiscardPlayerId: null,
  pendingActions: [],
  huResult: null,
  showHuResult: false,
  showLiujuResult: false,
  isPiaoPhase: false,
  piaoCurrentPlayerIndex: 0,
  baseScore: 10,
  multiplierBase: 5,
  difficulty: 'hard',
  piaoEnabled: false,
  volume: 80,
  canChi: false,
  canPeng: false,
  canZhao: false,
  canHu: false,
  canZimo: false,
  isZimoOpportunity: false,
  showZhaoSelection: false,
  zhaoCandidates: [],
  countdown: 14,
  newCardId: null,
  isDrawing: false,
  hideTingBadge: false,
  waitingForResponse: false,
  roundResults: [],
};

export const useGameStore = create<GameStore>((set, get) => ({
  ...initialState,

  startGame: (baseScore, multiplierBase, difficulty, piaoEnabled) => {
    const deck = shuffleDeck(createDeck());
    const dealerIndex = Math.floor(Math.random() * 3);

    const players: Player[] = [
      {
        id: 0, name: '我', type: 'human',
        hand: [], melds: [], discards: [],
        isTing: false, isDealer: dealerIndex === 0,
        score: 0, huCount: 0, piao: 0, piaoValue: 0, tingCards: [], meldHuCount: 0,
      },
      {
        id: 1, name: '玩家1', type: 'ai',
        hand: [], melds: [], discards: [],
        isTing: false, isDealer: dealerIndex === 1,
        score: 0, huCount: 0, piao: 0, piaoValue: 0, tingCards: [], meldHuCount: 0,
      },
      {
        id: 2, name: '玩家2', type: 'ai',
        hand: [], melds: [], discards: [],
        isTing: false, isDealer: dealerIndex === 2,
        score: 0, huCount: 0, piao: 0, piaoValue: 0, tingCards: [], meldHuCount: 0,
      },
    ];

    // 发牌：庄家20张，非庄家19张
    let cardIndex = 0;
    for (const player of players) {
      const count = player.isDealer ? 20 : 19;
      player.hand = deck.slice(cardIndex, cardIndex + count);
      cardIndex += count;
    }

    const remainingDeck = deck.slice(cardIndex);

    set({
      phase: piaoEnabled ? 'piao' : 'playing',
      players,
      deck: remainingDeck,
      currentPlayerIndex: dealerIndex,
      dealerIndex,
      roundNumber: 1,
      lastDiscard: null,
      lastDiscardPlayerId: null,
      pendingActions: [],
      huResult: null,
      showHuResult: false,
      showLiujuResult: false,
      isPiaoPhase: piaoEnabled,
      piaoCurrentPlayerIndex: 0,
      baseScore,
      multiplierBase,
      difficulty,
      piaoEnabled,
    });
  },

  setPiao: (value) => {
    const state = get();
    const players = [...state.players];
    const pIdx = state.piaoCurrentPlayerIndex;
    players[pIdx] = { ...players[pIdx], piao: value, piaoValue: value };

    const nextIdx = pIdx + 1;
    if (nextIdx >= 3) {
      set({ players, isPiaoPhase: false, piaoCurrentPlayerIndex: 0, phase: 'playing' });
    } else {
      set({ players, piaoCurrentPlayerIndex: nextIdx });
    }
  },

  discardCard: (cardId) => {
    const state = get();
    const players = state.players.map(p => ({ ...p, hand: [...p.hand], discards: [...p.discards] }));
    const current = players[state.currentPlayerIndex];

    const cardIdx = current.hand.findIndex(c => c.id === cardId);
    if (cardIdx < 0) return;

    const discarded = current.hand.splice(cardIdx, 1)[0];
    current.discards.push(discarded);

    // 检查听牌
    current.isTing = isTing(current.hand, current.melds);

    // 下一玩家
    const nextPlayerIndex = (state.currentPlayerIndex + 1) % 3;

    set({
      players,
      lastDiscard: discarded,
      lastDiscardPlayerId: current.id,
      currentPlayerIndex: nextPlayerIndex,
    });

    // AI自动操作（简化）
    setTimeout(() => {
      const s = get();
      if (s.phase !== 'playing') return;
      const nextPlayer = s.players[nextPlayerIndex];
      if (nextPlayer.type === 'ai') {
        // AI摸牌
        if (s.deck.length > 0) {
          const deck = [...s.deck];
          const drawn = deck.shift()!;
          const aiPlayers = s.players.map(p => ({ ...p, hand: [...p.hand] }));
          aiPlayers[nextPlayerIndex].hand.push(drawn);

          // AI出牌
          const toDiscard = aiDecideDiscard(aiPlayers[nextPlayerIndex], s.difficulty);
          const discardIdx = aiPlayers[nextPlayerIndex].hand.findIndex(c => c.id === toDiscard.id);
          if (discardIdx >= 0) {
            aiPlayers[nextPlayerIndex].hand.splice(discardIdx, 1);
            aiPlayers[nextPlayerIndex].discards.push(toDiscard);
            aiPlayers[nextPlayerIndex].isTing = isTing(aiPlayers[nextPlayerIndex].hand, aiPlayers[nextPlayerIndex].melds);
          }

          set({
            players: aiPlayers,
            deck,
            lastDiscard: toDiscard,
            lastDiscardPlayerId: nextPlayerIndex,
            currentPlayerIndex: (nextPlayerIndex + 1) % 3,
          });
        }
      }
    }, 1000);
  },

  doAction: (action) => {
    // 简化处理
    console.log('[Game] Action:', action);
  },

  passAction: () => {
    set({ pendingActions: [] });
  },

  nextRound: () => {
    const state = get();
    if (state.roundNumber >= 8) {
      set({ phase: 'settlement' });
    } else {
      // 简化：重新开始下一局
      set({ roundNumber: state.roundNumber + 1, showHuResult: false, showLiujuResult: false });
    }
  },

  closeHuResult: () => set({ showHuResult: false }),
  closeLiujuResult: () => set({ showLiujuResult: false }),
  setVolume: (v) => set({ volume: v }),
  setDifficulty: (d) => set({ difficulty: d }),
  selectZhaoCharacter: (char) => {
    console.log('[Game] Select zhao character:', char);
    set({ showZhaoSelection: false, zhaoCandidates: [] });
  },
}));
