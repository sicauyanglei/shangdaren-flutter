import { Card, CardChar } from './card';

// 玩家类型
export type PlayerType = 'human' | 'ai';

// 组合牌类型
export type MeldType = 'ju' | 'kan' | 'zhao' | 'dui' | 'kao';

// 组合牌
export interface Meld {
  type: MeldType;
  cards: Card[];
  isJing: boolean; // 是否含上/福（精）
}

// 获取组合牌胡数
export function getMeldHuCount(meld: Meld, isHand: boolean = true, isPao: boolean = false): number {
  switch (meld.type) {
    case 'ju':
      return meld.isJing ? 4 : 0;
    case 'kan':
      if (meld.isJing) return 12;
      if (isPao) return 2;
      return isHand ? 3 : 2;
    case 'zhao':
      return meld.isJing ? 16 : 6;
    case 'dui':
      return meld.isJing ? 8 : 0;
    case 'kao':
      return meld.isJing ? 4 : 0;
  }
}

// 玩家
export interface Player {
  id: number;
  name: string;
  type: PlayerType;
  hand: Card[];
  melds: Meld[];
  discards: Card[];
  isTing: boolean;
  isDealer: boolean;
  score: number;
  huCount: number;
  piao: number;           // 飘分（与Flame一致）
  piaoValue: number;      // 向后兼容别名，与piao保持同步
  tingCards: Card[];      // 听牌列表：哪些牌可以胡
  meldHuCount: number;    // 缓存的组合牌胡数
}

// 操作类型
export type ActionType = 'chi' | 'peng' | 'zhao' | 'hu' | 'zimo' | 'pass';

// 待处理操作
export interface PendingAction {
  playerId: number;
  action: ActionType;
  card?: Card;
  chiCards?: Card[];
}

// 游戏阶段
export type GamePhase = 'idle' | 'piao' | 'playing' | 'huResult' | 'liujuResult' | 'settlement';

// 胡牌方式
export type HuMethod = 'dianpao' | 'zimo';

// 胡牌结果
export interface HuResult {
  winnerId: number;
  method: HuMethod;
  dianpaoPlayerId?: number;
  huCard: Card;
  huType: string;
  huCount: number;
  multiplier: number;
  scoreChanges: number[];
}

// 局结果（用于总结算）
export interface RoundResult {
  roundNumber: number;
  isLiuju: boolean;
  winner?: string;
  winnerIndex?: number;
  huType?: string;
  method?: string;
  multiplier?: number;
  score?: number;
  scoreChanges?: number[];
  piaoScores?: number[];
}

// 游戏状态
export interface GameState {
  phase: GamePhase;
  players: Player[];
  deck: Card[];
  currentPlayerIndex: number;
  dealerIndex: number;
  roundNumber: number;
  lastDiscard: Card | null;
  lastDiscardPlayerId: number | null;
  pendingActions: PendingAction[];
  huResult: HuResult | null;
  showHuResult: boolean;
  showLiujuResult: boolean;
  isPiaoPhase: boolean;
  piaoCurrentPlayerIndex: number;
  baseScore: number;
  multiplierBase: number;
  difficulty: string;
  piaoEnabled: boolean;
  volume: number;
  // 操作按钮状态
  canChi: boolean;
  canPeng: boolean;
  canZhao: boolean;
  canHu: boolean;
  canZimo: boolean;
  isZimoOpportunity: boolean;
  // 招牌选择
  showZhaoSelection: boolean;
  zhaoCandidates: string[];
  // 倒计时
  countdown: number;
  // 新摸的牌ID
  newCardId: number | null;
  // 人类玩家是否处于摸牌状态
  isDrawing: boolean;
  // 是否隐藏听牌徽章
  hideTingBadge: boolean;
  // 是否等待人类玩家响应
  waitingForResponse: boolean;
  // 是否轮到人类玩家出牌
  isMyTurn: boolean;
  // 是否正在处理胡牌
  isHandlingHu: boolean;
  // 局结果历史（用于总结算）
  roundResults: RoundResult[];
}
