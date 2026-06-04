import { Card, CardChar, CARD_GROUPS, getCardGroup, isJingChar, isYinChar } from '../types/card';
import { Player, Meld, MeldType } from '../types/player';
import { canHu, canZimo, calculateTotalHu } from './huCalculator';
import { isTing, getTingCards } from './tingChecker';

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

/** 评估手牌潜力和距离 */
function evaluateHandPotentialAndDistance(
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

  // 评估对和靠
  for (const meld of dSet) {
    if (meld.type === 'dui') {
      const ch = meld.cards[0].char;
      const inJu = aSet.some(m => m.cards.some(c => c.char === ch));
      if (inJu) {
        score += 40;
      } else {
        score += 30;
      }
      if (meld.isJing) score += 20;
    } else if (meld.type === 'kao') {
      const chars = meld.cards.map(c => c.char);
      const missingChar = findMissingCharForSentence(chars);
      if (missingChar) {
        score += 50;
      } else {
        score += 60;
      }
      if (meld.isJing) score += 15;
    }
  }

  // 评估孤张牌
  for (const card of eSet) {
    const sameGroup = hand.filter(c => c.sentence === card.sentence);
    const groupCharSet = new Set(sameGroup.map(c => c.char));

    if (groupCharSet.size >= 2) {
      score += 30;
      if (groupCharSet.size >= 3) {
        score += 50;
      }
    } else {
      score -= 20;
    }

    if (isJingChar(card.char)) {
      score += 20;
    } else if (isYin(card)) {
      score += 3;
    }
  }

  // 基本听牌条件b.1/b.2加分
  if (dSet.length === 0 && eSet.length === 1) {
    score += 150;
  } else if (dSet.length === 2 && eSet.length === 0) {
    score += 130;
  }

  score += (10 - distance) * 30;

  return { potential: score, distance };
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
 * @param hand 手牌
 * @param melds 组合牌
 * @param discardedChar 被出的牌的字（别人出的牌）；如果为空则检查手牌自招
 */
export function aiCanZhao(hand: Card[], melds: Meld[], discardedChar: CardChar): boolean {
  const totalCount = getTotalCardCount(hand, melds);

  if (discardedChar) {
    // 招别人出的牌：手牌需要有3张同字 + 出的牌
    const sameCount = hand.filter(c => c.char === discardedChar).length;
    if (sameCount < 3) return false;

    // 19张牌时可以招别人出的牌：19+1-4+3=19，补摸一张变20
    if (totalCount === 19) return true;
    // 20张牌时不能招别人出的牌
    return false;
  }

  return false;
}

/**
 * 检查AI玩家是否可以碰（3-of-a-kind）
 * @param hand 手牌
 * @param melds 组合牌
 * @param discardedChar 被出的牌的字
 */
export function aiCanPeng(hand: Card[], melds: Meld[], discardedChar: CardChar): boolean {
  const totalCount = getTotalCardCount(hand, melds);

  // 20张牌时不能碰
  if (totalCount === 20) return false;

  const sameCount = hand.filter(c => c.char === discardedChar).length;
  return sameCount >= 2;
}

/**
 * 检查AI玩家是否可以吃（sentence meld）
 * @param hand 手牌
 * @param melds 组合牌
 * @param discardedChar 被出的牌的字
 * @param difficulty 难度
 */
export function aiCanChi(hand: Card[], melds: Meld[], discardedChar: CardChar, difficulty: string): boolean {
  const totalCount = getTotalCardCount(hand, melds);

  // 20张牌时不能吃
  if (totalCount === 20) return false;

  const sentence = CHAR_SENTENCE_MAP[discardedChar];
  if (!sentence) return false;
  const group = GROUP_CHARS[sentence - 1];
  const otherChars = group.filter(ch => ch !== discardedChar);

  // 检查手牌中是否有同组其他牌
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
 * @param hand 手牌
 * @param melds 组合牌
 * @param difficulty 难度：easy/medium/hard
 */
export function aiDecideDiscard(hand: Card[], melds: Meld[], difficulty: string): Card {
  if (hand.length === 0) return hand[0];
  if (hand.length <= 1) return hand[0];

  if (difficulty === 'easy') {
    return selectDiscardEasy(hand, melds);
  } else if (difficulty === 'medium') {
    return selectDiscardMedium(hand, melds);
  } else {
    return selectDiscardHard(hand, melds);
  }
}

/** 简单模式：随机出牌 */
function selectDiscardEasy(hand: Card[], _melds: Meld[]): Card {
  // 优先出单张（非精非银），否则随机
  const singles = hand.filter(c => {
    const sameCount = hand.filter(h => h.char === c.char).length;
    return sameCount === 1 && !isJingChar(c.char) && !isYin(c);
  });

  if (singles.length > 0) {
    return singles[Math.floor(Math.random() * singles.length)];
  }

  // 随机出非精牌
  const nonJing = hand.filter(c => !isJingChar(c.char));
  if (nonJing.length > 0) {
    return nonJing[Math.floor(Math.random() * nonJing.length)];
  }

  return hand[Math.floor(Math.random() * hand.length)];
}

/** 中等模式：基础听牌感知 */
function selectDiscardMedium(hand: Card[], melds: Meld[]): Card {
  // 如果已经听牌，选择听牌后不影响听牌的牌出
  if (isTing(hand, melds)) {
    return selectDiscardWhenTing(hand, melds);
  }

  // 按价值排序出牌
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

  // 同字数量越多越有价值
  score += sameCharCount * 10;

  // 精字价值高
  if (isJingChar(card.char)) score += 30;

  // 银字价值中等
  if (isYinChar(card.char)) score += 15;

  // 同组牌数量
  const group = CARD_GROUPS[getCardGroup(card.char)];
  const groupCount = group.filter(ch => hand.some(c => c.char === ch)).length;
  score += groupCount * 5;

  // 接近成句的牌价值更高
  if (groupCount === 2) score += 20;
  if (groupCount === 3) score += 40;

  // 已听牌的牌不轻易出
  if (sameCharCount >= 2) score += 25;

  // 检查出牌后是否还能听牌
  const testHand = hand.filter(c => c.id !== card.id);
  if (isTing(testHand, melds)) {
    score += 200;
  }

  return score;
}

/** 困难模式：完整听牌策略 */
function selectDiscardHard(hand: Card[], melds: Meld[]): Card {
  if (hand.length <= 1) return hand[0];

  const charCount = buildCharCount(hand);

  // 如果已经听牌
  if (isTing(hand, melds)) {
    return selectDiscardWhenTing(hand, melds);
  }

  return selectDiscardOptimized(hand, melds, charCount);
}

/** 听牌状态下选择出牌（匹配Flame的_selectDiscardWhenTing） */
function selectDiscardWhenTing(hand: Card[], melds: Meld[]): Card {
  const charCount = buildCharCount(hand);

  let bestCard: Card | null = null;
  let bestTingCount = -1;
  let bestTingProb = -1;
  let bestHuScore = -1;

  for (const card of hand) {
    // 坎中的牌不出
    if (isPartOfKan(card, charCount)) continue;

    const testHand = hand.filter(c => c.id !== card.id);

    // 检查出牌后是否仍然听牌
    if (!isTing(testHand, melds)) continue;

    // 计算听牌进张数
    const tingChars = getTingCards(testHand, melds);
    let tingCount = tingChars.length;
    let tingProb = tingChars.length / 24; // 简化概率计算

    const huScore = calculateTotalHu(testHand, melds);

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

  // 兜底
  return hand[0];
}

/** 出牌优先级（值越高越应该出） */
function discardPriority(card: Card): number {
  if (isJingChar(card.char)) return 0;
  if (isYin(card)) return 1;
  return 2;
}

/** 困难模式优化出牌（匹配Flame的_selectDiscardOptimized） */
function selectDiscardOptimized(hand: Card[], melds: Meld[], charCount: Map<string, number>): Card {
  if (hand.length <= 1) return hand[0];

  let bestTingCard: Card | null = null;
  let bestTingRem = -1;
  let bestTingProb = -1;
  let bestTingHu = -1;
  const scored: { card: Card; score: number }[] = [];

  for (const card of hand) {
    // 招中的牌不出
    if (isPartOfZhao(card, charCount)) {
      scored.push({ card, score: -10000 });
      continue;
    }
    // 坎中的牌不出
    if (isPartOfKan(card, charCount)) {
      scored.push({ card, score: -5000 });
      continue;
    }

    const testHand = hand.filter(c => c.id !== card.id);
    const quickDist = distanceToTing(testHand, melds);

    if (quickDist <= 2) {
      if (isTing(testHand, melds)) {
        const tingChars = getTingCards(testHand, melds);
        const tingRem = tingChars.length;
        const tingProb = tingChars.length / 24;
        const huScore = calculateTotalHu(testHand, melds);

        if (tingRem > bestTingRem ||
            (tingRem === bestTingRem && tingProb > bestTingProb) ||
            (tingRem === bestTingRem && tingProb === bestTingProb && huScore > bestTingHu)) {
          bestTingCard = card;
          bestTingRem = tingRem;
          bestTingProb = tingProb;
          bestTingHu = huScore;
        }

        let tingScore = 10000 + tingProb * 2000;
        tingScore += tingRem * 200;
        tingScore += huScore * 10;
        scored.push({ card, score: tingScore });
        continue;
      }
    }

    // 综合评估
    const { potential, distance: distToTing } = evaluateHandPotentialAndDistance(testHand, melds);
    let score = potential;

    if (isJingChar(card.char)) {
      score -= 80;
    } else if (isYin(card)) {
      score -= 20;
    }

    score += (10 - distToTing) * 120;

    if (distToTing <= 2) {
      score += 800;
    }

    scored.push({ card, score });
  }

  if (bestTingCard) return bestTingCard;

  scored.sort((a, b) => b.score - a.score);
  return scored[0].card;
}

// ============================================================
// AI操作决策
// ============================================================

/**
 * AI决定执行哪个操作
 * @param actions 可用操作列表
 * @param hand 手牌
 * @param melds 组合牌
 * @param difficulty 难度
 * @returns 选择的操作，null表示过
 */
export function aiDecideAction(
  actions: string[],
  hand: Card[],
  melds: Meld[],
  difficulty: string,
): string | null {
  if (actions.length === 0) return null;

  // 优先级：zimo > hu > zhao > peng > chi
  // 自摸和胡永远执行
  if (actions.includes('zimo')) return 'zimo';
  if (actions.includes('hu')) return 'hu';

  // 简单模式：随机决策
  if (difficulty === 'easy') {
    return decideActionEasy(actions);
  }

  // 中等模式：基础策略
  if (difficulty === 'medium') {
    return decideActionMedium(actions, hand, melds);
  }

  // 困难模式：完整策略
  return decideActionHard(actions, hand, melds);
}

/** 简单模式操作决策 */
function decideActionEasy(actions: string[]): string | null {
  // 招牌总是执行
  if (actions.includes('zhao')) return 'zhao';
  // 碰牌50%概率
  if (actions.includes('peng')) {
    return Math.random() > 0.5 ? 'peng' : null;
  }
  // 吃牌50%概率
  if (actions.includes('chi')) {
    return Math.random() > 0.5 ? 'chi' : null;
  }
  return null;
}

/** 中等模式操作决策 */
function decideActionMedium(actions: string[], _hand: Card[], _melds: Meld[]): string | null {
  // 招牌总是执行
  if (actions.includes('zhao')) return 'zhao';

  // 碰牌：检查碰后是否仍然听牌或更好
  if (actions.includes('peng')) {
    return 'peng';
  }

  // 吃牌：检查吃后是否仍然听牌或更好
  if (actions.includes('chi')) {
    return 'chi';
  }

  return null;
}

/** 困难模式操作决策 */
function decideActionHard(actions: string[], _hand: Card[], _melds: Meld[]): string | null {
  // 招牌：评估招后是否仍然听牌或更好
  if (actions.includes('zhao')) {
    // 招牌通常有利，但需要检查
    return 'zhao';
  }

  // 碰牌：评估碰后听牌距离
  if (actions.includes('peng')) {
    return 'peng';
  }

  // 吃牌：评估吃后听牌距离
  if (actions.includes('chi')) {
    return 'chi';
  }

  return null;
}

// ============================================================
// AI吃碰招决策（兼容旧接口）
// ============================================================

/** AI决定是否吃牌 */
export function aiDecideChi(
  player: Player,
  discardedCard: Card,
  difficulty: string,
): boolean {
  if (!aiCanChi(player.hand, player.melds, discardedCard.char, difficulty)) {
    return false;
  }

  // 困难模式：评估吃牌收益
  if (difficulty === 'hard') {
    return evaluateChiBenefit(player, discardedCard);
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

    // 吃牌后听牌，极大收益
    if (isTing(testHand, [...player.melds, newMeld])) return true;

    // 吃牌后距离更近
    const distBefore = distanceToTing(player.hand, player.melds);
    const distAfter = distanceToTing(testHand, [...player.melds, newMeld]);
    return distAfter <= distBefore;
  }

  // 简单模式：50%概率吃
  return Math.random() > 0.5;
}

/** 评估吃牌收益（困难模式） */
function evaluateChiBenefit(player: Player, discardedCard: Card): boolean {
  const hand = player.hand;
  const sentence = CHAR_SENTENCE_MAP[discardedCard.char];
  if (!sentence) return false;
  const group = GROUP_CHARS[sentence - 1];
  const neededChars = group.filter(ch => ch !== discardedCard.char);

  const hasAll = neededChars.every(ch => hand.some(c => c.char === ch));
  if (!hasAll) return false;

  // 检查完整句单张规则
  if (hasCompleteSentenceWithSingleCards(hand, discardedCard.char)) {
    return false;
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

  // 吃牌后听牌，极大收益
  if (isTing(testHand, newMelds)) return true;

  // 已听牌时，只有吃后仍听牌才吃
  if (player.isTing) {
    return isTing(testHand, newMelds);
  }

  // 评估吃牌前后的听牌距离
  const distBefore = distanceToTing(hand, player.melds);
  const distAfter = distanceToTing(testHand, newMelds);

  if (distAfter > distBefore) return false;
  if (distAfter < distBefore) return true;

  // 距离不变时，评估胡数
  const huScoreAfter = calculateTotalHu(testHand, newMelds);
  return huScoreAfter > 0;
}

/** AI决定是否碰牌 */
export function aiDecidePeng(
  player: Player,
  discardedCard: Card,
  difficulty: string,
): boolean {
  if (!aiCanPeng(player.hand, player.melds, discardedCard.char)) {
    return false;
  }

  const sameCharCount = player.hand.filter(c => c.char === discardedCard.char).length;
  if (sameCharCount < 2) return false;

  // 模拟碰牌
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

  // 碰牌后听牌，极大收益
  if (isTing(testHand, newMelds)) return true;

  // 已听牌时，只有碰后仍听牌才碰
  if (player.isTing) {
    if (!isTing(testHand, newMelds)) return false;
  }

  if (difficulty === 'easy') {
    return Math.random() > 0.5;
  }

  // 中等/困难模式：评估碰牌前后的听牌距离
  const distBefore = distanceToTing(player.hand, player.melds);
  const distAfter = distanceToTing(testHand, newMelds);

  if (distAfter > distBefore) return false;
  if (distAfter < distBefore) return true;

  // 距离不变时，评估胡数
  const huScoreAfter = calculateTotalHu(testHand, newMelds);
  if (huScoreAfter > 0) return true;

  // 检查该字是否参与了句/靠组合
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

  return testHand.length <= 10;
}

/** AI决定是否招牌 */
export function aiDecideZhao(
  player: Player,
  discardedCard: Card,
  difficulty: string,
): boolean {
  if (!aiCanZhao(player.hand, player.melds, discardedCard.char)) {
    return false;
  }

  // 模拟招后
  const testHand = [...player.hand];
  const zhaoCards = testHand.filter(c => c.char === discardedCard.char).slice(0, 3);
  for (const c of zhaoCards) {
    const idx = testHand.indexOf(c);
    if (idx >= 0) testHand.splice(idx, 1);
  }

  const newMeld: Meld = {
    type: 'zhao',
    cards: [discardedCard, ...zhaoCards],
    isJing: isJingChar(discardedCard.char),
  };

  const newMelds = [...player.melds, newMeld];

  // 招后听牌
  if (isTing(testHand, newMelds)) return true;

  // 已听牌时，只有招后仍听牌才招
  if (player.isTing) {
    if (!isTing(testHand, newMelds)) return false;
  }

  if (difficulty === 'easy') {
    return true;
  }

  // 中等/困难模式：评估招牌前后的听牌距离
  const distBefore = distanceToTing(player.hand, player.melds);
  const distAfter = distanceToTing(testHand, newMelds);

  if (distAfter > distBefore + 1) return false;

  // 比较招vs坎的收益
  const kanHand = [...player.hand];
  const kanCards = kanHand.filter(c => c.char === discardedCard.char).slice(0, 2);
  for (const c of kanCards) {
    const idx = kanHand.indexOf(c);
    if (idx >= 0) kanHand.splice(idx, 1);
  }
  const kanMeld: Meld = {
    type: 'kan',
    cards: [discardedCard, ...kanCards],
    isJing: isJingChar(discardedCard.char),
  };

  const huZhao = calculateTotalHu(testHand, newMelds);
  const huKan = calculateTotalHu(kanHand, [...player.melds, kanMeld]);
  const distKan = distanceToTing(kanHand, [...player.melds, kanMeld]);

  if (huZhao >= huKan && distAfter <= distKan) return true;
  if (huZhao > huKan + 4) return true;
  if (distAfter < distKan) return true;

  return distAfter <= distBefore;
}

/** AI决定是否招手牌中的4张同字（自招） */
export function aiDecideZhaoFromHand(
  player: Player,
  character: string,
  difficulty: string,
): boolean {
  const hand = player.hand;
  const sameCharCount = hand.filter(c => c.char === character).length;

  // 手牌中必须有4张同字才能自招
  if (sameCharCount < 4) {
    // 检查是否已有坎可以升级为招
    const existingKan = player.melds.find(
      m => m.type === 'kan' && m.cards[0].char === character,
    );
    if (existingKan) return true;
    return false;
  }

  const totalCount = getTotalCardCount(hand, player.melds);

  // 20张牌时可以招自己手牌上的4张同字牌
  // 招完后手牌-4+组合牌+3=19，补摸一张牌变20
  if (totalCount !== 20) return false;

  // 模拟招后
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

  // 招后听牌
  if (isTing(testHand, newMelds)) return true;

  // 已听牌时，只有招后仍听牌才招
  if (player.isTing) {
    if (!isTing(testHand, newMelds)) return false;
  }

  if (difficulty === 'easy') {
    return true;
  }

  // 评估招vs坎的收益
  const distBefore = distanceToTing(hand, player.melds);
  const distAfter = distanceToTing(testHand, newMelds);

  if (distAfter > distBefore + 1) return false;

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

  const huZhao = calculateTotalHu(testHand, newMelds);
  const huKan = calculateTotalHu(kanHand, [...player.melds, kanMeld]);
  const distKan = distanceToTing(kanHand, [...player.melds, kanMeld]);

  if (huZhao >= huKan && distAfter <= distKan) return true;
  if (huZhao > huKan + 4) return true;
  if (distAfter < distKan) return true;

  return distAfter <= distBefore;
}

/** AI决定是否胡牌（总是胡） */
export function aiDecideHu(_player: Player, _discardedCard: Card, _difficulty: string): boolean {
  return true;
}
