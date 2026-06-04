import { create } from 'zustand';
import { Card, CardChar, createDeck, shuffleDeck, sortHand, isJingChar, CARD_GROUPS } from '../types/card';
import { GameState, Player, HuResult, PendingAction, RoundResult } from '../types/player';
import { calculateTotalHu, canHu, canZimo, detectHuType } from '../utils/huCalculator';
import { isTing, getTingCards } from '../utils/tingChecker';
import { calculateScoreChanges } from '../utils/scoreCalculator';
import { aiDecideDiscard, aiDecideChi, aiDecidePeng, aiDecideZhao } from '../utils/aiStrategy';

// ============================================================
// Store接口：状态 + 操作方法
// ============================================================

interface GameStore extends GameState {
  // 游戏控制（公开）
  startGame: (baseScore: number, multiplierBase: number, difficulty: string, piaoEnabled: boolean) => void;
  setPiao: (value: number) => void;
  discardCard: (cardId: number) => void;
  doAction: (action: PendingAction) => void;
  passAction: () => void;
  respondHu: () => void;
  respondZhao: () => void;
  respondPeng: () => void;
  respondChi: () => void;
  respondPass: () => void;
  selectZhaoCharacter: (char: string) => void;
  nextRound: () => void;
  closeHuResult: () => void;
  closeLiujuResult: () => void;
  setVolume: (v: number) => void;
  setDifficulty: (d: string) => void;
  // 内部方法
  _startRound: () => void;
  _processAIPiao: () => void;
  _startTurn: () => void;
  _drawCardForHuman: () => void;
  _drawCardForAI: (playerIdx: number) => void;
  _checkHumanActionsAfterDraw: (skipZimoCheck: boolean) => void;
  _processAITurn: (player: Player, playerIdx: number) => void;
  _aiContinueAfterDraw: (player: Player, playerIdx: number, drawnCard: Card | undefined, skipZimoCheck: boolean) => void;
  _doDiscard: (playerIdx: number, card: Card) => void;
  _checkResponses: (card: Card, discardPlayerId: number) => void;
  _processResponses: (responses: Map<number, string[]>, card: Card, discardPlayerId: number) => void;
  _processAIResponses: (responses: Map<number, string[]>, card: Card, discardPlayerId: number) => void;
  _handleChi: (playerIdx: number, card: Card, discardPlayerId: number) => void;
  _handlePeng: (playerIdx: number, card: Card, discardPlayerId: number) => void;
  _handleZhaoRespond: (playerIdx: number, card: Card, discardPlayerId: number) => void;
  _handleZhaoFromHand: (playerIdx: number, character: string) => void;
  _drawAfterZhao: (playerIdx: number) => void;
  _handleHu: (winnerIdx: number, isZimo: boolean, dianpaoIdx?: number, zimoCard?: Card) => void;
  _handleLiuju: () => void;
  _nextTurn: () => void;
}

// ============================================================
// 初始状态
// ============================================================

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
  isMyTurn: false,
  isHandlingHu: false,
  roundResults: [],
};

// ============================================================
// 辅助函数
// ============================================================

/** 获取玩家总牌数（手牌 + 组合牌×3） */
function getTotalCardCount(player: Player): number {
  return player.hand.length + player.melds.length * 3;
}

/** 创建玩家 */
function createPlayer(id: number, name: string, type: 'human' | 'ai', isDealer: boolean): Player {
  return {
    id, name, type,
    hand: [], melds: [], discards: [],
    isTing: false, isDealer,
    score: 0, huCount: 0, piao: 0, piaoValue: 0, tingCards: [], meldHuCount: 0,
  };
}

/** 深拷贝玩家数组 */
function clonePlayers(players: Player[]): Player[] {
  return players.map(p => ({
    ...p,
    hand: [...p.hand],
    melds: p.melds.map(m => ({ ...m, cards: [...m.cards] })),
    discards: [...p.discards],
    tingCards: [...p.tingCards],
  }));
}

/** 判断玩家是否可以自摸 */
function canPlayerZimo(player: Player): boolean {
  if (player.hand.length === 0) return false;
  return canZimo(player.hand, player.melds);
}

/** 判断玩家是否可以招手牌中的4张同字 */
function canZhaoAfterDraw(player: Player): boolean {
  if (getTotalCardCount(player) < 20) return false;
  return getZhaoCandidates(player).length > 0;
}

/** 获取手牌中4张同字的候选 */
function getZhaoCandidates(player: Player): string[] {
  const byChar = new Map<string, number>();
  for (const card of player.hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }
  return Array.from(byChar.entries()).filter(([, count]) => count === 4).map(([ch]) => ch);
}

/** 判断玩家是否可以胡别人出的牌 */
function canHuWith(player: Player, card: Card): boolean {
  if (getTotalCardCount(player) >= 20) return false;
  const testHand = [...player.hand, card];
  return canHu(testHand, player.melds, player.isTing);
}

/** 判断玩家是否可以碰别人出的牌 */
function canPengWith(player: Player, card: Card): boolean {
  if (getTotalCardCount(player) >= 20) return false;
  const count = player.hand.filter(c => c.char === card.char).length;
  return count >= 2;
}

/** 判断玩家是否可以招别人出的牌 */
function canZhaoWith(player: Player, card: Card): boolean {
  if (getTotalCardCount(player) !== 19) return false;
  const count = player.hand.filter(c => c.char === card.char).length;
  return count >= 3;
}

/** 判断玩家是否可以吃别人出的牌 */
function canChiWith(player: Player, playerIndex: number, card: Card, discardPlayerId: number): boolean {
  if (getTotalCardCount(player) >= 20) return false;
  // 只有下家可以吃
  const isNextPlayer = playerIndex === (discardPlayerId + 1) % 3;
  if (!isNextPlayer) return false;
  return findChiCards(player, card) !== null;
}

