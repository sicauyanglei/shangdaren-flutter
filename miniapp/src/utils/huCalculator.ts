import { Card, CardChar, CARD_GROUPS, RED_CHARS, getCardGroup } from '../types/card';

// 牌型分类
export type HandTileType =
  | 'puKao'    // 普靠：同组不同2张(不含上/福)
  | 'yinKao'   // 银靠：大人或禄寿
  | 'jingKao'  // 精靠：同组不同2张，含上/福
  | 'puDan'    // 普单：单张(非上/福)
  | 'yinDan'   // 银单：单张(大/人/禄/寿)
  | 'jingDan'  // 精单：上或福
  | 'puDui'    // 普对：同字2张(非上/福)
  | 'yinDui'   // 银对：同字2张(大/人/禄/寿)
  | 'jinDui'   // 金对：上上或福福
  | 'puKan'    // 普坎：同字3张(非上/福)
  | 'jingKan'  // 精坎：上上上或福福福
  | 'puZhao'   // 普招：同字4张(非上/福)
  | 'jingZhao' // 精招：上上上上或福福福福
  | 'puJu'     // 普句：同组不同3张(组2-7)
  | 'jingJu';  // 精句：同组不同3张(组1/8)

// 牌型胡数
const TILE_HU: Record<HandTileType, number> = {
  puKao: 0, yinKao: 0, jingKao: 4,
  puDan: 0, yinDan: 0, jingDan: 4,
  puDui: 0, yinDui: 0, jinDui: 8,
  puKan: 0, jingKan: 12,
  puZhao: 6, jingZhao: 16,
  puJu: 0, jingJu: 4,
};

// 判断是否精字（上/福）
function isJingChar(char: CardChar): boolean {
  return char === '上' || char === '福';
}

// 判断是否银字（大/人/禄/寿）
function isYinChar(char: CardChar): boolean {
  return ['大', '人', '禄', '寿'].includes(char);
}

// 统计手牌中每个字的数量
function countChars(cards: Card[]): Map<CardChar, number> {
  const count = new Map<CardChar, number>();
  for (const c of cards) {
    count.set(c.char, (count.get(c.char) || 0) + 1);
  }
  return count;
}

// 从手牌中提取句
function extractSentences(countMap: Map<CardChar, number>, cards: Card[]): { sentences: Card[][]; remaining: Card[] } {
  const remaining = [...cards];
  const sentences: Card[][] = [];

  for (let g = 0; g < CARD_GROUPS.length; g++) {
    const group = CARD_GROUPS[g];
    while (group.every(ch => (countMap.get(ch) || 0) > 0)) {
      const sentence: Card[] = [];
      for (const ch of group) {
        const idx = remaining.findIndex(c => c.char === ch);
        if (idx >= 0) {
          sentence.push(remaining.splice(idx, 1)[0]);
          countMap.set(ch, (countMap.get(ch) || 0) - 1);
        }
      }
      if (sentence.length === 3) {
        sentences.push(sentence);
      }
    }
  }
  return { sentences, remaining };
}

// 从手牌中提取招（4张同字）
function extractZhaos(countMap: Map<CardChar, number>, cards: Card[]): { zhaos: Card[][]; remaining: Card[] } {
  const remaining = [...cards];
  const zhaos: Card[][] = [];

  for (const [char, count] of countMap) {
    if (count >= 4) {
      const zhao: Card[] = [];
      for (let i = 0; i < 4; i++) {
        const idx = remaining.findIndex(c => c.char === char);
        if (idx >= 0) zhao.push(remaining.splice(idx, 1)[0]);
      }
      if (zhao.length === 4) {
        zhaos.push(zhao);
        countMap.set(char, 0);
      }
    }
  }
  return { zhaos, remaining };
}

// 从手牌中提取坎（3张同字）
function extractTriples(countMap: Map<CardChar, number>, cards: Card[]): { triples: Card[][]; remaining: Card[] } {
  const remaining = [...cards];
  const triples: Card[][] = [];

  for (const [char, count] of countMap) {
    if (count >= 3) {
      const triple: Card[] = [];
      for (let i = 0; i < 3; i++) {
        const idx = remaining.findIndex(c => c.char === char);
        if (idx >= 0) triple.push(remaining.splice(idx, 1)[0]);
      }
      if (triple.length === 3) {
        triples.push(triple);
        countMap.set(char, count - 3);
      }
    }
  }
  return { triples, remaining };
}

