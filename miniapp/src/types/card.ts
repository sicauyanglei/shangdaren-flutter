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

// 红字（每句首字：上/丘/化/七/尔/八/佳/福）
export const RED_CHARS: CardChar[] = ['上', '丘', '化', '七', '尔', '八', '佳', '福'];

// 绿字（每句中字：大/乙/三/十/小/九/作/禄）
export const GREEN_CHARS: CardChar[] = ['大', '乙', '三', '十', '小', '九', '作', '禄'];

// 黑字（每句末字：人/己/千/土/生/子/亡/寿）
export const BLACK_CHARS: CardChar[] = ['人', '己', '千', '土', '生', '子', '亡', '寿'];

// 卡牌颜色类型
export type CardColor = 'red' | 'green' | 'black';

// 卡牌
export interface Card {
  id: number;
  char: CardChar;
  color: CardColor;
  sentence: number;  // 1-8, 对应8组
  position: number;  // 0-2, 组内位置
}

// 判断是否精字（上/福）
export function isJingChar(char: CardChar): boolean {
  return char === '上' || char === '福';
}

// 判断是否银字（大/人/禄/寿）
export function isYinChar(char: CardChar): boolean {
  return ['大', '人', '禄', '寿'].includes(char);
}

// 获取字的颜色
export function getCardColor(char: CardChar): CardColor {
  if (RED_CHARS.includes(char)) return 'red';
  if (GREEN_CHARS.includes(char)) return 'green';
  return 'black';
}

// 获取字所属组（返回0-7索引）
export function getCardGroup(char: CardChar): number {
  for (let i = 0; i < CARD_GROUPS.length; i++) {
    if (CARD_GROUPS[i].includes(char)) return i;
  }
  return -1;
}

// 获取字所属组(1-8)
export function getCardSentence(char: CardChar): number {
  const map: Record<CardChar, number> = {
    '上': 1, '大': 1, '人': 1,
    '丘': 2, '乙': 2, '己': 2,
    '化': 3, '三': 3, '千': 3,
    '七': 4, '十': 4, '土': 4,
    '尔': 5, '小': 5, '生': 5,
    '八': 6, '九': 6, '子': 6,
    '佳': 7, '作': 7, '亡': 7,
    '福': 8, '禄': 8, '寿': 8,
  };
  return map[char];
}

// 获取字在组内位置(0-2)
export function getCardPosition(char: CardChar): number {
  const map: Record<CardChar, number> = {
    '上': 0, '大': 1, '人': 2,
    '丘': 0, '乙': 1, '己': 2,
    '化': 0, '三': 1, '千': 2,
    '七': 0, '十': 1, '土': 2,
    '尔': 0, '小': 1, '生': 2,
    '八': 0, '九': 1, '子': 2,
    '佳': 0, '作': 1, '亡': 2,
    '福': 0, '禄': 1, '寿': 2,
  };
  return map[char];
}

// 创建一副牌（96张）
export function createDeck(): Card[] {
  const cards: Card[] = [];
  let id = 0;
  for (let s = 0; s < CARD_GROUPS.length; s++) {
    for (let p = 0; p < CARD_GROUPS[s].length; p++) {
      for (let c = 0; c < 4; c++) {
        cards.push({
          id: id++,
          char: CARD_GROUPS[s][p],
          color: getCardColor(CARD_GROUPS[s][p]),
          sentence: s + 1,
          position: p,
        });
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

// 手牌排序：按sentence升序，同sentence按position升序
export function sortHand(hand: Card[]): Card[] {
  return [...hand].sort((a, b) => {
    if (a.sentence !== b.sentence) return a.sentence - b.sentence;
    if (a.position !== b.position) return a.position - b.position;
    return a.id - b.id;
  });
}
