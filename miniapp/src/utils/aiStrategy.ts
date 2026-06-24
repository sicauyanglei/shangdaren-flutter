import { Card, CardChar, CARD_GROUPS, getCardGroup, isJingChar, isYinChar } from '../types/card';
import { Player, Meld, MeldType } from '../types/player';
import { canHu, canZimo, calculateTotalHu } from './huCalculator';
import { isTing, getTingCards } from './tingChecker';

// ============================================================
// 游戏上下文（匹配Flame的GameState，供AI策略使用）
// ============================================================

export interface GameContext {
  /** 所有玩家 */
  players: Player[];
  /** 牌堆剩余数量 */
  deckSize: number;
  /** 当前玩家ID */
  currentPlayerId: number;
  /** 可见牌计数（每个字已出现的数量，包含手牌/组合牌/弃牌） */
  visibleCount: Map<string, number>;
  /** 未知牌总数 */
  totalUnknown: number;
}

/** 从游戏状态构建可见牌计数 */
export function buildVisibleCount(players: Player[], _deckSize: number, currentPlayerId: number): Map<string, number> {
  const counts = new Map<string, number>();
  // 每个字最多4张
  for (const player of players) {
    // 自己的手牌和组合牌可见
    if (player.id === currentPlayerId) {
      for (const card of player.hand) {
        counts.set(card.char, (counts.get(card.char) || 0) + 1);
      }
    }
    // 所有玩家的组合牌可见
    for (const meld of player.melds) {
      for (const card of meld.cards) {
        counts.set(card.char, (counts.get(card.char) || 0) + 1);
      }
    }
    // 所有玩家的弃牌可见
    for (const card of player.discards) {
      counts.set(card.char, (counts.get(card.char) || 0) + 1);
    }
  }
  return counts;
}

/** 计算未知牌总数 */
export function calculateTotalUnknown(players: Player[], _deckSize: number, currentPlayerId: number): number {
  let knownCount = 0;
  for (const player of players) {
    if (player.id === currentPlayerId) {
      knownCount += player.hand.length;
    }
    for (const meld of player.melds) {
      knownCount += meld.cards.length;
    }
    knownCount += player.discards.length;
  }
  // 总牌数96 - 已知牌数 = 未知牌数（包含牌堆和其他玩家手牌）
  return 96 - knownCount;
}

// ============================================================
// 字符映射常量（匹配Flame版本）
// ============================================================

const GROUP_CHARS: string[][] = [
  ['上', '大', '人'],
  ['丘', '乙', '己'],
  ['化', '三', '千'],
  ['七', '十', '土'],
  ['尔', '小', '生'],
  ['八', '九', '子'],
  ['佳', '作', '亡'],
  ['福', '禄', '寿'],
];

const ALL_CHARS: string[] = [
  '上', '大', '人', '丘', '乙', '己', '化', '三', '千',
  '七', '十', '土', '尔', '小', '生', '八', '九', '子',
  '佳', '作', '亡', '福', '禄', '寿',
];

const CHAR_SENTENCE_MAP: Record<string, number> = {
  '上': 1, '大': 1, '人': 1,
  '丘': 2, '乙': 2, '己': 2,
  '化': 3, '三': 3, '千': 3,
  '七': 4, '十': 4, '土': 4,
  '尔': 5, '小': 5, '生': 5,
  '八': 6, '九': 6, '子': 6,
  '佳': 7, '作': 7, '亡': 7,
  '福': 8, '禄': 8, '寿': 8,
};

const CHAR_POSITION_MAP: Record<string, number> = {
  '上': 0, '大': 1, '人': 2,
  '丘': 0, '乙': 1, '己': 2,
  '化': 0, '三': 1, '千': 2,
  '七': 0, '十': 1, '土': 2,
  '尔': 0, '小': 1, '生': 2,
  '八': 0, '九': 1, '子': 2,
  '佳': 0, '作': 1, '亡': 2,
  '福': 0, '禄': 1, '寿': 2,
};

// ============================================================
// 内部Meld类型（用于提取逻辑）
// ============================================================

interface InternalMeld {
  type: MeldType;
  cards: Card[];
  isJing: boolean;
}

// ============================================================
// 提取函数（匹配Flame的HuCalculator提取逻辑）
// ============================================================

function extractJu(remaining: Card[], out: InternalMeld[]): void {
  const bySentence = new Map<number, Card[]>();
  for (const card of remaining) {
    const list = bySentence.get(card.sentence) || [];
    list.push(card);
    bySentence.set(card.sentence, list);
  }

  for (let s = 1; s <= 8; s++) {
    const cards = bySentence.get(s);
    if (!cards) continue;

    const byPos = new Map<number, Card[]>();
    for (const c of cards) {
      const list = byPos.get(c.position) || [];
      list.push(c);
      byPos.set(c.position, list);
    }

    const positions = [...byPos.keys()].sort((a, b) => a - b);
    if (positions.length >= 3) {
      const juCards: Card[] = [];
      for (const pos of positions) {
        const posList = byPos.get(pos);
        if (posList && posList.length > 0) {
          juCards.push(posList.pop()!);
        }
      }
      if (juCards.length === 3) {
        const hasJing = juCards.some(c => isJingChar(c.char));
        out.push({ type: 'ju', cards: juCards, isJing: hasJing });
        for (const c of juCards) {
          const idx = remaining.indexOf(c);
          if (idx >= 0) remaining.splice(idx, 1);
        }
        extractJu(remaining, out);
        return;
      } else {
        for (const c of juCards) {
          const posList = byPos.get(c.position);
          if (posList) posList.push(c);
        }
      }
    }
  }
}

function extractZhao(remaining: Card[], out: InternalMeld[]): void {
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    const list = byChar.get(card.char) || [];
    list.push(card);
    byChar.set(card.char, list);
  }

  for (const [, cards] of byChar) {
    if (cards.length >= 4) {
      const zhaoCards = cards.slice(0, 4);
      out.push({ type: 'zhao', cards: zhaoCards, isJing: isJingChar(zhaoCards[0].char) });
      for (const c of zhaoCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractZhao(remaining, out);
      return;
    }
  }
}

function extractKan(remaining: Card[], out: InternalMeld[]): void {
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    const list = byChar.get(card.char) || [];
    list.push(card);
    byChar.set(card.char, list);
  }

  for (const [, cards] of byChar) {
    if (cards.length >= 3) {
      const kanCards = cards.slice(0, 3);
      out.push({ type: 'kan', cards: kanCards, isJing: isJingChar(kanCards[0].char) });
      for (const c of kanCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractKan(remaining, out);
      return;
    }
  }
}

function extractDuiAndKao(remaining: Card[], out: InternalMeld[]): void {
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    const list = byChar.get(card.char) || [];
    list.push(card);
    byChar.set(card.char, list);
  }

  for (const [, cards] of byChar) {
    if (cards.length >= 2) {
      const duiCards = cards.slice(0, 2);
      out.push({ type: 'dui', cards: duiCards, isJing: isJingChar(duiCards[0].char) });
      for (const c of duiCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractDuiAndKao(remaining, out);
      return;
    }
  }

  const bySentence = new Map<number, Card[]>();
  for (const card of remaining) {
    const list = bySentence.get(card.sentence) || [];
    list.push(card);
    bySentence.set(card.sentence, list);
  }

  for (let s = 1; s <= 8; s++) {
    const cards = bySentence.get(s);
    if (!cards || cards.length < 2) continue;

    const byPos = new Map<number, Card>();
    for (const c of cards) {
      byPos.set(c.position, c);
    }

    const positions = [...byPos.keys()].sort((a, b) => a - b);
    for (let i = 0; i < positions.length - 1; i++) {
      for (let j = i + 1; j < positions.length; j++) {
        const p1 = positions[i];
        const p2 = positions[j];
        if (p1 === p2) continue;
        const c1 = byPos.get(p1)!;
        const c2 = byPos.get(p2)!;
        const hasJing = isJingChar(c1.char) || isJingChar(c2.char);
        out.push({ type: 'kao', cards: [c1, c2], isJing: hasJing });
        const idx1 = remaining.indexOf(c1);
        if (idx1 >= 0) remaining.splice(idx1, 1);
        const idx2 = remaining.indexOf(c2);
        if (idx2 >= 0) remaining.splice(idx2, 1);
        extractDuiAndKao(remaining, out);
        return;
      }
    }
  }
}

