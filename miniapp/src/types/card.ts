// 字牌类型
export type CardChar = '上' | '大' | '人' | '丘' | '乙' | '己' | '化' | '三' | '千' | '七' | '十' | '土' | '尔' | '小' | '生' | '八' | '九' | '子' | '佳' | '作' | '亡' | '福' | '禄' | '寿';

// 字牌组
export const CARD_GROUPS: CardChar[][] = [
  ['上', '大', '人'],
  ['丘', '乙', '己'],
  ['化', '三', '千'],
  ['七', '十', '土'],
  ['尔', '小', '生'],
  ['八', '九', '子'],
  ['佳', '作', '亡'],
  ['福', '禄', '寿'],
];

// 红字（上/大/人/福/禄/寿）
export const RED_CHARS: CardChar[] = ['上', '大', '人', '福', '禄', '寿'];

// 绿字（丘/乙/己/化/三/千/尔/小/生/佳/作/亡）
export const GREEN_CHARS: CardChar[] = ['丘', '乙', '己', '化', '三', '千', '尔', '小', '生', '佳', '作', '亡'];

// 黑字（七/十/土/八/九/子）
export const BLACK_CHARS: CardChar[] = ['七', '十', '土', '八', '九', '子'];

// 卡牌颜色类型
export type CardColor = 'red' | 'green' | 'black';

// 卡牌
export interface Card {
  id: number;
  char: CardChar;
  color: CardColor;
}

// 获取字的颜色
export function getCardColor(char: CardChar): CardColor {
  if (RED_CHARS.includes(char)) return 'red';
  if (GREEN_CHARS.includes(char)) return 'green';
  return 'black';
}

// 获取字所属组
export function getCardGroup(char: CardChar): number {
  for (let i = 0; i < CARD_GROUPS.length; i++) {
    if (CARD_GROUPS[i].includes(char)) return i;
  }
  return -1;
}

// 创建一副牌（96张）
export function createDeck(): Card[] {
  const cards: Card[] = [];
  let id = 0;
  for (const group of CARD_GROUPS) {
    for (const char of group) {
      for (let i = 0; i < 4; i++) {
        cards.push({ id: id++, char, color: getCardColor(char) });
      }
    }
  }
  return cards;
}

// 洗牌
export function shuffleDeck(cards: Card[]): Card[] {
  const arr = [...cards];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
