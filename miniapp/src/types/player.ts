import { Card, CardChar } from './card';

// 玩家类型
export type PlayerType = 'human' | 'ai';

// 组合牌类型
export type MeldType = 'sentence' | 'triple' | 'quad';

// 组合牌
export interface Meld {
  type: MeldType;
  cards: Card[];
  isJing: boolean; // 是否含上/福（精）
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
  piaoValue: number;
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
}