function extractKaoFirst(remaining: Card[], out: InternalMeld[]): void {
  const bySentence = new Map<number, Card[]>();
  for (const card of remaining) {
    const list = bySentence.get(card.sentence) || [];
    list.push(card);
    bySentence.set(card.sentence, list);
  }

  for (let s = 1; s <= 8; s++) {
    const cards = bySentence.get(s);
    if (!cards || cards.length < 2) continue;

    const byPos = new Map<number, Card>();
    for (const c of cards) {
      byPos.set(c.position, c);
    }

    const positions = [...byPos.keys()].sort((a, b) => a - b);
    for (let i = 0; i < positions.length - 1; i++) {
      for (let j = i + 1; j < positions.length; j++) {
        const p1 = positions[i];
        const p2 = positions[j];
        if (p1 === p2) continue;
        const c1 = byPos.get(p1)!;
        const c2 = byPos.get(p2)!;
        const hasJing = isJingChar(c1.char) || isJingChar(c2.char);
        out.push({ type: 'kao', cards: [c1, c2], isJing: hasJing });
        const idx1 = remaining.indexOf(c1);
        if (idx1 >= 0) remaining.splice(idx1, 1);
        const idx2 = remaining.indexOf(c2);
        if (idx2 >= 0) remaining.splice(idx2, 1);
        extractKaoFirst(remaining, out);
        return;
      }
    }
  }

  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    const list = byChar.get(card.char) || [];
    list.push(card);
    byChar.set(card.char, list);
  }

  for (const [, cards] of byChar) {
    if (cards.length >= 2) {
      const duiCards = cards.slice(0, 2);
      out.push({ type: 'dui', cards: duiCards, isJing: isJingChar(duiCards[0].char) });
      for (const c of duiCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractKaoFirst(remaining, out);
      return;
    }
  }
}

// ============================================================
// 辅助函数
// ============================================================

/** 计算手牌中的对数 */
function countHandPairs(hand: Card[]): number {
  const byChar = new Map<string, number>();
  for (const card of hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }
  let pairs = 0;
  for (const count of byChar.values()) {
    pairs += Math.floor(count / 2);
  }
  return pairs;
}

/** 计算手牌+组合牌中的对数（匹配Flame的_countHandPairsWithMelds） */
function countHandPairsWithMelds(hand: Card[], melds: Meld[]): number {
  const byChar = new Map<string, number>();
  for (const card of hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }
  let pairs = 0;
  for (const count of byChar.values()) {
    if (count === 2) pairs++;
    if (count === 4) pairs += 2;
  }
  for (const meld of melds) {
    if (meld.type === 'kan') pairs++;
    if (meld.type === 'zhao') pairs += 2;
  }
  return pairs;
}

/** 构建手牌字计数 */
function buildCharCount(hand: Card[]): Map<string, number> {
  const result = new Map<string, number>();
  for (const card of hand) {
    result.set(card.char, (result.get(card.char) || 0) + 1);
  }
  return result;
}

/** 查找靠的缺失字（组成完整句缺少的字） */
function findMissingCharForSentence(existingChars: string[]): string | null {
  if (existingChars.length !== 2) return null;
  const sentence = CHAR_SENTENCE_MAP[existingChars[0]];
  if (!sentence) return null;
  const fullGroup = GROUP_CHARS[sentence - 1];
  for (const ch of fullGroup) {
    if (!existingChars.includes(ch)) return ch;
  }
  return null;
}

/** 判断是否银字 */
function isYin(card: Card): boolean {
  return card.char === '大' || card.char === '人' || card.char === '禄' || card.char === '寿';
}

/** 判断卡牌是否是坎的一部分 */
function isPartOfKan(card: Card, charCount: Map<string, number>): boolean {
  return (charCount.get(card.char) || 0) >= 3;
}

/** 判断卡牌是否是招的一部分 */
function isPartOfZhao(card: Card, charCount: Map<string, number>): boolean {
  return (charCount.get(card.char) || 0) >= 4;
}

/** 计算总牌数（手牌+组合牌，组合牌每组计3） */
function getTotalCardCount(hand: Card[], melds: Meld[]): number {
  return hand.length + melds.length * 3;
}

/** 计算某字的剩余张数（匹配Flame的_remainingCount） */
function remainingCount(character: string, visibleCount: Map<string, number>): number {
  const rem = 4 - (visibleCount.get(character) || 0);
  return rem > 0 ? rem : 0;
}

/** 构建可用字列表（还有剩余张数的字） */
function buildAvailableChars(visibleCount: Map<string, number>): string[] {
  const result: string[] = [];
  for (const ch of ALL_CHARS) {
    if (remainingCount(ch, visibleCount) > 0) {
      result.push(ch);
    }
  }
  return result;
}

/** 判断是否晚期（牌堆<20） */
function isLateGame(deckSize: number): boolean {
  return deckSize < 20;
}

/** 判断是否早期（牌堆>50） */
function isEarlyGame(deckSize: number): boolean {
  return deckSize > 50;
}

// ============================================================
// 听牌距离计算（匹配Flame的AIStrategyHard）
// ============================================================

/** 十对听牌距离 */
function distanceToTingShiDui(hand: Card[], melds: Meld[]): number {
  const byChar = new Map<string, number>();
  for (const card of hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }

  let meldPairs = 0;
  for (const m of melds) {
    if (m.type === 'kan') meldPairs += 1;
    if (m.type === 'zhao') meldPairs += 2;
  }

  let pairs = 0;
  for (const count of byChar.values()) {
    if (count >= 4) pairs += 2;
    else if (count === 3) pairs += 1;
    else if (count === 2) pairs += 1;
  }
  pairs += meldPairs;

  let dist = 10 - pairs;
  if (dist < 0) dist = 0;
  if (dist > 10) dist = 10;
  return dist;
}

/** 普通胡听牌距离 */
function distanceToTingNormal(hand: Card[], melds: Meld[]): number {
  let bestDist = 10;

  for (let mode = 0; mode < 2; mode++) {
    const remaining = [...hand];
    const aSet: InternalMeld[] = [];
    const bSet: InternalMeld[] = [];
    const cSet: InternalMeld[] = [];
    const eSet: Card[] = [];

    extractJu(remaining, aSet);
    extractZhao(remaining, bSet);
    extractKan(remaining, cSet);

    const dSet: InternalMeld[] = [];
    if (mode === 0) {
      extractDuiAndKao(remaining, dSet);
    } else {
      extractKaoFirst(remaining, dSet);
    }
    eSet.push(...remaining);

    let totalMelds = aSet.length + bSet.length + cSet.length;
    for (const m of melds) {
      if (m.type === 'ju' || m.type === 'kan' || m.type === 'zhao') {
        totalMelds++;
      }
    }

    let neededMelds = 6 - totalMelds;
    if (neededMelds < 0) neededMelds = 0;

    let usefulDuiKao = 0;
    for (const meld of dSet) {
      if (meld.type === 'kao' || meld.type === 'dui') {
        usefulDuiKao++;
      }
    }

    let potentialKaoFromSingles = 0;
    const singleByGroup = new Map<number, Card[]>();
    for (const card of eSet) {
      const list = singleByGroup.get(card.sentence) || [];
      list.push(card);
      singleByGroup.set(card.sentence, list);
    }
    for (const [, groupCards] of singleByGroup) {
      if (groupCards.length >= 2) {
        potentialKaoFromSingles += Math.floor(groupCards.length / 2);
      }
    }

    let dist = neededMelds * 2 - usefulDuiKao - potentialKaoFromSingles;
    if (dist < 0) dist = 0;
    if (dist > 10) dist = 10;
    if (dist < bestDist) bestDist = dist;
  }

  return bestDist;
}

/** 计算听牌距离 */
function distanceToTing(hand: Card[], melds: Meld[]): number {
  const pairDist = distanceToTingShiDui(hand, melds);
  const normalDist = distanceToTingNormal(hand, melds);
  return Math.min(pairDist, normalDist);
}

// ============================================================
// distanceToTing缓存机制（匹配Flame的_distanceCache）
// ============================================================

let _distanceCache = new Map<string, number>();
let _huScoreCache = new Map<string, number>();

