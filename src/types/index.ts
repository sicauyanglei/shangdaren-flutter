export enum CardColor {
  RED = 'red',
  GREEN = 'green',
  BLACK = 'black'
}

export enum MeldType {
  PAIR = 'pair',
  TRIPLET = 'triplet',
  QUARTET = 'quartet',
  SEQUENCE = 'sequence'
}

export enum MeldSource {
  HAND = 'hand',
  PENG = 'peng',
  CHI = 'chi',
  ZHAO = 'zhao'
}

export enum HuMethod {
  DIAN_PAO = 'dian_pao',
  ZI_MO = 'zi_mo'
}

export enum NormalHuType {
  NORMAL_HU = 'normal_hu',
  KA_HU = 'ka_hu',
  TAI_KA = 'tai_ka',
  TAI_HU = 'tai_hu',
  ZHONG_TAI_KA = 'zhong_tai_ka',
  ZHONG_TAI_HU = 'zhong_tai_hu'
}

export enum SpecialHuType {
  KU_HU = 'ku_hu',
  QING_KU_HU = 'qing_ku_hu',
  QING_KU_TAI_KA = 'qing_ku_tai_ka',
  HEI_YUAN = 'hei_yuan',
  HONG_YUAN_3 = 'hong_yuan_3',
  HONG_YUAN_4 = 'hong_yuan_4',
  HONG_YUAN_5 = 'hong_yuan_5',
  HONG_YUAN_6 = 'hong_yuan_6',
  HONG_YUAN_7 = 'hong_yuan_7',
  TEN_PAIRS = 'ten_pairs'
}

export enum ComboHuType {
  QING_HU = 'qing_hu',
  QING_KA_HU = 'qing_ka_hu',
  KU_ZHONG_TAI_KA = 'ku_zhong_tai_ka'
}

export enum TingType {
  TEN_PAIRS = 'ten_pairs',
  HEI_YUAN = 'hei_yuan',
  HONG_YUAN = 'hong_yuan',
  KU_HU = 'ku_hu',
  OTHER = 'other'
}

export enum PlayerType {
  HUMAN = 'human',
  AI = 'ai'
}

export enum BaseScore {
  FIVE = 5,
  TEN = 10,
  TWENTY = 20
}

export enum MultiplierBase {
  TWO = 2,
  FIVE = 5,
  TEN = 10
}

export enum PiaoScore {
  NONE = 0,
  FIVE = 5,
  TEN = 10,
  TWENTY = 20
}

export enum SoundType {
  DISCARD = 'discard',
  DRAW = 'draw',
  CHI = 'chi',
  PENG = 'peng',
  ZHAO = 'zhao',
  HU = 'hu',
  DEAL = 'deal',
  SHUFFLE = 'shuffle',
  WIN = 'win',
  LOSE = 'lose',
  BUTTON_CLICK = 'button_click',
  CARD_CLICK = 'card_click',
  ALERT = 'alert',
  COUNTDOWN = 'countdown'
}

export enum PlayerVoiceType {
  MALE = 'male',
  FEMALE = 'female',
  CHILD = 'child'
}

export enum GameState {
  WAITING = 'waiting',
  SETTING_PIAO = 'setting_piao',
  DEALING = 'dealing',
  PLAYER_TURN = 'player_turn',
  WAITING_RESPONSE = 'waiting_response',
  ROUND_END = 'round_end',
  SESSION_END = 'session_end'
}

export interface CardDefinition {
  character: string;
  sentence: number;
  position: number;
  color: CardColor;
  isSpecial: boolean;
  baseHu: number;
  imageFile: string;
}

export interface Card {
  id: string;
  definition: CardDefinition;
  readonly character: string;
  readonly sentence: number;
  readonly position: number;
  readonly color: CardColor;
  readonly isSpecial: boolean;
  readonly baseHu: number;
}

export interface Meld {
  type: MeldType;
  cards: Card[];
  source: MeldSource;
  huValue: number;
}

export interface HuResult {
  canHu: boolean;
  method: HuMethod;
  normalType?: NormalHuType;
  specialType?: SpecialHuType;
  comboType?: ComboHuType;
  dianPaoMultiplier: number;
  ziMoMultiplier: number;
  huCount: number;
}

export interface TingStatus {
  isTing: boolean;
  tingType: TingType | null;
  tingCards: Card[];
  huCount: number;
  huType: NormalHuType | SpecialHuType | ComboHuType | null;
}

export interface HalfPair {
  cards: Card[];
  sentence: number;
  characters: string[];
}

export interface GameSettings {
  baseScore: BaseScore;
  multiplierBase: MultiplierBase;
}

export interface PlayerStatistics {
  wins: number;
  losses: number;
  maxHuType: string;
  totalHuCount: number;
  averageHuCount: number;
}

export interface RoundSettlement {
  winnerId: string;
  huType: string;
  huMethod: HuMethod;
  huCount: number;
  multiplier: number;
  payments: { playerId: string; payment: number }[];
  winnerScore: number;
}