/** 找到吃的组合牌 */
function findChiCards(player: Player, card: Card): Card[] | null {
  const sameSentence = player.hand.filter(c => c.sentence === card.sentence);
  if (sameSentence.length < 2) return null;

  const byPos = new Map<number, Card>();
  for (const c of sameSentence) {
    byPos.set(c.position, c);
  }

  // 中间位置：需要左右两张
  const needed1 = card.position - 1;
  const needed2 = card.position + 1;
  if (needed1 >= 0 && needed2 <= 2 && byPos.has(needed1) && byPos.has(needed2)) {
    return [byPos.get(needed1)!, byPos.get(needed2)!];
  }

  // 左边位置：需要更左两张
  const needed3 = card.position - 2;
  const needed4 = card.position - 1;
  if (needed3 >= 0 && needed4 >= 0 && byPos.has(needed3) && byPos.has(needed4)) {
    return [byPos.get(needed3)!, byPos.get(needed4)!];
  }

  // 右边位置：需要更右两张
  const needed5 = card.position + 1;
  const needed6 = card.position + 2;
  if (needed5 <= 2 && needed6 <= 2 && byPos.has(needed5) && byPos.has(needed6)) {
    return [byPos.get(needed5)!, byPos.get(needed6)!];
  }

  return null;
}

/** 检查手牌中是否有包含该字的完整一句且每个字只有一张（人类玩家吃牌特例） */
function hasCompleteSentenceWithSingleCards(player: Player, card: Card): boolean {
  const sentence = card.sentence;
  const groupChars = CARD_GROUPS[sentence - 1];

  const charCount = new Map<string, number>();
  for (const ch of groupChars) {
    charCount.set(ch, 0);
  }
  for (const c of player.hand) {
    if (c.sentence === sentence && charCount.has(c.char)) {
      charCount.set(c.char, charCount.get(c.char)! + 1);
    }
  }

  const allPresent = Array.from(charCount.values()).every(count => count >= 1);
  const allSingle = Array.from(charCount.values()).every(count => count === 1);
  return allPresent && allSingle && groupChars.includes(card.char);
}

/** AI决定是否招手牌中的4张同字 */
function aiShouldZhaoFromHand(_player: Player, _char: string, difficulty: string): boolean {
  // 简单策略：总是招
  if (difficulty === 'easy') return true;
  // 中等和困难：总是招（招牌本身很强）
  return true;
}

/** AI选择出牌 */
function aiSelectDiscard(player: Player, difficulty: string): Card {
  return aiDecideDiscard(player.hand, player.melds, difficulty);
}

/** AI决定是否招别人出的牌 */
function aiShouldZhaoRespond(player: Player, card: Card, difficulty: string): boolean {
  return aiDecideZhao(player, card, difficulty);
}

/** AI决定是否碰别人出的牌 */
function aiShouldPengRespond(player: Player, card: Card, difficulty: string): boolean {
  return aiDecidePeng(player, card, difficulty);
}

/** AI决定是否吃别人出的牌 */
function aiShouldChiRespond(player: Player, card: Card, difficulty: string): boolean {
  return aiDecideChi(player, card, difficulty);
}

/** 更新玩家的听牌状态和胡数 */
function updatePlayerTingAndHu(player: Player): void {
  const tingResult = isTing(player.hand, player.melds);
  player.isTing = tingResult;
  if (tingResult) {
    player.tingCards = getTingCards(player.hand, player.melds).map(ch => {
      const sentence = CARD_GROUPS.findIndex(g => g.includes(ch)) + 1;
      const position = CARD_GROUPS[sentence - 1].indexOf(ch);
      return {
        id: -1,
        char: ch,
        color: 'red' as const,
        sentence,
        position,
      };
    });
  } else {
    player.tingCards = [];
  }
  player.huCount = calculateTotalHu(player.hand, player.melds);
}

// ============================================================
// 模块级变量：暂存AI待处理响应（不属于Zustand状态）
// ============================================================

let _pendingAIResponses: Map<number, string[]> | null = null;
let _pendingResponseCard: Card | null = null;
let _pendingResponseDiscardPlayerId: number | null = null;
let _skipDraw = false;
let _hasDealerPlayedFirstTurn = false;

function clearPendingAIResponses(): void {
  _pendingAIResponses = null;
  _pendingResponseCard = null;
  _pendingResponseDiscardPlayerId = null;
}

// ============================================================
// Zustand Store
// ============================================================