/** 生成手牌缓存key */
function handCacheKey(hand: Card[], melds: Meld[]): string {
  const charCount = new Map<string, number>();
  for (const c of hand) {
    charCount.set(c.char, (charCount.get(c.char) || 0) + 1);
  }
  const meldKey = melds.map(m => `${m.type}${m.cards[0].char}${m.isJing ? 'j' : ''}`).join(',');
  const handKey = Array.from(charCount.entries()).sort((a, b) => a[0].localeCompare(b[0])).map(([ch, cnt]) => `${ch}${cnt}`).join('');
  return `${handKey}|${meldKey}`;
}

/** 带缓存的听牌距离计算（匹配Flame的_distanceCache） */
function distanceToTingCached(hand: Card[], melds: Meld[]): number {
  const key = handCacheKey(hand, melds);
  const cached = _distanceCache.get(key);
  if (cached !== undefined) return cached;
  const result = distanceToTing(hand, melds);
  _distanceCache.set(key, result);
  return result;
}

/** 带缓存的胡数评估（匹配Flame的_huScoreCache） */
function evaluateHuScoreCached(hand: Card[], melds: Meld[]): number {
  const key = handCacheKey(hand, melds);
  const cached = _huScoreCache.get(key);
  if (cached !== undefined) return cached;
  const result = evaluateHuScore(hand, melds);
  _huScoreCache.set(key, result);
  return result;
}

/** 清除缓存（每次selectDiscardHard调用前清除，避免缓存膨胀） */
function clearAICaches(): void {
  _distanceCache.clear();
  _huScoreCache.clear();
}

/** 评估手牌潜力和距离（匹配Flame的_evaluateHandPotentialAndDistance，含可见牌概率） */
function evaluateHandPotentialAndDistance(
  hand: Card[],
  melds: Meld[],
  visibleCount: Map<string, number>,
  totalUnknown: number,
): { potential: number; distance: number } {
  const remaining = [...hand];
  const aSet: InternalMeld[] = [];
  const bSet: InternalMeld[] = [];
  const cSet: InternalMeld[] = [];
  const dSet: InternalMeld[] = [];
  const eSet: Card[] = [];

  extractJu(remaining, aSet);
  extractZhao(remaining, bSet);
  extractKan(remaining, cSet);
  extractDuiAndKao(remaining, dSet);
  eSet.push(...remaining);

  let totalMelds = aSet.length + bSet.length + cSet.length;
  for (const m of melds) {
    if (m.type === 'ju' || m.type === 'kan' || m.type === 'zhao') {
      totalMelds++;
    }
  }

  let neededMelds = 6 - totalMelds;
  if (neededMelds < 0) neededMelds = 0;

  let usefulDuiKao = 0;
  for (const meld of dSet) {
    if (meld.type === 'kao' || meld.type === 'dui') {
      usefulDuiKao++;
    }
  }

  let distance = neededMelds * 2 - usefulDuiKao;
  if (distance < 0) distance = 0;
  if (distance > 10) distance = 10;

  const pairCount = countHandPairs(hand);
  if (pairCount >= 9) {
    let prob = 0;
    const byChar = new Map<string, number>();
    for (const card of hand) {
      byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
    }
    for (const [ch, count] of byChar) {
      if (count === 1 || count === 3) {
        const rem = remainingCount(ch, visibleCount);
        if (rem > 0) prob += rem / totalUnknown;
      }
    }
    return { potential: 500 + prob * 200, distance };
  }

  let score = 0;
  score += aSet.length * 100.0;
  score += bSet.length * 150.0;
  score += cSet.length * 120.0;

  for (const meld of aSet) {
    if (meld.isJing) score += 20;
  }
  for (const meld of bSet) {
    if (meld.isJing) score += 30;
  }
  for (const meld of cSet) {
    if (meld.isJing) score += 25;
  }

  // 评估对和靠，增加进张概率权重（匹配Flame）
  for (const meld of dSet) {
    if (meld.type === 'dui') {
      const ch = meld.cards[0].char;
      const inJu = aSet.some(m => m.cards.some(c => c.char === ch));
      if (inJu) {
        score += 40;
      } else {
        const rem = remainingCount(ch, visibleCount);
        if (rem >= 1) {
          score += 30 + rem * 12;
        } else {
          score += 3;
        }
      }
      if (meld.isJing) score += 20;
    } else if (meld.type === 'kao') {
      const chars = meld.cards.map(c => c.char);
      const missingChar = findMissingCharForSentence(chars);
      if (missingChar) {
        const rem = remainingCount(missingChar, visibleCount);
        if (rem >= 1) {
          score += 50 + rem * 20;
        } else {
          score -= 10;
        }
      } else {
        score += 60;
      }
      if (meld.isJing) score += 15;
    }
  }

  // 评估孤张牌的价值，考虑半搭子（匹配Flame）
  for (const card of eSet) {
    const sameGroup = hand.filter(c => c.sentence === card.sentence);
    const groupCharSet = new Set(sameGroup.map(c => c.char));

    if (groupCharSet.size >= 2) {
      const missingChars = GROUP_CHARS[card.sentence - 1].filter(ch => !groupCharSet.has(ch as CardChar));
      let missingProb = 0;
      let totalRem = 0;
      for (const ch of missingChars) {
        const rem = remainingCount(ch, visibleCount);
        if (rem > 0) {
          missingProb += rem / totalUnknown;
          totalRem += rem;
        }
      }
      score += missingProb * 80 + totalRem * 5;
      if (groupCharSet.size >= 3) {
        score += 50;
      }
    } else {
      const otherChars = GROUP_CHARS[card.sentence - 1].filter(ch => ch !== card.char);
      let partnerProb = 0;
      let partnerRem = 0;
      for (const ch of otherChars) {
        const rem = remainingCount(ch, visibleCount);
        if (rem > 0) {
          partnerProb += rem / totalUnknown;
          partnerRem += rem;
        }
      }
      score -= 20;
      score += partnerProb * 8 + partnerRem * 1;
      if (partnerRem === 0) {
        score -= 50;
      }
    }

    if (isJingChar(card.char)) {
      score += 20;
    } else if (isYin(card)) {
      score += 3;
    }
  }

  // 基本听牌条件b.1/b.2加分（匹配Flame）
  if (dSet.length === 0 && eSet.length === 1) {
    const singleChar = eSet[0].char;
    const rem = remainingCount(singleChar, visibleCount);
    score += 150 + rem * 20;
    const kaoChars = GROUP_CHARS[eSet[0].sentence - 1].filter(ch => ch !== singleChar);
    for (const ch of kaoChars) {
      const r = remainingCount(ch, visibleCount);
      if (r > 0) score += r * 10;
    }
  } else if (dSet.length === 2 && eSet.length === 0) {
    let pairProb = 0;
    for (const meld of dSet) {
      if (meld.type === 'dui') {
        const ch = meld.cards[0].char;
        const rem = remainingCount(ch, visibleCount);
        if (rem > 0) pairProb += rem / totalUnknown;
      } else if (meld.type === 'kao') {
        const chars = meld.cards.map(c => c.char);
        const missing = findMissingCharForSentence(chars);
        if (missing) {
          const rem = remainingCount(missing, visibleCount);
          if (rem > 0) pairProb += rem / totalUnknown;
        }
      }
    }
    score += 130 + pairProb * 100;
  }

  // 十对潜力加分
  if (pairCount >= 7 && pairCount < 9) {
    const byChar = new Map<string, number>();
    for (const card of hand) {
      byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
    }
    let singlesNeedingPair = 0;
    let pairProb = 0;
    for (const [ch, count] of byChar) {
      if (count === 1) {
        singlesNeedingPair++;
        const rem = remainingCount(ch, visibleCount);
        if (rem > 0) pairProb += rem / totalUnknown;
      }
    }
    if (singlesNeedingPair <= 10 - pairCount) {
      score += pairCount * 30 + pairProb * 100;
    }
  }

  score += (10 - distance) * 30;

  return { potential: score, distance };
}

// ============================================================
// 高级评估函数（匹配Flame的AIStrategyHard）
// ============================================================