export const CARD_DEFINITIONS: CardDefinition[] = [
  { character: '上', sentence: 1, position: 0, color: CardColor.RED, isSpecial: true, baseHu: 4, imageFile: 'shang.png' },
  { character: '大', sentence: 1, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'da.png' },
  { character: '人', sentence: 1, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'ren.png' },
  { character: '丘', sentence: 2, position: 0, color: CardColor.RED, isSpecial: false, baseHu: 0, imageFile: 'qiu.png' },
  { character: '乙', sentence: 2, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'yi.png' },
  { character: '己', sentence: 2, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'ji.png' },
  { character: '化', sentence: 3, position: 0, color: CardColor.RED, isSpecial: false, baseHu: 0, imageFile: 'hua.png' },
  { character: '三', sentence: 3, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'san.png' },
  { character: '千', sentence: 3, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'qian.png' },
  { character: '七', sentence: 4, position: 0, color: CardColor.RED, isSpecial: false, baseHu: 0, imageFile: 'qi.png' },
  { character: '十', sentence: 4, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'shi.png' },
  { character: '土', sentence: 4, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'tu.png' },
  { character: '尔', sentence: 5, position: 0, color: CardColor.RED, isSpecial: false, baseHu: 0, imageFile: 'er.png' },
  { character: '小', sentence: 5, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'xiao.png' },
  { character: '生', sentence: 5, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'sheng.png' },
  { character: '八', sentence: 6, position: 0, color: CardColor.RED, isSpecial: false, baseHu: 0, imageFile: 'ba.png' },
  { character: '九', sentence: 6, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'jiu.png' },
  { character: '子', sentence: 6, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'zi.png' },
  { character: '佳', sentence: 7, position: 0, color: CardColor.RED, isSpecial: false, baseHu: 0, imageFile: 'jia.png' },
  { character: '作', sentence: 7, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'zuo.png' },
  { character: '亡', sentence: 7, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'wang.png' },
  { character: '福', sentence: 8, position: 0, color: CardColor.RED, isSpecial: true, baseHu: 4, imageFile: 'fu.png' },
  { character: '禄', sentence: 8, position: 1, color: CardColor.GREEN, isSpecial: false, baseHu: 0, imageFile: 'lu.png' },
  { character: '寿', sentence: 8, position: 2, color: CardColor.BLACK, isSpecial: false, baseHu: 0, imageFile: 'shou.png' },
];

export const MULTIPLIER_TABLE: Record<string, { dianPao: number; ziMo: number }> = {
  [NormalHuType.NORMAL_HU]: { dianPao: 0, ziMo: 1 },
  [NormalHuType.KA_HU]: { dianPao: 1, ziMo: 2 },
  [NormalHuType.TAI_KA]: { dianPao: 2, ziMo: 3 },
  [NormalHuType.TAI_HU]: { dianPao: 1, ziMo: 2 },
  [NormalHuType.ZHONG_TAI_KA]: { dianPao: 7, ziMo: 8 },
  [NormalHuType.ZHONG_TAI_HU]: { dianPao: 6, ziMo: 7 },
  [SpecialHuType.KU_HU]: { dianPao: 5, ziMo: 6 },
  [SpecialHuType.QING_KU_HU]: { dianPao: 6, ziMo: 7 },
  [SpecialHuType.QING_KU_TAI_KA]: { dianPao: 8, ziMo: 9 },
  [SpecialHuType.HEI_YUAN]: { dianPao: 4, ziMo: 5 },
  [SpecialHuType.HONG_YUAN_3]: { dianPao: 3, ziMo: 4 },
  [SpecialHuType.HONG_YUAN_4]: { dianPao: 4, ziMo: 5 },
  [SpecialHuType.HONG_YUAN_5]: { dianPao: 5, ziMo: 6 },
  [SpecialHuType.HONG_YUAN_6]: { dianPao: 6, ziMo: 7 },
  [SpecialHuType.HONG_YUAN_7]: { dianPao: 7, ziMo: 8 },
  [SpecialHuType.TEN_PAIRS]: { dianPao: 10, ziMo: 11 },
  [ComboHuType.QING_HU]: { dianPao: 1, ziMo: 2 },
  [ComboHuType.QING_KA_HU]: { dianPao: 2, ziMo: 3 },
  [ComboHuType.KU_ZHONG_TAI_KA]: { dianPao: 12, ziMo: 13 },
};

let cardIdCounter = 0;

export function createCardByCharacter(character: string): Card {
  const definition = CARD_DEFINITIONS.find(d => d.character === character);
  if (!definition) {
    throw new Error(`Unknown character: ${character}`);
  }
  const id = `${character}-${++cardIdCounter}`;
  return {
    id,
    definition,
    get character() { return definition.character; },
    get sentence() { return definition.sentence; },
    get position() { return definition.position; },
    get color() { return definition.color; },
    get isSpecial() { return definition.isSpecial; },
    get baseHu() { return definition.baseHu; }
  };
}

export function resetCardIdCounter(): void {
  cardIdCounter = 0;
}