export const useGameStore = create<GameStore>((set, get) => ({
  ...initialState,

  // ============================================================
  // 1. 开始游戏
  // ============================================================
  startGame: (baseScore, multiplierBase, difficulty, piaoEnabled) => {
    const deck = shuffleDeck(createDeck());
    const dealerIndex = Math.floor(Math.random() * 3);

    const players: Player[] = [
      createPlayer(0, '我', 'human', dealerIndex === 0),
      createPlayer(1, '玩家1', 'ai', dealerIndex === 1),
      createPlayer(2, '玩家2', 'ai', dealerIndex === 2),
    ];

    set({
      phase: 'idle',
      players,
      deck,
      currentPlayerIndex: dealerIndex,
      dealerIndex,
      roundNumber: 0,
      lastDiscard: null,
      lastDiscardPlayerId: null,
      pendingActions: [],
      huResult: null,
      showHuResult: false,
      showLiujuResult: false,
      isPiaoPhase: false,
      piaoCurrentPlayerIndex: 0,
      baseScore,
      multiplierBase,
      difficulty,
      piaoEnabled,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      showZhaoSelection: false,
      zhaoCandidates: [],
      isDrawing: false,
      hideTingBadge: false,
      waitingForResponse: false,
      roundResults: [],
    });

    // 进入第一局
    get()._startRound();
  },

  // ============================================================
  // 2. 开始一局
  // ============================================================
  _startRound: () => {
    const state = get();
    const roundNumber = state.roundNumber + 1;

    if (roundNumber > 8) {
      set({ phase: 'settlement' });
      return;
    }

    // 重置状态
    _skipDraw = false;
    _hasDealerPlayedFirstTurn = false;
    const players = clonePlayers(state.players);
    for (const player of players) {
      player.hand = [];
      player.melds = [];
      player.discards = [];
      player.isTing = false;
      player.tingCards = [];
      player.huCount = 0;
      player.meldHuCount = 0;
      // piao不重置，保留飘分设置（下一局重新设置）
      player.piao = 0;
      player.piaoValue = 0;
    }

    // 洗牌发牌
    const deck = shuffleDeck(createDeck());
    let cardIndex = 0;
    for (const player of players) {
      const count = player.isDealer ? 20 : 19;
      player.hand = deck.slice(cardIndex, cardIndex + count);
      cardIndex += count;
    }
    const remainingDeck = deck.slice(cardIndex);

    // 排序手牌
    for (const player of players) {
      player.hand = sortHand(player.hand);
      updatePlayerTingAndHu(player);
    }

    set({
      phase: 'idle',
      players,
      deck: remainingDeck,
      currentPlayerIndex: state.dealerIndex,
      roundNumber,
      lastDiscard: null,
      lastDiscardPlayerId: null,
      pendingActions: [],
      huResult: null,
      showHuResult: false,
      showLiujuResult: false,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      showZhaoSelection: false,
      zhaoCandidates: [],
      isDrawing: false,
      hideTingBadge: false,
      waitingForResponse: false,
    });

    // 进入飘分阶段或直接开始
    if (state.piaoEnabled) {
      set({ isPiaoPhase: true, piaoCurrentPlayerIndex: state.dealerIndex });
      get()._processAIPiao();
    } else {
      for (const player of players) {
        player.piao = 0;
        player.piaoValue = 0;
      }
      set({ players, isPiaoPhase: false, phase: 'playing' });
      get()._startTurn();
    }
  },

  // ============================================================
  // 3. 飘分阶段
  // ============================================================
  _processAIPiao: () => {
    const state = get();
    let piaoCurrentPlayerIndex = state.piaoCurrentPlayerIndex;
    const players = clonePlayers(state.players);
    let piaoSetCount = players.filter(p => p.piao > 0 || p.type === 'ai').length;

    // 处理AI飘分
    while (true) {
      const player = players[piaoCurrentPlayerIndex];
      if (player.type === 'ai') {
        // AI根据难度选择飘分
        let piaoOptions: number[];
        if (state.difficulty === 'easy') {
          piaoOptions = [0];
        } else if (state.difficulty === 'medium') {
          piaoOptions = [0, 5, 10];
        } else {
          piaoOptions = [5, 10, 20];
        }
        const piaoValue = piaoOptions[Math.floor(Math.random() * piaoOptions.length)];
        player.piao = piaoValue;
        player.piaoValue = piaoValue;
        piaoCurrentPlayerIndex = (piaoCurrentPlayerIndex + 1) % 3;
        piaoSetCount++;

        if (piaoSetCount >= 3) {
          set({
            players,
            isPiaoPhase: false,
            piaoCurrentPlayerIndex: 0,
            phase: 'playing',
          });
          get()._startTurn();
          return;
        }
      } else {
        // 人类玩家，等待UI输入
        break;
      }
    }

    set({ players, piaoCurrentPlayerIndex });
  },

  setPiao: (value) => {
    const state = get();
    const players = clonePlayers(state.players);
    const pIdx = state.piaoCurrentPlayerIndex;
    players[pIdx] = { ...players[pIdx], piao: value, piaoValue: value };

    const nextIdx = (pIdx + 1) % 3;
    const piaoSetCount = players.filter(p => p.piao > 0).length;

    if (piaoSetCount >= 3) {
      set({ players, isPiaoPhase: false, piaoCurrentPlayerIndex: 0, phase: 'playing' });
      get()._startTurn();
    } else {
      set({ players, piaoCurrentPlayerIndex: nextIdx });
      get()._processAIPiao();
    }
  },

  // ============================================================
  // 4. 回合开始
  // ============================================================
  _startTurn: () => {
    const state = get();
    if (state.phase !== 'playing') return;

    // 匹配 Flame: 流局检查（_skipDraw时不检查牌堆空）
    if (state.deck.length === 0 && !_skipDraw) {
      get()._handleLiuju();
      return;
    }

    const currentIdx = state.currentPlayerIndex;
    const player = state.players[currentIdx];

    if (player.type === 'ai') {
      get()._processAITurn(player, currentIdx);
    } else {
      // 人类玩家
      // 匹配 Flame: _skipDraw时跳过摸牌，直接出牌
      if (_skipDraw) {
        _skipDraw = false;
        get()._checkHumanActionsAfterDraw(true);
      } else if (!_hasDealerPlayedFirstTurn && currentIdx === state.dealerIndex) {
        // 匹配 Flame: 庄家第一回合不摸牌，直接出牌
        _hasDealerPlayedFirstTurn = true;
        get()._checkHumanActionsAfterDraw(true);
      } else {
        const totalCards = getTotalCardCount(player);
        if (totalCards >= 20) {
          // 20张牌，不能摸牌，必须出牌
          get()._checkHumanActionsAfterDraw(true);
        } else {
          get()._drawCardForHuman();
        }
      }
    }
  },

  // ============================================================
  // 5. 摸牌
  // ============================================================
  _drawCardForHuman: () => {
    const state = get();
    if (state.deck.length === 0) {
      get()._handleLiuju();
      return;
    }

    const deck = [...state.deck];
    const drawn = deck.shift()!;
    const players = clonePlayers(state.players);
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    const humanPlayer = players[humanIdx];

    humanPlayer.hand.push(drawn);
    humanPlayer.hand = sortHand(humanPlayer.hand);
    updatePlayerTingAndHu(humanPlayer);

    set({
      players,
      deck,
      isDrawing: false,
      newCardId: drawn.id,
      currentPlayerIndex: humanIdx,
    });

    get()._checkHumanActionsAfterDraw(false);
  },

  _drawCardForAI: (playerIdx: number) => {
    const state = get();
    if (state.deck.length === 0) {
      get()._handleLiuju();
      return;
    }

    const deck = [...state.deck];
    const drawn = deck.shift()!;
    const players = clonePlayers(state.players);
    const player = players[playerIdx];

    player.hand.push(drawn);
    player.hand = sortHand(player.hand);
    updatePlayerTingAndHu(player);

    set({ players, deck });

    get()._aiContinueAfterDraw(player, playerIdx, drawn, false);
  },

  // ============================================================
  // 6. 检查人类玩家操作
  // ============================================================
  _checkHumanActionsAfterDraw: (skipZimoCheck: boolean) => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    const player = state.players[humanIdx];

    const canZimoFlag = !skipZimoCheck && canPlayerZimo(player);
    const canZhaoFlag = canZhaoAfterDraw(player);

    set({
      canHu: canZimoFlag,
      canZimo: canZimoFlag,
      isZimoOpportunity: canZimoFlag,
      canZhao: canZhaoFlag,
      canPeng: false,
      canChi: false,
      isDrawing: false,
      hideTingBadge: canZimoFlag,
      isMyTurn: true, // 匹配 Flame: _completeDrawForHuman 中设置 isMyTurn = true
    });
  },

  // ============================================================
  // 7. AI回合处理
  // ============================================================
  _processAITurn: (player: Player, playerIdx: number) => {
    const state = get();
    if (state.deck.length === 0 && !_skipDraw) {
      get()._handleLiuju();
      return;
    }

    // 匹配 Flame: _skipDraw时跳过摸牌
    if (_skipDraw) {
      _skipDraw = false;
      get()._aiContinueAfterDraw(player, playerIdx, undefined, true);
      return;
    }

    // 匹配 Flame: 庄家第一回合不摸牌，直接出牌
    if (!_hasDealerPlayedFirstTurn && playerIdx === state.dealerIndex) {
      _hasDealerPlayedFirstTurn = true;
      get()._aiContinueAfterDraw(player, playerIdx, undefined, true);
      return;
    }

    const totalCards = getTotalCardCount(player);
    if (totalCards >= 20) {
      // 20张牌，不能摸牌，直接出牌
      get()._aiContinueAfterDraw(player, playerIdx, undefined, true);
    } else {
      get()._drawCardForAI(playerIdx);
    }
  },

  _aiContinueAfterDraw: (_player: Player, playerIdx: number, drawnCard: Card | undefined, skipZimoCheck: boolean) => {
    const state = get();
    const players = clonePlayers(state.players);
    const aiPlayer = players[playerIdx];

    if (aiPlayer.hand.length === 0) {
      get()._nextTurn();
      return;
    }

    // 检查自摸
    if (!skipZimoCheck && canPlayerZimo(aiPlayer)) {
      get()._handleHu(playerIdx, true, undefined, drawnCard);
      return;
    }

    // 检查招手牌中的4张同字
    if (!skipZimoCheck && canZhaoAfterDraw(aiPlayer)) {
      const candidates = getZhaoCandidates(aiPlayer);
      let shouldZhao = true;
      for (const ch of candidates) {
        if (!aiShouldZhaoFromHand(aiPlayer, ch, state.difficulty)) {
          shouldZhao = false;
          break;
        }
      }
      if (shouldZhao) {
        get()._handleZhaoFromHand(playerIdx, candidates[0]);
        return;
      }
    }

    // AI出牌
    const toDiscard = aiSelectDiscard(aiPlayer, state.difficulty);
    get()._doDiscard(playerIdx, toDiscard);
  },

  // ============================================================
  // 8. 出牌
  // ============================================================
  discardCard: (cardId: number) => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    const player = state.players[humanIdx];

    if (state.canChi || state.canPeng || state.canZhao || state.canHu) return;
    if (state.isDrawing) return;

    const cardIdx = player.hand.findIndex(c => c.id === cardId);
    if (cardIdx < 0) return;

    const card = player.hand[cardIdx];
    get()._doDiscard(humanIdx, card);
  },

  _doDiscard: (playerIdx: number, card: Card) => {
    const state = get();
    _skipDraw = false;
    const players = clonePlayers(state.players);
    const player = players[playerIdx];

    const cardIdx = player.hand.findIndex(c => c.id === card.id);
    if (cardIdx < 0) {
      // 卡牌不在手中，出最后一张
      if (player.hand.length > 0) {
        const lastCard = player.hand[player.hand.length - 1];
        player.hand.pop();
        player.discards.push(lastCard);
        updatePlayerTingAndHu(player);

        set({
          players,
          lastDiscard: lastCard,
          lastDiscardPlayerId: playerIdx,
          canChi: false,
          canPeng: false,
          canZhao: false,
          canHu: false,
          canZimo: false,
          isZimoOpportunity: false,
          isDrawing: false,
          isMyTurn: false, // 匹配 Flame: 出牌后 isMyTurn = false
        });

        get()._checkResponses(lastCard, playerIdx);
      }
      return;
    }

    player.hand.splice(cardIdx, 1);
    player.discards.push(card);
    updatePlayerTingAndHu(player);

    const humanIdx = state.players.findIndex(p => p.type === 'human');
    if (playerIdx === humanIdx) {
      set({ hideTingBadge: !player.isTing });
    }

    set({
      players,
      lastDiscard: card,
      lastDiscardPlayerId: playerIdx,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      isDrawing: false,
      newCardId: null,
      isMyTurn: false, // 匹配 Flame: 出牌后 isMyTurn = false
    });

    get()._checkResponses(card, playerIdx);
  },

  // ============================================================
  // 9. 响应检查（操作优先级：胡 > 招 > 碰 > 吃）
  // ============================================================
  _checkResponses: (card: Card, discardPlayerId: number) => {
    const state = get();
    const responses = new Map<number, string[]>();

    for (let i = 0; i < state.players.length; i++) {
      if (i === discardPlayerId) continue;
      const p = state.players[i];
      const actions: string[] = [];

      // 检查胡
      if (canHuWith(p, card) && p.isTing) {
        actions.push('hu');
      }

      if (p.type === 'ai') {
        // AI使用策略判断
        if (canZhaoWith(p, card) && aiShouldZhaoRespond(p, card, state.difficulty)) {
          actions.push('zhao');
        }
        if (canPengWith(p, card) && aiShouldPengRespond(p, card, state.difficulty)) {
          actions.push('peng');
        }
        if (canChiWith(p, i, card, discardPlayerId) && aiShouldChiRespond(p, card, state.difficulty)) {
          actions.push('chi');
        }
      } else {
        // 人类玩家
        if (canZhaoWith(p, card)) {
          actions.push('zhao');
        }
        if (canPengWith(p, card)) {
          actions.push('peng');
        }
        if (canChiWith(p, i, card, discardPlayerId)) {
          // 人类玩家吃牌特例：完整一句且每个字只有一张，不显示吃按钮
          if (!hasCompleteSentenceWithSingleCards(p, card)) {
            actions.push('chi');
          }
        }
      }

      responses.set(i, actions);
    }

    get()._processResponses(responses, card, discardPlayerId);
  },

  _processResponses: (
    responses: Map<number, string[]>,
    card: Card,
    discardPlayerId: number,
  ) => {
    const state = get();
    const priorityOrder = ['hu', 'zhao', 'peng', 'chi'];

    const humanResponses: string[] = [];
    const deferredAI = new Map<number, string[]>();

    for (const action of priorityOrder) {
      const respondents: number[] = [];
      for (const [playerIdx, actions] of Array.from(responses)) {
        if (actions.includes(action)) {
          respondents.push(playerIdx);
        }
      }

      if (respondents.length === 0) continue;

      const humanRespondent = respondents.filter(i => state.players[i].type === 'human');

      if (action === 'hu') {
        if (humanRespondent.length > 0) {
          humanResponses.push('hu');
          for (const r of respondents) {
            if (state.players[r].type === 'ai') {
              deferredAI.set(r, [...(deferredAI.get(r) || []), 'hu']);
            }
          }
          continue;
        }
        // AI直接胡
        get()._handleHu(respondents[0], false, discardPlayerId, undefined);
        return;
      }

      if (action === 'zhao') {
        if (humanRespondent.length > 0) {
          humanResponses.push('zhao');
          for (const r of respondents) {
            if (state.players[r].type === 'ai') {
              deferredAI.set(r, [...(deferredAI.get(r) || []), 'zhao']);
            }
          }
          continue;
        }
        if (humanResponses.length > 0) {
          // 人类有更高优先级操作，AI等待
          for (const r of respondents) {
            if (state.players[r].type === 'ai') {
              deferredAI.set(r, [...(deferredAI.get(r) || []), 'zhao']);
            }
          }
          continue;
        }
        get()._handleZhaoRespond(respondents[0], card, discardPlayerId);
        return;
      }

      if (action === 'peng') {
        if (humanRespondent.length > 0) {
          humanResponses.push('peng');
          for (const r of respondents) {
            if (state.players[r].type === 'ai') {
              deferredAI.set(r, [...(deferredAI.get(r) || []), 'peng']);
            }
          }
          continue;
        }
        if (humanResponses.length > 0) {
          for (const r of respondents) {
            if (state.players[r].type === 'ai') {
              deferredAI.set(r, [...(deferredAI.get(r) || []), 'peng']);
            }
          }
          continue;
        }
        get()._handlePeng(respondents[0], card, discardPlayerId);
        return;
      }

      if (action === 'chi') {
        const nextPlayerIndex = (discardPlayerId + 1) % 3;
        if (respondents.includes(nextPlayerIndex)) {
          const p = state.players[nextPlayerIndex];
          if (p.type === 'human') {
            humanResponses.push('chi');
            continue;
          }
          if (humanResponses.length > 0) {
            deferredAI.set(nextPlayerIndex, [...(deferredAI.get(nextPlayerIndex) || []), 'chi']);
            continue;
          }
          get()._handleChi(nextPlayerIndex, card, discardPlayerId);
          return;
        }
      }
    }

    // 没有人类响应，下一回合
    if (humanResponses.length === 0) {
      get()._nextTurn();
      return;
    }

    // 显示人类操作按钮（匹配 Flame: 设置 isMyTurn = true）
    const updates: Partial<GameState> = {
      waitingForResponse: true,
      isMyTurn: true,
    };

    for (const action of humanResponses) {
      if (action === 'hu') {
        updates.canHu = true;
        updates.isZimoOpportunity = false;
      }
      if (action === 'zhao') updates.canZhao = true;
      if (action === 'peng') updates.canPeng = true;
      if (action === 'chi') updates.canChi = true;
    }

    // 保存待处理的AI响应
    _pendingAIResponses = deferredAI.size > 0 ? deferredAI : null;
    _pendingResponseCard = card;
    _pendingResponseDiscardPlayerId = discardPlayerId;

    set(updates);
  },

  // ============================================================
  // 10. 人类响应操作
  // ============================================================
  respondHu: () => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    const isZimo = !state.waitingForResponse;

    set({
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
    });

    // 匹配 Flame: respondHu 中清除待处理AI响应
    clearPendingAIResponses();

    get()._handleHu(
      humanIdx,
      isZimo,
      isZimo ? undefined : state.lastDiscardPlayerId ?? undefined,
      isZimo ? state.players[humanIdx].hand[state.players[humanIdx].hand.length - 1] : undefined,
    );
  },

  respondZhao: () => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');

    set({
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
    });

    if (state.waitingForResponse) {
      set({ waitingForResponse: false, hideTingBadge: true });
      // 匹配 Flame: respondZhao 中清除待处理AI响应
      clearPendingAIResponses();
      if (state.lastDiscard && state.lastDiscardPlayerId !== null) {
        get()._handleZhaoRespond(humanIdx, state.lastDiscard, state.lastDiscardPlayerId);
      }
    } else {
      // 招手牌中的4张同字
      const player = state.players[humanIdx];
      const candidates = getZhaoCandidates(player);
      if (candidates.length === 0) {
        // 匹配 Flame: 没有可招的牌，设置isMyTurn并启动countdown
        set({ canZhao: false, isMyTurn: true });
        return;
      }
      if (candidates.length === 1) {
        get()._handleZhaoFromHand(humanIdx, candidates[0]);
      } else {
        set({ showZhaoSelection: true, zhaoCandidates: candidates });
      }
    }
  },

  respondPeng: () => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');

    set({
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
      hideTingBadge: true,
    });

    // 匹配 Flame: respondPeng 中清除待处理AI响应
    clearPendingAIResponses();

    if (state.lastDiscard && state.lastDiscardPlayerId !== null) {
      get()._handlePeng(humanIdx, state.lastDiscard, state.lastDiscardPlayerId);
    }
  },

  respondChi: () => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');

    set({
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
      hideTingBadge: true,
    });

    // 匹配 Flame: respondChi 中清除待处理AI响应
    clearPendingAIResponses();

    if (state.lastDiscard && state.lastDiscardPlayerId !== null) {
      get()._handleChi(humanIdx, state.lastDiscard, state.lastDiscardPlayerId);
    }
  },

  respondPass: () => {
    const state = get();
    const wasWaitingForResponse = state.waitingForResponse;

    set({
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
    });

    if (wasWaitingForResponse) {
      // 人类过牌后，处理AI待处理操作
      if (_pendingAIResponses && _pendingResponseCard && _pendingResponseDiscardPlayerId !== null) {
        get()._processAIResponses(_pendingAIResponses, _pendingResponseCard, _pendingResponseDiscardPlayerId);
        clearPendingAIResponses();
      } else {
        clearPendingAIResponses();
        get()._nextTurn();
      }
    } else {
      // 匹配 Flame: 过招按钮后，需要出牌，设置isMyTurn并启动countdown
      set({ isMyTurn: true });
    }
  },

  passAction: () => {
    get().respondPass();
  },

  // ============================================================
  // 11. 处理AI待处理响应
  // ============================================================
  _processAIResponses: (
    responses: Map<number, string[]>,
    card: Card,
    discardPlayerId: number,
  ) => {
    const priorityOrder = ['hu', 'zhao', 'peng', 'chi'];

    for (const action of priorityOrder) {
      const respondents: number[] = [];
      for (const [playerIdx, actions] of Array.from(responses)) {
        if (actions.includes(action)) {
          respondents.push(playerIdx);
        }
      }

      if (respondents.length === 0) continue;

      if (action === 'hu') {
        get()._handleHu(respondents[0], false, discardPlayerId, undefined);
        return;
      }
      if (action === 'zhao') {
        get()._handleZhaoRespond(respondents[0], card, discardPlayerId);
        return;
      }
      if (action === 'peng') {
        get()._handlePeng(respondents[0], card, discardPlayerId);
        return;
      }
      if (action === 'chi') {
        const nextPlayerIndex = (discardPlayerId + 1) % 3;
        if (respondents.includes(nextPlayerIndex)) {
          get()._handleChi(nextPlayerIndex, card, discardPlayerId);
          return;
        }
      }
    }

    get()._nextTurn();
  },

  // ============================================================
  // 12. 执行操作
  // ============================================================

  // --- 吃 ---
  _handleChi: (playerIdx: number, card: Card, discardPlayerId: number) => {
    const state = get();
    const players = clonePlayers(state.players);
    const player = players[playerIdx];
    const discarder = players[discardPlayerId];

    const chiCards = findChiCards(player, card);
    if (!chiCards) {
      get()._nextTurn();
      return;
    }

    const meldCards = [card, chiCards[0], chiCards[1]];

    // 从弃牌区移除
    const discardIdx = discarder.discards.findIndex(c => c.id === card.id);
    if (discardIdx >= 0) {
      discarder.discards.splice(discardIdx, 1);
    }

    // 从手牌移除吃的牌
    const idx0 = player.hand.findIndex(c => c.id === chiCards[0].id);
    if (idx0 >= 0) player.hand.splice(idx0, 1);
    const idx1 = player.hand.findIndex(c => c.id === chiCards[1].id);
    if (idx1 >= 0) player.hand.splice(idx1, 1);

    // 添加组合牌
    const hasJing = meldCards.some(c => isJingChar(c.char));
    player.melds.push({
      type: 'ju',
      cards: meldCards,
      isJing: hasJing,
    });

    updatePlayerTingAndHu(player);

    // 匹配 Flame: 吃后设置 _skipDraw = true
    _skipDraw = true;

    set({
      players,
      currentPlayerIndex: playerIdx,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
    });

    // 匹配 Flame: 人类玩家吃后设置isMyTurn并启动countdown
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    if (playerIdx === humanIdx) {
      set({ isMyTurn: true, isDrawing: false });
      get()._checkHumanActionsAfterDraw(true);
    } else {
      // AI出牌
      get()._aiContinueAfterDraw(player, playerIdx, undefined, true);
    }
  },

  // --- 碰 ---
  _handlePeng: (playerIdx: number, card: Card, discardPlayerId: number) => {
    const state = get();
    const players = clonePlayers(state.players);
    const player = players[playerIdx];
    const discarder = players[discardPlayerId];

    const matching = player.hand.filter(c => c.char === card.char);
    if (matching.length < 2) {
      get()._nextTurn();
      return;
    }

    const pengCards = [card, matching[0], matching[1]];

    // 从弃牌区移除
    const discardIdx = discarder.discards.findIndex(c => c.id === card.id);
    if (discardIdx >= 0) {
      discarder.discards.splice(discardIdx, 1);
    }

    // 从手牌移除碰的牌
    const idx0 = player.hand.findIndex(c => c.id === matching[0].id);
    if (idx0 >= 0) player.hand.splice(idx0, 1);
    const idx1 = player.hand.findIndex(c => c.id === matching[1].id);
    if (idx1 >= 0) player.hand.splice(idx1, 1);

    // 添加组合牌
    player.melds.push({
      type: 'kan',
      cards: pengCards,
      isJing: isJingChar(card.char),
    });

    updatePlayerTingAndHu(player);

    // 匹配 Flame: 碰后设置 _skipDraw = true
    _skipDraw = true;

    set({
      players,
      currentPlayerIndex: playerIdx,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
    });

    // 匹配 Flame: 人类玩家碰后设置isMyTurn并启动countdown
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    if (playerIdx === humanIdx) {
      set({ isMyTurn: true, isDrawing: false });
      get()._checkHumanActionsAfterDraw(true);
    } else {
      get()._aiContinueAfterDraw(player, playerIdx, undefined, true);
    }
  },

  // --- 招（响应别人出的牌） ---
  _handleZhaoRespond: (playerIdx: number, card: Card, discardPlayerId: number) => {
    const state = get();
    const players = clonePlayers(state.players);
    const player = players[playerIdx];
    const discarder = players[discardPlayerId];

    // 检查是否有现有坎可以升级为招
    const existingKan = player.melds.filter(
      m => m.type === 'kan' && m.cards[0].char === card.char
    );

    if (existingKan.length > 0) {
      // 坎升级为招（匹配 Flame L1468-1478）
      const oldMeld = existingKan[0];
      player.melds = player.melds.filter(m => m !== oldMeld);

      // 从弃牌区移除
      const discardIdx = discarder.discards.findIndex(c => c.id === card.id);
      if (discardIdx >= 0) {
        discarder.discards.splice(discardIdx, 1);
      }

      const newCards = [...oldMeld.cards, card];
      player.melds.push({
        type: 'zhao',
        cards: newCards,
        isJing: isJingChar(card.char),
      });
    } else {
      // 手牌中有3张同字
      const handMatching = player.hand.filter(c => c.char === card.char);
      if (handMatching.length < 3) {
        get()._nextTurn();
        return;
      }
      const zhaoCards = [card, handMatching[0], handMatching[1], handMatching[2]];

      // 从弃牌区移除
      const discardIdx = discarder.discards.findIndex(c => c.id === card.id);
      if (discardIdx >= 0) {
        discarder.discards.splice(discardIdx, 1);
      }

      // 从手牌移除
      for (let i = 0; i < 3; i++) {
        const idx = player.hand.findIndex(c => c.id === handMatching[i].id);
        if (idx >= 0) player.hand.splice(idx, 1);
      }

      player.melds.push({
        type: 'zhao',
        cards: zhaoCards,
        isJing: isJingChar(card.char),
      });
    }

    updatePlayerTingAndHu(player);

    set({
      players,
      currentPlayerIndex: playerIdx,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
    });

    // 招后补摸一张牌
    get()._drawAfterZhao(playerIdx);
  },

  // --- 招（手牌中的4张同字） ---
  _handleZhaoFromHand: (playerIdx: number, character: string) => {
    const state = get();
    const players = clonePlayers(state.players);
    const player = players[playerIdx];

    const byChar = new Map<string, Card[]>();
    for (const c of player.hand) {
      const list = byChar.get(c.char) || [];
      list.push(c);
      byChar.set(c.char, list);
    }

    let targetChar = character;
    if (!targetChar) {
      for (const [ch, cards] of Array.from(byChar)) {
        if (cards.length === 4) {
          targetChar = ch;
          break;
        }
      }
    }

    if (!targetChar) {
      // 匹配 Flame: 没有可招的牌，清除状态
      set({
        canZhao: false,
        showZhaoSelection: false,
        zhaoCandidates: [],
        canChi: false,
        canPeng: false,
        canHu: false,
        isDrawing: false,
      });
      const humanIdx = state.players.findIndex(p => p.type === 'human');
      if (playerIdx === humanIdx) {
        // 匹配 Flame: 设置isMyTurn并启动countdown
        set({ isMyTurn: true });
        get()._checkHumanActionsAfterDraw(true);
      } else {
        const toDiscard = aiSelectDiscard(player, state.difficulty);
        get()._doDiscard(playerIdx, toDiscard);
      }
      return;
    }

    const zhaoCards = (byChar.get(targetChar) || []).slice(0, 4);

    // 从手牌移除
    for (const c of zhaoCards) {
      const idx = player.hand.findIndex(h => h.id === c.id);
      if (idx >= 0) player.hand.splice(idx, 1);
    }

    // 添加组合牌
    player.melds.push({
      type: 'zhao',
      cards: zhaoCards,
      isJing: isJingChar(targetChar as CardChar),
    });

    updatePlayerTingAndHu(player);

    set({
      players,
      showZhaoSelection: false,
      zhaoCandidates: [],
      canZhao: false,
    });

    // 招后补摸一张牌
    get()._drawAfterZhao(playerIdx);
  },

  // --- 招后补摸 ---
  _drawAfterZhao: (playerIdx: number) => {
    const state = get();
    if (state.deck.length === 0) {
      get()._handleLiuju();
      return;
    }

    const deck = [...state.deck];
    const drawn = deck.shift()!;
    const players = clonePlayers(state.players);
    const player = players[playerIdx];

    player.hand.push(drawn);
    player.hand = sortHand(player.hand);
    updatePlayerTingAndHu(player);

    set({ players, deck });

    const humanIdx = state.players.findIndex(p => p.type === 'human');
    if (playerIdx === humanIdx) {
      get()._checkHumanActionsAfterDraw(false);
    } else {
      get()._aiContinueAfterDraw(player, playerIdx, drawn, false);
    }
  },

  // ============================================================
  // 13. 胡牌处理
  // ============================================================
  _handleHu: (
    winnerIdx: number,
    isZimo: boolean,
    dianpaoIdx?: number,
    zimoCard?: Card,
  ) => {
    const state = get();
    if (state.showHuResult) return;

    // 匹配 Flame: 设置 isHandlingHu
    set({ isHandlingHu: true, canChi: false, canPeng: false, canZhao: false, canHu: false, isMyTurn: false });

    const players = clonePlayers(state.players);
    const winner = players[winnerIdx];

    // 点炮时检查听牌（自摸不要求isTing）
    if (!isZimo && !winner.isTing) {
      // 匹配 Flame: 清除状态后调用 _nextTurn
      set({
        isHandlingHu: false,
        waitingForResponse: false,
        isDrawing: false,
      });
      clearPendingAIResponses();
      get()._nextTurn();
      return;
    }

    // 点炮时，将弃牌从弃牌区移到赢家手牌
    if (!isZimo && dianpaoIdx !== undefined && state.lastDiscard) {
      const discarder = players[dianpaoIdx];
      const discardIdx = discarder.discards.findIndex(c => c.id === state.lastDiscard!.id);
      if (discardIdx >= 0) {
        discarder.discards.splice(discardIdx, 1);
      }
      winner.hand.push(state.lastDiscard);
      winner.hand = sortHand(winner.hand);
    }

    // 检测胡牌类型
    const huTypeResult = detectHuType(winner.hand, winner.melds);

    // 计算分数
    const piaoValues = players.map(p => p.piao);
    const scoreChanges = calculateScoreChanges(
      isZimo ? 'zimo' : 'dianpao',
      state.baseScore,
      state.multiplierBase,
      huTypeResult,
      piaoValues,
      winnerIdx,
      dianpaoIdx,
    );

    // 更新分数
    for (let i = 0; i < players.length; i++) {
      players[i].score += scoreChanges[i];
    }

    // 更新胡数
    winner.huCount = calculateTotalHu(winner.hand, winner.melds);

    // 庄家流转
    let newDealerIndex = state.dealerIndex;
    if (winnerIdx !== state.dealerIndex) {
      newDealerIndex = (state.dealerIndex + 1) % 3;
    }

    // 构建胡牌结果
    const huResult: HuResult = {
      winnerId: winnerIdx,
      method: isZimo ? 'zimo' : 'dianpao',
      dianpaoPlayerId: isZimo ? undefined : dianpaoIdx,
      huCard: isZimo ? (zimoCard || winner.hand[winner.hand.length - 1]) : state.lastDiscard!,
      huType: huTypeResult.name,
      huCount: winner.huCount,
      multiplier: isZimo ? huTypeResult.zimo : huTypeResult.dianpao,
      scoreChanges,
    };

    // 局结果
    const roundResult: RoundResult = {
      roundNumber: state.roundNumber,
      isLiuju: false,
      winner: winner.name,
      winnerIndex: winnerIdx,
      huType: huTypeResult.name,
      method: isZimo ? '自摸' : '点炮',
      multiplier: huResult.multiplier,
      score: scoreChanges[winnerIdx],
      scoreChanges,
      piaoScores: piaoValues,
    };

    const roundResults = [...state.roundResults, roundResult];

    set({
      players,
      huResult,
      showHuResult: true,
      phase: 'huResult',
      dealerIndex: newDealerIndex,
      roundResults,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
      isDrawing: false,
      isHandlingHu: false,
    });
  },

  // ============================================================
  // 14. 流局处理
  // ============================================================
  _handleLiuju: () => {
    const state = get();
    if (state.showLiujuResult) return;

    const players = clonePlayers(state.players);
    for (const p of players) {
      p.huCount = calculateTotalHu(p.hand, p.melds);
    }

    const roundResult: RoundResult = {
      roundNumber: state.roundNumber,
      isLiuju: true,
      scoreChanges: [0, 0, 0],
    };

    const roundResults = [...state.roundResults, roundResult];

    // 流局庄家不变
    set({
      players,
      showLiujuResult: true,
      phase: 'liujuResult',
      roundResults,
      canChi: false,
      canPeng: false,
      canZhao: false,
      canHu: false,
      canZimo: false,
      isZimoOpportunity: false,
      waitingForResponse: false,
      isDrawing: false,
    });
  },

  // ============================================================
  // 15. 下一回合
  // ============================================================
  _nextTurn: () => {
    const state = get();
    if (state.showHuResult || state.showLiujuResult) return;

    const nextPlayerIndex = (state.currentPlayerIndex + 1) % 3;
    set({ currentPlayerIndex: nextPlayerIndex });
    get()._startTurn();
  },

  // ============================================================
  // 16. 局结束/下一局
  // ============================================================
  nextRound: () => {
    const state = get();
    if (state.roundNumber >= 8) {
      set({ phase: 'settlement' });
    } else {
      set({
        showHuResult: false,
        showLiujuResult: false,
        phase: 'idle',
      });
      get()._startRound();
    }
  },

  closeHuResult: () => {
    const state = get();
    if (state.roundNumber >= 8) {
      set({ phase: 'settlement', showHuResult: false });
    } else {
      set({ showHuResult: false, phase: 'idle' });
      get()._startRound();
    }
  },

  closeLiujuResult: () => {
    const state = get();
    if (state.roundNumber >= 8) {
      set({ phase: 'settlement', showLiujuResult: false });
    } else {
      set({ showLiujuResult: false, phase: 'idle' });
      get()._startRound();
    }
  },

  // ============================================================
  // 17. 招牌选择
  // ============================================================
  selectZhaoCharacter: (char: string) => {
    const state = get();
    const humanIdx = state.players.findIndex(p => p.type === 'human');
    set({ showZhaoSelection: false, zhaoCandidates: [] });
    get()._handleZhaoFromHand(humanIdx, char);
  },

  // ============================================================
  // 18. 通用操作（兼容旧接口）
  // ============================================================
  doAction: (action: PendingAction) => {
    switch (action.action) {
      case 'hu':
        get().respondHu();
        break;
      case 'zimo':
        get().respondHu();
        break;
      case 'zhao':
        get().respondZhao();
        break;
      case 'peng':
        get().respondPeng();
        break;
      case 'chi':
        get().respondChi();
        break;
      case 'pass':
        get().respondPass();
        break;
    }
  },

  // ============================================================
  // 19. 设置
  // ============================================================
  setVolume: (v: number) => set({ volume: v }),
  setDifficulty: (d: string) => set({ difficulty: d }),
}));