/** 评估十对潜力（匹配Flame的_evaluateShiDuiPotential） */
function evaluateShiDuiPotential(
  hand: Card[],
  melds: Meld[],
  visibleCount: Map<string, number>,
  totalUnknown: number,
): number {
  const pairCount = countHandPairsWithMelds(hand, melds);
  if (pairCount < 7) return -1;

  const byChar = new Map<string, number>();
  for (const card of hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }

  let prob = 0;
  for (const [ch, count] of byChar) {
    if (count === 1) {
      const rem = remainingCount(ch, visibleCount);
      if (rem > 0) prob += rem / totalUnknown;
    }
  }

  let score = pairCount * 80.0 + prob * 200;
  if (pairCount >= 9) score += 500;
  if (pairCount >= 8) score += 200;

  return score;
}

/** 评估胡数（匹配Flame的_evaluateHuScore） */
function evaluateHuScore(hand: Card[], melds: Meld[]): number {
  return calculateTotalHu(hand, melds);
}

/** 找到组合牌后最佳出牌（匹配Flame的_findBestDiscardAfterMeld） */
function findBestDiscardAfterMeld(
  hand: Card[],
  melds: Meld[],
): { bestHand: Card[]; bestDist: number } {
  if (hand.length === 0) return { bestHand: hand, bestDist: distanceToTingCached(hand, melds) };

  let bestDist = 99;
  let bestHand = hand;

  for (const card of hand) {
    const testHand = hand.filter(c => c.id !== card.id);
    const dist = distanceToTingCached(testHand, melds);
    if (dist < bestDist) {
      bestDist = dist;
      bestHand = testHand;
    }
  }

  return { bestHand, bestDist };
}

/** 前瞻评分（匹配Flame的_lookaheadScore） */
function lookaheadScore(
  testHand: Card[],
  melds: Meld[],
  visibleCount: Map<string, number>,
  totalUnknown: number,
  availableChars: string[],
): number {
  let totalScore = 0;

  const handGroups = new Set<number>();
  for (const card of testHand) {
    handGroups.add(card.sentence);
  }

  for (const ch of availableChars) {
    const sentence = CHAR_SENTENCE_MAP[ch];
    if (!sentence) continue;

    if (!handGroups.has(sentence)) continue;

    const rem = remainingCount(ch, visibleCount);
    if (rem <= 0) continue;

    const prob = rem / totalUnknown;
    if (prob < 0.01) continue;

    const position = CHAR_POSITION_MAP[ch];
    if (position === undefined || position < 0) continue;

    const simHand = [...testHand, {
      id: -100,
      char: ch as CardChar,
      color: 'red' as const,
      sentence,
      position,
    }];
    const dist = distanceToTingCached(simHand, melds);
    if (dist <= 0) {
      totalScore += prob * 500;
    } else {
      totalScore += prob * (10 - dist) * 20;
    }
  }

  return totalScore;
}

/** 两步前瞻（匹配Flame的_twoStepLookahead） */
function twoStepLookahead(
  hand: Card[],
  melds: Meld[],
  cardToDiscard: Card,
  visibleCount: Map<string, number>,
  totalUnknown: number,
  availableChars: string[],
): number {
  const testHand = hand.filter(c => c.id !== cardToDiscard.id);

  const distBefore = distanceToTingCached(testHand, melds);
  if (distBefore > 5) return 0;

  const handGroups = new Set<number>();
  for (const card of testHand) {
    handGroups.add(card.sentence);
  }

  let totalScore = 0;

  for (const ch of availableChars) {
    const sentence = CHAR_SENTENCE_MAP[ch];
    if (!sentence) continue;

    const rem = remainingCount(ch, visibleCount);
    if (rem <= 0) continue;

    const prob = rem / totalUnknown;

    if (!handGroups.has(sentence)) {
      if (prob < 0.03) continue;

      const position = CHAR_POSITION_MAP[ch];
      if (position === undefined || position < 0) continue;

      const simHand = [...testHand, {
        id: -100,
        char: ch as CardChar,
        color: 'red' as const,
        sentence,
        position,
      }];
      const dist = distanceToTingCached(simHand, melds);
      const improvement = distBefore - dist;
      if (improvement > 0) {
        totalScore += prob * improvement * 60;
      }
      continue;
    }

    if (prob < 0.01) continue;

    const position = CHAR_POSITION_MAP[ch];
    if (position === undefined || position < 0) continue;

    const simHand = [...testHand, {
      id: -100,
      char: ch as CardChar,
      color: 'red' as const,
      sentence,
      position,
    }];
    const dist = distanceToTingCached(simHand, melds);

    if (dist <= 0) {
      totalScore += prob * 1000;
    } else {
      const improvement = distBefore - dist;
      if (improvement > 0) {
        totalScore += prob * improvement * 100;
      }
    }
  }

  return totalScore;
}

/** 预期步数到听牌（匹配Flame的_expectedStepsToTing） */
function expectedStepsToTing(
  hand: Card[],
  melds: Meld[],
  visibleCount: Map<string, number>,
  totalUnknown: number,
): number {
  const currentDist = distanceToTingCached(hand, melds);
  if (currentDist <= 0) return 0;

  let totalImproveProb = 0;
  const handGroups = new Set<number>();
  for (const card of hand) {
    handGroups.add(card.sentence);
  }

  for (const ch of ALL_CHARS) {
    const sentence = CHAR_SENTENCE_MAP[ch];
    if (!sentence) continue;
    if (!handGroups.has(sentence)) continue;

    const rem = remainingCount(ch, visibleCount);
    if (rem <= 0) continue;

    const prob = rem / totalUnknown;
    const position = CHAR_POSITION_MAP[ch];
    if (position === undefined || position < 0) continue;

    const simHand = [...hand, {
      id: -100,
      char: ch as CardChar,
      color: 'red' as const,
      sentence,
      position,
    }];
    const newDist = distanceToTingCached(simHand, melds);
    const improvement = currentDist - newDist;
    if (improvement > 0) {
      totalImproveProb += prob * improvement;
    }
  }

  if (totalImproveProb <= 0.01) return currentDist * 2.0;
  return currentDist / totalImproveProb;
}

/** 评估出牌危险性（匹配Flame的_evaluateDanger） */
function evaluateDanger(
  player: Player,
  cardToDiscard: Card,
  ctx: GameContext,
  isLate: boolean,
  myDist?: number,
): number {
  let danger = 0;
  const isMidGame = ctx.deckSize >= 20 && ctx.deckSize <= 50;

  for (const other of ctx.players) {
    if (other.id === player.id) continue;

    // 对方听牌时更危险
    if (other.isTing) {
      const otherMeldChars = new Set<string>();
      for (const meld of other.melds) {
        for (const c of meld.cards) {
          otherMeldChars.add(c.char);
        }
      }

      const sameGroupChars = GROUP_CHARS[cardToDiscard.sentence - 1];
      for (const mc of sameGroupChars) {
        if (otherMeldChars.has(mc)) {
          danger += isLate ? 60 : 40;
          break;
        }
      }

      if (isJingChar(cardToDiscard.char)) {
        danger += isLate ? 100 : 60;
      }

      if (isYin(cardToDiscard)) {
        danger += isLate ? 40 : 20;
      }

      danger += isLate ? 25 : 12;

      for (const meld of other.melds) {
        const meldSentence = meld.cards[0].sentence;
        if (meldSentence === cardToDiscard.sentence) {
          danger += isLate ? 50 : 30;
        }
      }
    }

    // 对方未听牌但面子多时
    if (!other.isTing && other.melds.length >= 3) {
      danger += isLate ? 15 : 8;
    }

    if (isMidGame && !other.isTing) {
      const discardGroups = new Set<number>();
      for (const dc of other.discards) {
        discardGroups.add(dc.sentence);
      }
      const meldGroups = new Set<number>();
      for (const meld of other.melds) {
        meldGroups.add(meld.cards[0].sentence);
      }
      if (meldGroups.has(cardToDiscard.sentence) &&
          !discardGroups.has(cardToDiscard.sentence)) {
        danger += 10;
      }
    }

    const otherDiscardChars = new Set<string>();
    for (const dc of other.discards) {
      otherDiscardChars.add(dc.char);
    }
    const sameGroupChars = GROUP_CHARS[cardToDiscard.sentence - 1];
    let discardedByOther = 0;
    for (const gc of sameGroupChars) {
      if (otherDiscardChars.has(gc)) discardedByOther++;
    }
    if (discardedByOther === 0 && other.melds.length > 0) {
      danger += isLate ? 15 : 8;
    }

    const otherMeldChars = new Set<string>();
    for (const meld of other.melds) {
      for (const c of meld.cards) {
        otherMeldChars.add(c.char);
      }
    }
    for (const gc of sameGroupChars) {
      if (otherMeldChars.has(gc) && !otherDiscardChars.has(gc)) {
        danger += isLate ? 20 : 12;
        break;
      }
    }
  }

  // 自己听牌时进攻优先
  if (player.isTing) {
    danger *= 0.1;
  }

  const actualMyDist = myDist ?? distanceToTingCached([...player.hand], player.melds);
  if (actualMyDist <= 2) {
    danger *= 0.15;
  } else if (actualMyDist <= 4) {
    danger *= 0.4;
  }

  return danger;
}