// 计算手牌胡数
export function calculateHandHu(hand: Card[]): number {
  const countMap = countChars(hand);
  const { sentences, remaining: r1 } = extractSentences(new Map(countMap), hand);
  const { zhaos, remaining: r2 } = extractZhaos(countChars(r1), r1);
  const { triples, remaining: r3 } = extractTriples(countChars(r2), r2);

  // A集：句
  let aHu = 0;
  const sentenceChars: CardChar[] = [];
  for (const s of sentences) {
    const groupIdx = getCardGroup(s[0].char);
    const isJing = groupIdx === 0 || groupIdx === 7;
    aHu += isJing ? 4 : 0;
    for (const c of s) sentenceChars.push(c.char);
  }

  // B集：招
  let bHu = 0;
  for (const z of zhaos) {
    bHu += isJingChar(z[0].char) ? 16 : 6;
  }

  // C集：坎
  let cHu = 0;
  for (const t of triples) {
    cHu += isJingChar(t[0].char) ? 12 : 0; // 普坎胡数在组合牌计算
  }

  // D集：对/半靠
  const r3Count = countChars(r3);
  let dHu = 0;
  const duiPairs: { char: CardChar; isJing: boolean; isYin: boolean }[] = [];
  const kaoPairs: { chars: CardChar[]; isJing: boolean }[] = [];

  for (const [char, count] of r3Count) {
    if (count >= 2) {
      const jing = isJingChar(char);
      const yin = isYinChar(char);
      duiPairs.push({ char, isJing: jing, isYin: yin });
      dHu += jing ? 8 : 0;
    }
  }

  // 提取半靠（同组不同2张）
  for (let g = 0; g < CARD_GROUPS.length; g++) {
    const group = CARD_GROUPS[g];
    const available = group.filter(ch => (r3Count.get(ch) || 0) > 0);
    if (available.length >= 2) {
      const hasJing = available.some(ch => isJingChar(ch));
      kaoPairs.push({ chars: available.slice(0, 2), isJing: hasJing });
      dHu += hasJing ? 4 : 0;
    }
  }

  // E集：剩余单
  let eHu = 0;
  for (const [char, count] of r3Count) {
    if (count === 1) {
      eHu += isJingChar(char) ? 4 : 0;
    }
  }

  // 附加胡数
  let bonusHu = 0;

  // a. 普对对应字在A中有1张 → +3
  for (const pair of duiPairs) {
    if (!pair.isJing) {
      const countInA = sentenceChars.filter(c => c === pair.char).length;
      if (countInA === 1) bonusHu += 3;
    }
  }

  // b. 普靠中字在A中有2张 → +6
  for (const kao of kaoPairs) {
    if (!kao.isJing) {
      for (const ch of kao.chars) {
        const countInA = sentenceChars.filter(c => c === ch).length;
        if (countInA === 2) { bonusHu += 6; break; }
      }
    }
  }

  // c. 普单在A中有2张 → +3
  for (const [char, count] of r3Count) {
    if (count === 1 && !isJingChar(char)) {
      const countInA = sentenceChars.filter(c => c === char).length;
      if (countInA === 2) bonusHu += 3;
    }
  }

  // d. 3句相同
  const sentenceGroupCount = new Map<number, number>();
  for (const s of sentences) {
    const g = getCardGroup(s[0].char);
    sentenceGroupCount.set(g, (sentenceGroupCount.get(g) || 0) + 1);
  }
  for (const [, count] of sentenceGroupCount) {
    if (count === 3) {
      const g = getCardGroup(sentences[0][0].char);
      bonusHu += (g === 0 || g === 7) ? 6 : 9;
    }
  }

  return aHu + bHu + cHu + dHu + eHu + bonusHu;
}

// 计算组合牌胡数
export function calculateMeldHu(melds: { type: string; cards: Card[]; isJing: boolean }[]): number {
  let hu = 0;
  for (const meld of melds) {
    if (meld.type === 'sentence') {
      hu += meld.isJing ? 4 : 0;
    } else if (meld.type === 'triple') {
      hu += meld.isJing ? 12 : 0;
    } else if (meld.type === 'quad') {
      hu += meld.isJing ? 16 : 6;
    }
  }
  return hu;
}

// 计算总胡数
export function calculateTotalHu(
  melds: { type: string; cards: Card[]; isJing: boolean }[],
  hand: Card[]
): number {
  return calculateMeldHu(melds) + calculateHandHu(hand);
}

// 判断是否可以胡牌
export function canHu(
  melds: { type: string; cards: Card[]; isJing: boolean }[],
  hand: Card[],
  isTing: boolean
): boolean {
  if (!isTing) return false;
  const totalHu = calculateTotalHu(melds, hand);
  // 胡数条件：总胡数≥11 或 满足特殊胡牌类型
  return totalHu >= 11;
}

// 判断是否可以自摸
export function canZimo(
  melds: { type: string; cards: Card[]; isJing: boolean }[],
  hand: Card[]
): boolean {
  const totalHu = calculateTotalHu(melds, hand);
  return totalHu >= 11;
}