/** 综合出牌评估（匹配Flame的_evaluateDiscardComprehensiveWithDist） */
function evaluateDiscardComprehensiveWithDist(
  player: Player,
  cardToDiscard: Card,
  testHand: Card[],
  _quickDist: number,
  ctx: GameContext,
  visibleCount: Map<string, number>,
  totalUnknown: number,
  isLate: boolean,
  shiDuiPotential: number,
  availableChars: string[],
): number {
  const { potential, distance: distToTing } = evaluateHandPotentialAndDistance(
    testHand, player.melds, visibleCount, totalUnknown,
  );

  let score = potential;

  if (distToTing <= 4) {
    score += lookaheadScore(testHand, player.melds, visibleCount, totalUnknown, availableChars);
  }

  if (shiDuiPotential > 0) {
    const testPairCount = countHandPairsWithMelds(testHand, player.melds);
    if (testPairCount >= 7) {
      score += testPairCount * 20.0;
    }
  }

  if (isJingChar(cardToDiscard.char)) {
    score -= 80;
  } else if (isYin(cardToDiscard)) {
    score -= 20;
  }

  score += (10 - distToTing) * 120;

  if (isLate) {
    score += (10 - distToTing) * 150;
    if (distToTing <= 2) {
      score += 800;
    }
  }

  if (isEarlyGame(ctx.deckSize)) {
    const sameGroup = player.hand.filter(c => c.sentence === cardToDiscard.sentence);
    const groupCharSet = new Set(sameGroup.map(c => c.char));
    if (groupCharSet.size >= 2) {
      score -= 30;
      if (groupCharSet.size >= 3) {
        score -= 20;
      }
    }
    const otherChars = GROUP_CHARS[cardToDiscard.sentence - 1].filter(ch => ch !== cardToDiscard.char);
    let partnerRem = 0;
    for (const ch of otherChars) {
      partnerRem += remainingCount(ch, visibleCount);
    }
    if (partnerRem > 0) {
      score -= partnerRem * 3;
    }
    if (isJingChar(cardToDiscard.char)) {
      score -= 20;
    }
  }

  score -= evaluateDanger(player, cardToDiscard, ctx, isLate, distToTing);

  if (distToTing > 0 && distToTing <= 4) {
    const expSteps = expectedStepsToTing(testHand, player.melds, visibleCount, totalUnknown);
    score += (10 - expSteps) * 50;
  }

  return score;
}

// ============================================================
// AI操作检测函数
// ============================================================

/**
 * 检查AI玩家是否可以自摸
 * 自摸不要求isTing
 */
export function aiCanZimo(hand: Card[], melds: Meld[]): boolean {
  return canZimo(hand, melds);
}

/**
 * 检查AI玩家是否可以胡（点炮场景，需要isTing）
 */
export function aiCanHu(hand: Card[], melds: Meld[], playerIsTing: boolean): boolean {
  return canHu(hand, melds, playerIsTing);
}

/**
 * 检查AI玩家是否可以招（4-of-a-kind）
 */
export function aiCanZhao(hand: Card[], melds: Meld[], discardedChar: CardChar): boolean {
  const totalCount = getTotalCardCount(hand, melds);
  const sameCount = hand.filter(c => c.char === discardedChar).length;

  // 手牌中有3张同字，且总牌数19张时可以招别人出的牌
  if (sameCount >= 3 && totalCount === 19) return true;

  // 手牌中有1张以上同字，且已有该字的坎可以升级为招（匹配Flame）
  if (sameCount >= 1) {
    const existingKan = melds.find(m => m.type === 'kan' && m.cards[0].char === discardedChar);
    if (existingKan) return true;
  }

  return false;
}

/**
 * 检查AI玩家是否可以碰（3-of-a-kind）
 */
export function aiCanPeng(hand: Card[], melds: Meld[], discardedChar: CardChar): boolean {
  const totalCount = getTotalCardCount(hand, melds);
  if (totalCount === 20) return false;

  const sameCount = hand.filter(c => c.char === discardedChar).length;
  return sameCount >= 2;
}

/**
 * 检查AI玩家是否可以吃（sentence meld）
 */
export function aiCanChi(hand: Card[], melds: Meld[], discardedChar: CardChar, difficulty: string): boolean {
  const totalCount = getTotalCardCount(hand, melds);
  if (totalCount === 20) return false;

  const sentence = CHAR_SENTENCE_MAP[discardedChar];
  if (!sentence) return false;
  const group = GROUP_CHARS[sentence - 1];
  const otherChars = group.filter(ch => ch !== discardedChar);

  const hasAll = otherChars.every(ch => hand.some(c => c.char === ch));
  if (!hasAll) return false;

  // 困难模式：规则14 - 如果手牌有且只有这张卡牌完整的1句，不吃
  if (difficulty === 'hard') {
    if (hasCompleteSentenceWithSingleCards(hand, discardedChar)) {
      return false;
    }
  }

  return true;
}

/** 检查手牌中是否已有包含出牌的完整一句，且每个字都只有1张 */
function hasCompleteSentenceWithSingleCards(hand: Card[], discardedChar: CardChar): boolean {
  const sentence = CHAR_SENTENCE_MAP[discardedChar];
  if (!sentence) return false;
  const groupChars = GROUP_CHARS[sentence - 1];

  const charCount = new Map<string, number>();
  for (const ch of groupChars) {
    charCount.set(ch, 0);
  }
  for (const c of hand) {
    if (c.sentence === sentence && charCount.has(c.char)) {
      charCount.set(c.char, charCount.get(c.char)! + 1);
    }
  }

  const allPresent = [...charCount.values()].every(count => count >= 1);
  const allSingle = [...charCount.values()].every(count => count === 1);

  return allPresent && allSingle && groupChars.includes(discardedChar);
}

// ============================================================
// AI出牌策略
// ============================================================

/**
 * AI决定出哪张牌
 */
export function aiDecideDiscard(hand: Card[], melds: Meld[], difficulty: string, ctx?: GameContext): Card {
  if (hand.length === 0) return hand[0];
  if (hand.length <= 1) return hand[0];

  if (difficulty === 'easy') {
    return selectDiscardEasy(hand, melds);
  } else if (difficulty === 'medium') {
    return selectDiscardMedium(hand, melds);
  } else {
    return selectDiscardHard(hand, melds, ctx);
  }
}

/** 简单模式：随机出牌 */
function selectDiscardEasy(hand: Card[], _melds: Meld[]): Card {
  const singles = hand.filter(c => {
    const sameCount = hand.filter(h => h.char === c.char).length;
    return sameCount === 1 && !isJingChar(c.char) && !isYin(c);
  });

  if (singles.length > 0) {
    return singles[Math.floor(Math.random() * singles.length)];
  }

  const nonJing = hand.filter(c => !isJingChar(c.char));
  if (nonJing.length > 0) {
    return nonJing[Math.floor(Math.random() * nonJing.length)];
  }

  return hand[Math.floor(Math.random() * hand.length)];
}

/** 中等模式：基础听牌感知 */
function selectDiscardMedium(hand: Card[], melds: Meld[]): Card {
  if (isTing(hand, melds)) {
    return selectDiscardWhenTing(hand, melds);
  }

  const charCount = buildCharCount(hand);
  const scored = hand.map(card => ({
    card,
    score: evaluateCardMedium(card, hand, melds, charCount),
  }));

  scored.sort((a, b) => a.score - b.score);
  return scored[0].card;
}

/** 中等模式卡牌评估 */
function evaluateCardMedium(card: Card, hand: Card[], melds: Meld[], charCount: Map<string, number>): number {
  let score = 0;
  const sameCharCount = charCount.get(card.char) || 0;

  score += sameCharCount * 10;

  if (isJingChar(card.char)) score += 30;
  if (isYinChar(card.char)) score += 15;

  const group = CARD_GROUPS[getCardGroup(card.char)];
  const groupCount = group.filter(ch => hand.some(c => c.char === ch)).length;
  score += groupCount * 5;

  if (groupCount === 2) score += 20;
  if (groupCount === 3) score += 40;

  if (sameCharCount >= 2) score += 25;

  const testHand = hand.filter(c => c.id !== card.id);
  if (isTing(testHand, melds)) {
    score += 200;
  }

  return score;
}

/** 困难模式：完整听牌策略（匹配Flame的AIStrategyHard.selectDiscard） */
function selectDiscardHard(hand: Card[], melds: Meld[], ctx?: GameContext): Card {
  if (hand.length <= 1) return hand[0];

  // 匹配Flame: 每次selectDiscard调用前清除缓存
  clearAICaches();

  // 如果已经听牌
  if (isTing(hand, melds)) {
    return selectDiscardWhenTing(hand, melds, ctx);
  }

  return selectDiscardOptimized(hand, melds, ctx);
}

/** 听牌状态下选择出牌（匹配Flame的_selectDiscardWhenTing） */
function selectDiscardWhenTing(hand: Card[], melds: Meld[], ctx?: GameContext): Card {
  const charCount = buildCharCount(hand);
  const visibleCount = ctx?.visibleCount || new Map<string, number>();
  const totalUnknown = ctx?.totalUnknown || 96;

  let bestCard: Card | null = null;
  let bestTingCount = -1;
  let bestTingProb = -1;
  let bestHuScore = -1;

  for (const card of hand) {
    if (isPartOfKan(card, charCount)) continue;

    const testHand = hand.filter(c => c.id !== card.id);

    if (!isTing(testHand, melds)) continue;

    // 计算听牌进张数和进张概率（匹配Flame）
    const tingChars = getTingCards(testHand, melds);
    let tingCount = 0;
    let tingProb = 0;
    const seenChars = new Set<string>();
    for (const tc of tingChars) {
      if (seenChars.has(tc)) continue;
      seenChars.add(tc);
      const rem = remainingCount(tc, visibleCount);
      if (rem > 0) {
        tingCount += rem;
        tingProb += rem / totalUnknown;
      }
    }

    const huScore = evaluateHuScoreCached(testHand, melds);

    if (tingCount > bestTingCount ||
        (tingCount === bestTingCount && tingProb > bestTingProb) ||
        (tingCount === bestTingCount && tingProb === bestTingProb && huScore > bestHuScore)) {
      bestCard = card;
      bestTingCount = tingCount;
      bestTingProb = tingProb;
      bestHuScore = huScore;
    }
  }

  if (bestCard) return bestCard;

  // 没有听牌出牌时，选择安全的牌
  const tingChars = getTingCards(hand, melds);
  const safeCards = hand.filter(c => !tingChars.includes(c.char));
  if (safeCards.length > 0) {
    safeCards.sort((a, b) => discardPriority(b) - discardPriority(a));
    return safeCards[0];
  }

  // 兜底：出剩余最多的牌（匹配Flame，无ctx时也按剩余牌数排序）
  const scored = hand.map(card => {
    let score = 0;
    if (ctx) {
      const rem = remainingCount(card.char, ctx.visibleCount);
      score += rem * 10;
    }
    if (isJingChar(card.char)) score -= 100;
    else if (isYin(card)) score -= 20;
    return { card, score };
  });
  scored.sort((a, b) => b.score - a.score);
  return scored[0].card;
}

/** 出牌优先级（值越高越应该出） */
function discardPriority(card: Card): number {
  if (isJingChar(card.char)) return 0;
  if (isYin(card)) return 1;
  return 2;
}

/** 困难模式优化出牌（匹配Flame的_selectDiscardOptimized） */
function selectDiscardOptimized(hand: Card[], melds: Meld[], ctx?: GameContext): Card {
  if (hand.length <= 1) return hand[0];

  const visibleCount = ctx?.visibleCount || new Map<string, number>();
  const totalUnknown = ctx?.totalUnknown || 96;
  const isLate = ctx ? isLateGame(ctx.deckSize) : false;

  const shiDuiPotential = evaluateShiDuiPotential(hand, melds, visibleCount, totalUnknown);
  const availableChars = buildAvailableChars(visibleCount);
  const charCount = buildCharCount(hand);

  let bestTingCard: Card | null = null;
  let bestTingRem = -1;
  let bestTingProb = -1;
  let bestTingHu = -1;
  const scored: { card: Card; score: number }[] = [];

  for (const card of hand) {
    if (isPartOfZhao(card, charCount)) {
      scored.push({ card, score: -10000 });
      continue;
    }
    if (isPartOfKan(card, charCount)) {
      scored.push({ card, score: -5000 });
      continue;
    }

    const testHand = hand.filter(c => c.id !== card.id);
    const quickDist = distanceToTingCached(testHand, melds);

    if (quickDist <= 2) {
      if (isTing(testHand, melds)) {
        const tingChars = getTingCards(testHand, melds);
        let tingRem = 0;
        let tingProb = 0;
        const seenChars = new Set<string>();
        for (const tc of tingChars) {
          if (seenChars.has(tc)) continue;
          seenChars.add(tc);
          const rem = remainingCount(tc, visibleCount);
          if (rem > 0) {
            tingRem += rem;
            tingProb += rem / totalUnknown;
          }
        }
        const huScore = evaluateHuScoreCached(testHand, melds);

        if (tingRem > bestTingRem ||
            (tingRem === bestTingRem && tingProb > bestTingProb) ||
            (tingRem === bestTingRem && tingProb === bestTingProb && huScore > bestTingHu)) {
          bestTingCard = card;
          bestTingRem = tingRem;
          bestTingProb = tingProb;
          bestTingHu = huScore;
        }

        let tingScore = 10000 + tingProb * 2000;
        const effectiveTingCount = seenChars.size;
        tingScore += effectiveTingCount * 200;
        tingScore += huScore * 10;
        if (isLate) tingScore += 3000;
        scored.push({ card, score: tingScore });
        continue;
      }
    }

    // 综合评估（匹配Flame的_evaluateDiscardComprehensiveWithDist）
    let score: number;
    if (ctx) {
      score = evaluateDiscardComprehensiveWithDist(
        { ...ctx.players.find(p => p.id === ctx.currentPlayerId)!, hand, melds },
        card,
        testHand,
        quickDist,
        ctx,
        visibleCount,
        totalUnknown,
        isLate,
        shiDuiPotential,
        availableChars,
      );

      if (hand.length > 3) {
        score += twoStepLookahead(hand, melds, card, visibleCount, totalUnknown, availableChars);
      }
    } else {
      // 无ctx时使用简化评估
      const { potential, distance: distToTing } = evaluateHandPotentialAndDistanceSimple(testHand, melds);
      score = potential;
      if (isJingChar(card.char)) score -= 80;
      else if (isYin(card)) score -= 20;
      score += (10 - distToTing) * 120;
      if (distToTing <= 2) score += 800;
    }

    scored.push({ card, score });
  }

  if (bestTingCard) return bestTingCard;

  scored.sort((a, b) => b.score - a.score);
  return scored[0].card;
}

/** 简化版手牌评估（无可见牌信息时使用） */
function evaluateHandPotentialAndDistanceSimple(
  hand: Card[],
  melds: Meld[],
): { potential: number; distance: number } {
  const remaining = [...hand];
  const aSet: InternalMeld[] = [];
  const bSet: InternalMeld[] = [];
  const cSet: InternalMeld[] = [];
  const dSet: InternalMeld[] = [];
  const eSet: Card[] = [];

  extractJu(remaining, aSet);
  extractZhao(remaining, bSet);
  extractKan(remaining, cSet);
  extractDuiAndKao(remaining, dSet);
  eSet.push(...remaining);

  let totalMelds = aSet.length + bSet.length + cSet.length;
  for (const m of melds) {
    if (m.type === 'ju' || m.type === 'kan' || m.type === 'zhao') {
      totalMelds++;
    }
  }

  let neededMelds = 6 - totalMelds;
  if (neededMelds < 0) neededMelds = 0;

  let usefulDuiKao = 0;
  for (const meld of dSet) {
    if (meld.type === 'kao' || meld.type === 'dui') {
      usefulDuiKao++;
    }
  }

  let distance = neededMelds * 2 - usefulDuiKao;
  if (distance < 0) distance = 0;
  if (distance > 10) distance = 10;

  const pairCount = countHandPairs(hand);
  if (pairCount >= 9) {
    return { potential: 500, distance };
  }

  let score = 0;
  score += aSet.length * 100.0;
  score += bSet.length * 150.0;
  score += cSet.length * 120.0;

  for (const meld of aSet) {
    if (meld.isJing) score += 20;
  }
  for (const meld of bSet) {
    if (meld.isJing) score += 30;
  }
  for (const meld of cSet) {
    if (meld.isJing) score += 25;
  }

  for (const meld of dSet) {
    if (meld.type === 'dui') {
      const ch = meld.cards[0].char;
      const inJu = aSet.some(m => m.cards.some(c => c.char === ch));
      if (inJu) score += 40;
      else score += 30;
      if (meld.isJing) score += 20;
    } else if (meld.type === 'kao') {
      const chars = meld.cards.map(c => c.char);
      const missingChar = findMissingCharForSentence(chars);
      if (missingChar) score += 50;
      else score += 60;
      if (meld.isJing) score += 15;
    }
  }

  for (const card of eSet) {
    const sameGroup = hand.filter(c => c.sentence === card.sentence);
    const groupCharSet = new Set(sameGroup.map(c => c.char));
    if (groupCharSet.size >= 2) {
      score += 30;
      if (groupCharSet.size >= 3) score += 50;
    } else {
      score -= 20;
    }
    if (isJingChar(card.char)) score += 20;
    else if (isYin(card)) score += 3;
  }

  if (dSet.length === 0 && eSet.length === 1) score += 150;
  else if (dSet.length === 2 && eSet.length === 0) score += 130;

  score += (10 - distance) * 30;

  return { potential: score, distance };
}

// ============================================================
// AI操作决策
// ============================================================

/**
 * AI决定执行哪个操作
 */
export function aiDecideAction(
  actions: string[],
  hand: Card[],
  melds: Meld[],
  difficulty: string,
): string | null {
  if (actions.length === 0) return null;

  if (actions.includes('zimo')) return 'zimo';
  if (actions.includes('hu')) return 'hu';

  if (difficulty === 'easy') {
    return decideActionEasy(actions);
  }

  if (difficulty === 'medium') {
    return decideActionMedium(actions, hand, melds);
  }

  return decideActionHard(actions, hand, melds);
}

/** 简单模式操作决策 */
function decideActionEasy(actions: string[]): string | null {
  if (actions.includes('zhao')) return 'zhao';
  if (actions.includes('peng')) {
    return Math.random() > 0.5 ? 'peng' : null;
  }
  if (actions.includes('chi')) {
    return Math.random() > 0.5 ? 'chi' : null;
  }
  return null;
}

/** 中等模式操作决策 */
function decideActionMedium(actions: string[], _hand: Card[], _melds: Meld[]): string | null {
  if (actions.includes('zhao')) return 'zhao';
  if (actions.includes('peng')) return 'peng';
  if (actions.includes('chi')) return 'chi';
  return null;
}

/** 困难模式操作决策（匹配Flame的shouldChi/shouldPeng/shouldZhao） */
function decideActionHard(actions: string[], _hand: Card[], _melds: Meld[]): string | null {
  if (actions.includes('zhao')) return 'zhao';
  if (actions.includes('peng')) return 'peng';
  if (actions.includes('chi')) return 'chi';
  return null;
}

// ============================================================
// AI吃碰招决策（匹配Flame的shouldChi/shouldPeng/shouldZhao）
// ============================================================

/** AI决定是否吃牌（匹配Flame的shouldChi三级判断） */
export function aiDecideChi(
  player: Player,
  discardedCard: Card,
  difficulty: string,
  ctx?: GameContext,
): boolean {
  if (!aiCanChi(player.hand, player.melds, discardedCard.char, difficulty)) {
    return false;
  }

  // 手牌中已有出牌的同字（自己持有该字）：由于能吃说明手牌已含同句另两字，
  // 故手牌可独立成句。此时吃牌只会把另两字移入组合牌，并使手牌中这张同字
  // 沦为废单（甚至破坏既有对/句结构），属于规则14的广义情形，不吃。
  if (player.hand.some(c => c.char === discardedCard.char)) {
    return false;
  }

  // 困难模式：评估吃牌收益（匹配Flame的shouldChi）
  if (difficulty === 'hard') {
    const benefit = evaluateChiBenefit(player, discardedCard, ctx);
    if (benefit < 0) return false;
    if (player.isTing) return benefit >= 10000;
    return benefit > 0;
  }

  // 中等模式：吃牌后检查听牌
  if (difficulty === 'medium') {
    const sentence = CHAR_SENTENCE_MAP[discardedCard.char];
    if (!sentence) return false;
    const group = GROUP_CHARS[sentence - 1];
    const otherChars = group.filter(ch => ch !== discardedCard.char);

    const testHand = [...player.hand];
    for (const ch of otherChars) {
      const idx = testHand.findIndex(c => c.char === ch);
      if (idx >= 0) testHand.splice(idx, 1);
    }

    const newMeld: Meld = {
      type: 'ju',
      cards: [discardedCard, ...otherChars.map(ch => player.hand.find(c => c.char === ch)!)],
      isJing: isJingChar(discardedCard.char),
    };

    if (isTing(testHand, [...player.melds, newMeld])) return true;

    const distBefore = distanceToTingCached(player.hand, player.melds);
    const distAfter = distanceToTingCached(testHand, [...player.melds, newMeld]);
    return distAfter <= distBefore;
  }

  // 简单模式：50%概率吃
  return Math.random() > 0.5;
}

/** 评估吃牌收益（困难模式，匹配Flame的_evaluateChiBenefit，返回数值分数） */
function evaluateChiBenefit(player: Player, discardedCard: Card, ctx?: GameContext): number {
  const hand = player.hand;
  const sentence = CHAR_SENTENCE_MAP[discardedCard.char];
  if (!sentence) return -1;
  const group = GROUP_CHARS[sentence - 1];
  const neededChars = group.filter(ch => ch !== discardedCard.char);

  const hasAll = neededChars.every(ch => hand.some(c => c.char === ch));
  if (!hasAll) return -1;

  if (hasCompleteSentenceWithSingleCards(hand, discardedCard.char)) {
    return -1;
  }

  const visibleCount = ctx?.visibleCount || new Map<string, number>();
  const totalUnknown = ctx?.totalUnknown || 96;

  // 评估吃牌前被消耗的牌在其他组合中的价值（匹配Flame）
  let consumptionCost = 0;
  for (const ch of neededChars) {
    const sameGroupInHand = hand.filter(c => c.sentence === CHAR_SENTENCE_MAP[ch] && c.char !== ch);
    if (sameGroupInHand.length > 0) {
      consumptionCost += 30;
    }
    const chCount = hand.filter(c => c.char === ch).length;
    if (chCount >= 2) {
      consumptionCost -= 20;
    }
  }

  const testHand = [...hand];
  for (const ch of neededChars) {
    const idx = testHand.findIndex(c => c.char === ch);
    if (idx >= 0) testHand.splice(idx, 1);
  }

  const newMeld: Meld = {
    type: 'ju',
    cards: [discardedCard, ...neededChars.map(ch => hand.find(c => c.char === ch)!)],
    isJing: isJingChar(discardedCard.char),
  };

  const newMelds = [...player.melds, newMeld];

  // 吃牌后听牌，极大收益（匹配Flame: benefit >= 10000）
  if (isTing(testHand, newMelds)) return 10000;

  // 已听牌时，只有吃后仍听牌才吃
  if (player.isTing) {
    return isTing(testHand, newMelds) ? 10000 : -1;
  }

  const distBefore = distanceToTingCached([...hand], player.melds);
  const { bestHand, bestDist: distAfterDiscard } = findBestDiscardAfterMeld(testHand, newMelds);

  if (distAfterDiscard > distBefore) return -1;

  let benefit = (distBefore - distAfterDiscard) * 300.0;

  if (distAfterDiscard === distBefore) {
    benefit += 100;
  }

  if (distAfterDiscard <= 2) benefit += 800;
  if (distAfterDiscard <= 4) benefit += 300;

  benefit += evaluateHuScoreCached(bestHand, newMelds) * 4;

  // 进张概率评估（匹配Flame）
  let chiAfterProb = 0;
  for (const c of bestHand) {
    const rem = remainingCount(c.char, visibleCount);
    if (rem > 0) chiAfterProb += rem / totalUnknown;
  }
  benefit += chiAfterProb * 80;

  let chiBeforeProb = 0;
  for (const c of hand) {
    const rem = remainingCount(c.char, visibleCount);
    if (rem > 0) chiBeforeProb += rem / totalUnknown;
  }
  const probLoss = chiBeforeProb - chiAfterProb;
  benefit -= probLoss * 50;

  benefit -= consumptionCost;

  return benefit;
}

/** AI决定是否碰牌（匹配Flame的shouldPeng） */
export function aiDecidePeng(
  player: Player,
  discardedCard: Card,
  _difficulty: string,
  _ctx?: GameContext,
): boolean {
  if (!aiCanPeng(player.hand, player.melds, discardedCard.char)) {
    return false;
  }

  const sameCharCount = player.hand.filter(c => c.char === discardedCard.char).length;

  if (sameCharCount >= 2) {
    const testHand = [...player.hand];
    const matching = testHand.filter(c => c.char === discardedCard.char).slice(0, 2);
    for (const m of matching) {
      const idx = testHand.indexOf(m);
      if (idx >= 0) testHand.splice(idx, 1);
    }

    const newMeld: Meld = {
      type: 'kan',
      cards: [discardedCard, ...matching],
      isJing: isJingChar(discardedCard.char),
    };

    const newMelds = [...player.melds, newMeld];

    if (isTing(testHand, newMelds)) return true;
    if (player.isTing && !isTing(testHand, newMelds)) return false;

    const distBefore = distanceToTingCached([...player.hand], player.melds);
    const { bestDist: distAfterDiscard } = findBestDiscardAfterMeld(testHand, newMelds);

    if (distAfterDiscard > distBefore) return false;
    if (distAfterDiscard < distBefore) return true;

    // 距离不变时，评估碰牌后手牌质量和进张损失（匹配Flame）
    const huScoreAfter = evaluateHuScoreCached(testHand, newMelds);
    if (huScoreAfter > 0) return true;

    // 匹配 Flame: 评估碰牌前的进张（该字参与的其他组合价值）
    const charInHand = player.hand.filter(c => c.char === discardedCard.char).length;
    if (charInHand >= 2) {
      // 手牌有2张同字，碰掉后少了1张可用的牌
      // 检查该字同组的其他字在手牌中是否有
      const otherChars = GROUP_CHARS[discardedCard.sentence - 1].filter(ch => ch !== discardedCard.char);
      const hasPartner = otherChars.some(ch => player.hand.some(c => c.char === ch));
      // 有同组伙伴时，如果碰牌后胡数更高，仍然碰
      if (hasPartner) {
        const huScoreBefore = evaluateHuScoreCached(player.hand, player.melds);
        if (huScoreAfter > huScoreBefore) return true;
        // 否则保留灵活性，不碰
        return false;
      }
      // 无同组伙伴时，该字的对子无法参与成句，碰掉变坎更优
      return true;
    }

    // 碰牌增加面子，更倾向碰
    return true;
  }

  // sameCharCount == 1: 只有一张同字牌
  if (sameCharCount === 1) {
    const existingCard = player.hand.find(c => c.char === discardedCard.char);

    // 检查该字是否参与已有的句/靠组合
    const remaining = [...player.hand];
    const aSet: InternalMeld[] = [];
    const bSet: InternalMeld[] = [];
    const cSet: InternalMeld[] = [];
    const dSet: InternalMeld[] = [];
    extractJu(remaining, aSet);
    extractZhao(remaining, bSet);
    extractKan(remaining, cSet);
    extractDuiAndKao(remaining, dSet);

    const inJu = aSet.some(m => m.cards.some(c => c.char === discardedCard.char));
    const inKao = dSet.some(m =>
      m.type === 'kao' && m.cards.some(c => c.char === discardedCard.char),
    );
    if (inJu || inKao) return false;

    const testHand = player.hand.filter(c => c.char !== discardedCard.char);

    const newMeld: Meld = {
      type: 'kan',
      cards: [discardedCard, existingCard!, existingCard!],
      isJing: isJingChar(discardedCard.char),
    };

    if (isTing(testHand, [...player.melds, newMeld])) return true;

    const distBefore = distanceToTingCached([...player.hand], player.melds);
    const distAfter = distanceToTingCached(testHand, [...player.melds, newMeld]);
    return distAfter <= distBefore;
  }

  return false;
}

/** AI决定是否招牌（匹配Flame的shouldZhao/_evaluateZhaoBenefit） */
export function aiDecideZhao(
  player: Player,
  discardedCard: Card,
  _difficulty: string,
  _ctx?: GameContext,
): boolean {
  if (!aiCanZhao(player.hand, player.melds, discardedCard.char)) {
    return false;
  }

  return evaluateZhaoBenefit(player, discardedCard.char);
}

/** AI决定是否招手牌中的4张同字（自招） */
export function aiDecideZhaoFromHand(
  player: Player,
  character: string,
  _difficulty: string,
  _ctx?: GameContext,
): boolean {
  const hand = player.hand;
  const sameCharCount = hand.filter(c => c.char === character).length;

  // 检查是否已有坎可以升级为招
  if (sameCharCount < 4) {
    const existingKan = player.melds.find(
      m => m.type === 'kan' && m.cards[0].char === character,
    );
    if (existingKan) return true;
    return false;
  }

  const totalCount = getTotalCardCount(hand, player.melds);
  if (totalCount !== 20) return false;

  return evaluateZhaoBenefit(player, character);
}

/** 评估招的收益（匹配Flame的_evaluateZhaoBenefit） */
function evaluateZhaoBenefit(player: Player, character: string): boolean {
  const hand = player.hand;
  const sameCharCount = hand.filter(c => c.char === character).length;

  if (sameCharCount < 3) {
    const existingKan = player.melds.find(
      m => m.type === 'kan' && m.cards[0].char === character,
    );
    if (existingKan) return true;
    return false;
  }

  if (sameCharCount >= 4) {
    const testHand = [...hand];
    const zhaoCards = testHand.filter(c => c.char === character).slice(0, 4);
    for (const c of zhaoCards) {
      const idx = testHand.indexOf(c);
      if (idx >= 0) testHand.splice(idx, 1);
    }

    const newMeld: Meld = {
      type: 'zhao',
      cards: zhaoCards,
      isJing: isJingChar(zhaoCards[0].char),
    };

    const newMelds = [...player.melds, newMeld];

    if (isTing(testHand, newMelds)) return true;
    if (player.isTing && !isTing(testHand, newMelds)) return false;

    const distBefore = distanceToTingCached([...hand], player.melds);
    const distAfter = distanceToTingCached(testHand, newMelds);

    if (distAfter > distBefore + 1) return false;

    // 比较招vs坎的收益（匹配Flame）
    const kanHand = [...hand];
    const kanCards = kanHand.filter(c => c.char === character).slice(0, 3);
    for (const c of kanCards) {
      const idx = kanHand.indexOf(c);
      if (idx >= 0) kanHand.splice(idx, 1);
    }
    const kanMeld: Meld = {
      type: 'kan',
      cards: kanCards,
      isJing: isJingChar(kanCards[0].char),
    };

    const huZhao = evaluateHuScoreCached(testHand, newMelds);
    const huKan = evaluateHuScoreCached(kanHand, [...player.melds, kanMeld]);
    const distKan = distanceToTingCached(kanHand, [...player.melds, kanMeld]);

    if (huZhao >= huKan && distAfter <= distKan) return true;
    if (huZhao > huKan + 4) return true;
    if (distAfter < distKan) return true;

    return distAfter <= distBefore;
  }

  return true;
}

/** AI决定是否胡牌（总是胡） */
export function aiDecideHu(_player: Player, _discardedCard: Card, _difficulty: string): boolean {
  return true;
}
