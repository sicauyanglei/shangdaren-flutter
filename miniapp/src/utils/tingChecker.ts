import { Card, CardChar, isJingChar } from '../types/card';
import { Meld, MeldType } from '../types/player';

// ============================================================
// 字符到sentence/position映射（匹配Flame版本）
// ============================================================

const CHAR_TO_SENTENCE: Record<string, number> = {
  '上': 1, '大': 1, '人': 1,
  '丘': 2, '乙': 2, '己': 2,
  '化': 3, '三': 3, '千': 3,
  '七': 4, '十': 4, '土': 4,
  '尔': 5, '小': 5, '生': 5,
  '八': 6, '九': 6, '子': 6,
  '佳': 7, '作': 7, '亡': 7,
  '福': 8, '禄': 8, '寿': 8,
};

const CHAR_TO_POSITION: Record<string, number> = {
  '上': 0, '大': 1, '人': 2,
  '丘': 0, '乙': 1, '己': 2,
  '化': 0, '三': 1, '千': 2,
  '七': 0, '十': 1, '土': 2,
  '尔': 0, '小': 1, '生': 2,
  '八': 0, '九': 1, '子': 2,
  '佳': 0, '作': 1, '亡': 2,
  '福': 0, '禄': 1, '寿': 2,
};

const ALL_CHARS: CardChar[] = [
  '上', '大', '人', '丘', '乙', '己', '化', '三', '千',
  '七', '十', '土', '尔', '小', '生', '八', '九', '子',
  '佳', '作', '亡', '福', '禄', '寿',
];

const SENTENCE_CHARS: string[][] = [
  ['上', '大', '人'],
  ['丘', '乙', '己'],
  ['化', '三', '千'],
  ['七', '十', '土'],
  ['尔', '小', '生'],
  ['八', '九', '子'],
  ['佳', '作', '亡'],
  ['福', '禄', '寿'],
];

// ============================================================
// 内部Meld类型（用于提取逻辑，与Flame的Meld一致）
// ============================================================

interface InternalMeld {
  type: MeldType;
  cards: Card[];
  isJing: boolean;
}

// ============================================================
// 提取函数（匹配Flame的HuCalculator提取逻辑）
// ============================================================

/** 提取句（同组不同3张） */
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
        // 放回
        for (const c of juCards) {
          const posList = byPos.get(c.position);
          if (posList) posList.push(c);
        }
      }
    }
  }
}

/** 提取招（4张同字） */
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

/** 提取坎（3张同字） */
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

/** 提取对和半靠（匹配Flame的extractDuiAndKao） */
function extractDuiAndKao(remaining: Card[], out: InternalMeld[]): void {
  // 先提取对
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

  // 再提取半靠（同组不同2张）
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

// ============================================================
// 胡数计算（匹配Flame的HuCalculator）
// ============================================================

/** 计算单张胡数 */
function singleHu(card: Card): number {
  if (isJingChar(card.char)) return 4;
  return 0;
}

/** 计算Meld胡数 */
function meldGetHuCount(meld: InternalMeld, isHand: boolean, isPao: boolean = false): number {
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

/** 计算组合牌胡数 */
function calculateMeldHu(melds: Meld[], isPao: boolean = false): number {
  let total = 0;
  for (const meld of melds) {
    total += meldGetHuCount(meld as InternalMeld, false, isPao);
  }
  return total;
}

/** 计算附加胡数 */
function calculateBonus(aSet: InternalMeld[], dSet: InternalMeld[], eSet: Card[]): number {
  let bonus = 0;

  const aCharCount = new Map<string, number>();
  for (const meld of aSet) {
    for (const card of meld.cards) {
      aCharCount.set(card.char, (aCharCount.get(card.char) || 0) + 1);
    }
  }

  // a. 普对对应字在A中有1张 → +3
  for (const meld of dSet) {
    if (meld.type === 'dui' && !meld.isJing) {
      const ch = meld.cards[0].char;
      const count = aCharCount.get(ch) || 0;
      if (count === 1) bonus += 3;
    }
    // b. 普靠中字在A中有2张 → +6
    if (meld.type === 'kao' && !meld.isJing) {
      for (const card of meld.cards) {
        const count = aCharCount.get(card.char) || 0;
        if (count === 2) {
          bonus += 6;
          break;
        }
      }
    }
  }

  // c. 普单在A中有2张 → +3
  for (const card of eSet) {
    if (isJingChar(card.char)) continue;
    const count = aCharCount.get(card.char) || 0;
    if (count === 2) bonus += 3;
  }

  // d. 3句相同
  const aSentenceCount = new Map<number, number>();
  for (const meld of aSet) {
    if (meld.type === 'ju') {
      const s = meld.cards[0].sentence;
      aSentenceCount.set(s, (aSentenceCount.get(s) || 0) + 1);
    }
  }
  for (const [s, count] of aSentenceCount) {
    if (count >= 3) {
      if (s === 1 || s === 8) {
        bonus += 6;
      } else {
        bonus += 9;
      }
    }
  }

  return bonus;
}

/** 计算手牌胡数 */
function calculateHandHu(hand: Card[], _melds: Meld[]): number {
  if (hand.length === 0) return 0;

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

  let hu = 0;
  for (const m of aSet) hu += meldGetHuCount(m, true);
  for (const m of bSet) hu += meldGetHuCount(m, true);
  for (const m of cSet) hu += meldGetHuCount(m, true);
  for (const m of dSet) hu += meldGetHuCount(m, true);
  for (const card of eSet) hu += singleHu(card);

  hu += calculateBonus(aSet, dSet, eSet);

  return hu;
}

// ============================================================
// 特殊胡牌类型检测（匹配Flame的HuCalculator）
// ============================================================

/** 检查招牌是否被用于句 */
function isZhaoUsedInSentence(hand: Card[], melds: Meld[]): boolean {
  const zhaoMelds = melds.filter(m => m.type === 'zhao');
  if (zhaoMelds.length === 0) return false;

  const allCards = [...hand, ...melds.flatMap(m => m.cards)];

  for (const zhaoMeld of zhaoMelds) {
    const zhaoSentence = zhaoMeld.cards[0].sentence;
    const sentenceCards = allCards.filter(c => c.sentence === zhaoSentence);
    const positions = new Set(sentenceCards.map(c => c.position));
    if (positions.size === 3) return true;
  }
  return false;
}

/** 检查十对 */
function checkShiDui(hand: Card[], melds: Meld[]): boolean {
  const counts = new Map<string, number>();
  for (const card of hand) {
    counts.set(card.char, (counts.get(card.char) || 0) + 1);
  }

  let duiCount = 0;
  for (const count of counts.values()) {
    if (count === 2) duiCount++;
    else if (count === 4) duiCount += 2;
  }

  for (const meld of melds) {
    if (meld.type === 'kan') duiCount += 1;
    else if (meld.type === 'zhao') duiCount += 2;
  }

  return duiCount === 10;
}

/** 检查枯胡 */
function checkKuHu(hand: Card[], melds: Meld[], _effectiveHasZhao: boolean): boolean {
  const hasChi = melds.some(m => m.type === 'ju');
  if (hasChi) return false;

  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  if (!allCards.some(c => c.char === '上' || c.char === '福')) return false;

  const counts = new Map<string, number>();
  for (const card of hand) {
    counts.set(card.char, (counts.get(card.char) || 0) + 1);
  }

  for (const count of counts.values()) {
    if (count === 1) return false;
    if (count >= 4) return false;
  }

  let kanCount = 0;
  let duiCount = 0;
  let zhaoCount = 0;

  for (const count of counts.values()) {
    if (count === 3) kanCount++;
    else if (count === 2) duiCount++;
  }

  for (const meld of melds) {
    if (meld.type === 'kan') kanCount++;
    else if (meld.type === 'zhao') zhaoCount++;
  }

  return (kanCount + zhaoCount) === 6 && duiCount === 1;
}

/** 检查清枯胡 */
function checkQingKuHu(hand: Card[], melds: Meld[], _effectiveHasZhao: boolean): boolean {
  const hasChi = melds.some(m => m.type === 'ju');
  if (hasChi) return false;

  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  if (allCards.some(c => c.char === '上' || c.char === '福')) return false;

  const counts = new Map<string, number>();
  for (const card of hand) {
    counts.set(card.char, (counts.get(card.char) || 0) + 1);
  }

  for (const count of counts.values()) {
    if (count === 1) return false;
    if (count >= 4) return false;
  }

  let kanCount = 0;
  let duiCount = 0;
  let zhaoCount = 0;

  for (const count of counts.values()) {
    if (count === 3) kanCount++;
    else if (count === 2) duiCount++;
  }

  for (const meld of melds) {
    if (meld.type === 'kan') kanCount++;
    else if (meld.type === 'zhao') zhaoCount++;
  }

  return (kanCount + zhaoCount) === 6 && duiCount === 1;
}

/** 检查黑元 */
function checkHeiYuan(hand: Card[], melds: Meld[], effectiveHasZhao: boolean): boolean {
  const hasPeng = melds.some(m => m.type === 'kan');
  const hasZhao = melds.some(m => m.type === 'zhao');

  if (hasPeng || (hasZhao && effectiveHasZhao)) return false;

  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  if (allCards.some(c => c.sentence === 1 || c.sentence === 8)) return false;
  if (allCards.some(c => c.char === '上' || c.char === '福')) return false;

  return checkSentencePattern(hand, melds);
}

/** 检查句型模式（黑元/红元共用） */
function checkSentencePattern(hand: Card[], melds: Meld[]): boolean {
  const cards = [...hand];
  const usedIds = new Set<number>();

  let meldSentenceCount = 0;
  for (const meld of melds) {
    if (meld.type === 'ju') meldSentenceCount++;
  }

  const neededSentences = 6 - meldSentenceCount;

  let foundGroup = true;
  while (foundGroup) {
    foundGroup = false;
    for (let s = 1; s <= 8; s++) {
      const sentenceCards = cards.filter(c => c.sentence === s && !usedIds.has(c.id));
      const pos0 = sentenceCards.filter(c => c.position === 0);
      const pos1 = sentenceCards.filter(c => c.position === 1);
      const pos2 = sentenceCards.filter(c => c.position === 2);

      if (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
        usedIds.add(pos0[0].id);
        usedIds.add(pos1[0].id);
        usedIds.add(pos2[0].id);
        foundGroup = true;
      }
    }
  }

  const remaining = cards.filter(c => !usedIds.has(c.id));
  const handSentenceCount = (cards.length - remaining.length) / 3;

  if (handSentenceCount === neededSentences && remaining.length === 2) {
    const c1 = remaining[0];
    const c2 = remaining[1];
    if (c1.sentence === c2.sentence && c1.position !== c2.position) {
      return true;
    }
  }

  return false;
}

/** 检查红元，返回精数（0表示不满足） */
function checkHongYuan(hand: Card[], melds: Meld[], effectiveHasZhao: boolean): number {
  const hasPeng = melds.some(m => m.type === 'kan');
  const hasZhao = melds.some(m => m.type === 'zhao');

  if (hasPeng || (hasZhao && effectiveHasZhao)) return 0;

  if (melds.length > 0) {
    if (!melds.every(m => m.type === 'ju')) return 0;
  }

  let shangDaRenSentenceCount = 0;
  let fuLuShouSentenceCount = 0;
  let totalSentenceCount = 0;

  for (const meld of melds) {
    if (meld.type === 'ju') {
      totalSentenceCount++;
      const sentence = meld.cards[0].sentence;
      if (sentence === 1) shangDaRenSentenceCount++;
      if (sentence === 8) fuLuShouSentenceCount++;
    }
  }

  const usedIds = new Set<number>();

  let foundGroup = true;
  while (foundGroup) {
    foundGroup = false;
    for (let s = 1; s <= 8; s++) {
      const sentenceCards = hand.filter(c => c.sentence === s && !usedIds.has(c.id));
      const pos0 = sentenceCards.filter(c => c.position === 0);
      const pos1 = sentenceCards.filter(c => c.position === 1);
      const pos2 = sentenceCards.filter(c => c.position === 2);

      if (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
        usedIds.add(pos0[0].id);
        usedIds.add(pos1[0].id);
        usedIds.add(pos2[0].id);
        foundGroup = true;
        totalSentenceCount++;
        if (s === 1) shangDaRenSentenceCount++;
        if (s === 8) fuLuShouSentenceCount++;
      }
    }
  }

  const totalSpecialSentenceCount = shangDaRenSentenceCount + fuLuShouSentenceCount;
  if (totalSpecialSentenceCount < 2) return 0;

  const remaining = hand.filter(c => !usedIds.has(c.id));
  if (remaining.length !== 2) return 0;
  if (totalSentenceCount !== 6) return 0;

  const c1 = remaining[0];
  const c2 = remaining[1];
  const isHalfKao =
    c1.sentence === c2.sentence &&
    c1.position !== c2.position &&
    c1.char !== c2.char;
  if (!isHalfKao) return 0;

  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const shangCount = allCards.filter(c => c.char === '上').length;
  const fuCount = allCards.filter(c => c.char === '福').length;
  const shangFuCount = shangCount + fuCount;

  if (shangFuCount >= 3 && shangFuCount <= 6) {
    return shangFuCount;
  }

  return 0;
}

/** 检查清枯重台 */
function checkQingKuChongTai(hand: Card[], melds: Meld[]): string | null {
  const zhaoCount = melds.filter(m => m.type === 'zhao').length;
  const hasShangFu = melds.some(m =>
    m.cards.some(c => c.char === '上' || c.char === '福')
  );

  if (hasShangFu) return null;

  const counts = new Map<string, number>();
  for (const card of hand) {
    counts.set(card.char, (counts.get(card.char) || 0) + 1);
  }

  const handZhaoCount = [...counts.values()].filter(c => c >= 4).length;
  const handKanCount = [...counts.values()].filter(c => c === 3).length;
  const handDuiCount = [...counts.values()].filter(c => c === 2).length;

  const totalZhaoCount = zhaoCount + handZhaoCount;

  if (totalZhaoCount === 6 && handDuiCount === 1) {
    return 'qingKuChongTaiHu';
  }
  if (totalZhaoCount === 5 && handKanCount === 1 && handDuiCount === 1) {
    return 'qingKuChongTaiKa';
  }

  let halfKaoCount = 0;
  for (let s = 1; s <= 8; s++) {
    const sentenceCards = hand.filter(c => c.sentence === s);
    const positions = new Set(sentenceCards.map(c => c.position));
    if (positions.size === 2 &&
        !sentenceCards.some(c => c.char === '上' || c.char === '福')) {
      halfKaoCount++;
    }
  }

  if (totalZhaoCount === 6 && halfKaoCount === 1) {
    return 'qingKuChongTaiHu';
  }
  if (totalZhaoCount === 5 && handKanCount === 1 && halfKaoCount === 1) {
    return 'qingKuChongTaiKa';
  }

  return null;
}

// ============================================================
// canHu（匹配Flame的HuCalculator.canHu）
// ============================================================

/** 结构检查 */
function checkStructural(hand: Card[]): boolean {
  const remaining = [...hand];
  const aSet: InternalMeld[] = [];
  const bSet: InternalMeld[] = [];
  const cSet: InternalMeld[] = [];
  const dSet: Card[] = [];

  extractJu(remaining, aSet);
  extractKan(remaining, bSet);
  extractDuiAndKao(remaining, cSet);
  dSet.push(...remaining);

  if (cSet.length === 1 && dSet.length === 0) return true;

  const byChar = new Map<string, number>();
  for (const card of hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }
  let pairCount = 0;
  for (const count of byChar.values()) {
    pairCount += Math.floor(count / 2);
  }
  if (pairCount >= 10) return true;

  return false;
}

/** 判断是否可以胡牌（匹配Flame的HuCalculator.canHu） */
function canHuInternal(hand: Card[], melds: Meld[]): boolean {
  if (!checkStructural(hand)) return false;

  const meldHu = calculateMeldHu(melds);
  const handHu = calculateHandHu(hand, melds);
  const totalHu = meldHu + handHu;

  if (totalHu >= 11) return true;

  const hasZhao = melds.some(m => m.type === 'zhao');
  const effectiveHasZhao = hasZhao && !isZhaoUsedInSentence(hand, melds);

  if (checkShiDui(hand, melds)) return true;
  if (checkHeiYuan(hand, melds, effectiveHasZhao)) return true;
  if (checkHongYuan(hand, melds, effectiveHasZhao) > 0) return true;
  if (checkKuHu(hand, melds, effectiveHasZhao)) return true;
  if (checkQingKuHu(hand, melds, effectiveHasZhao)) return true;
  if (checkQingKuChongTai(hand, melds) !== null) return true;

  return false;
}

// ============================================================
// 听牌检查（匹配Flame的TingChecker）
// ============================================================

enum BasicTingType { none, ninePairs, singleWait, pairWait }

interface BasicTingResult {
  met: boolean;
  type: BasicTingType;
  dSet: InternalMeld[];  // 对/靠集合（b.2时使用）
  eSet: Card[];          // 剩余单牌（b.1时使用）
}

/** 计算手牌中的对数 */
function countPairs(hand: Card[]): number {
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

/** 基本听牌条件检查 */
function checkBasicTing(hand: Card[]): BasicTingResult {
  const pairCount = countPairs(hand);
  if (pairCount >= 9) {
    return { met: true, type: BasicTingType.ninePairs, dSet: [], eSet: [] };
  }

  const remaining = [...hand];
  const aSet: InternalMeld[] = [];
  const bSet: InternalMeld[] = [];
  const cSet: InternalMeld[] = [];
  const dSet: Card[] = [];

  extractJu(remaining, aSet);
  extractKan(remaining, bSet);
  extractDuiAndKao(remaining, cSet);
  dSet.push(...remaining);

  if (cSet.length === 0 && dSet.length === 1) {
    return { met: true, type: BasicTingType.singleWait, dSet: cSet, eSet: dSet };
  }
  if (cSet.length === 2 && dSet.length === 0) {
    return { met: true, type: BasicTingType.pairWait, dSet: cSet, eSet: dSet };
  }

  return { met: false, type: BasicTingType.none, dSet: cSet, eSet: dSet };
}

/** 听牌胡型条件 - 九对 */
function findTingCardsForNinePairs(
  hand: Card[],
  melds: Meld[],
  tingCards: Card[],
): void {
  const byChar = new Map<string, number>();
  for (const card of hand) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }

  for (const ch of ALL_CHARS) {
    const count = byChar.get(ch) || 0;
    if (count === 1 || count === 3) {
      const sentence = CHAR_TO_SENTENCE[ch];
      const position = CHAR_TO_POSITION[ch];
      if (sentence > 0) {
        const testCard: Card = {
          id: -1,
          char: ch as CardChar,
          color: 'red' as const,
          sentence,
          position,
        };
        const testHand = [...hand, testCard];
        if (canHuInternal(testHand, melds)) {
          tingCards.push(testCard);
        }
      }
    }
  }
}

/** 获取靠的伙伴字（同组不同字） */
function getKaoPartners(card: Card): string[] {
  if (card.sentence < 1 || card.sentence > 8) return [];
  return SENTENCE_CHARS[card.sentence - 1].filter(ch => ch !== card.char);
}

/** 听牌胡型条件 - 单等 */
function findTingCardsForSingleWait(
  hand: Card[],
  melds: Meld[],
  eSet: Card[],
  tingCards: Card[],
): void {
  if (eSet.length === 0) return;
  const singleCard = eSet[0];

  // 单牌变成对
  const testHand = [...hand];
  const pairCard: Card = {
    id: -1,
    char: singleCard.char,
    color: singleCard.color,
    sentence: singleCard.sentence,
    position: singleCard.position,
  };
  testHand.push(pairCard);
  if (canHuInternal(testHand, melds)) {
    tingCards.push(pairCard);
  }

  // 单牌变成靠
  const kaoChars = getKaoPartners(singleCard);
  for (const ch of kaoChars) {
    const sentence = CHAR_TO_SENTENCE[ch];
    const position = CHAR_TO_POSITION[ch];
    if (sentence > 0) {
      const kaoCard: Card = {
        id: -2,
        char: ch as CardChar,
        color: 'red' as const,
        sentence,
        position,
      };
      const testHand2 = [...hand, kaoCard];
      if (canHuInternal(testHand2, melds)) {
        tingCards.push(kaoCard);
      }
    }
  }
}

/** 听牌胡型条件 - 对/靠等 */
function findTingCardsForPairWait(
  hand: Card[],
  melds: Meld[],
  dSet: InternalMeld[],
  tingCards: Card[],
): void {
  const groupSet = new Set<number>();
  for (const meld of dSet) {
    groupSet.add(meld.cards[0].sentence);
  }

  for (const sentence of groupSet) {
    const sentenceChars = SENTENCE_CHARS[sentence - 1];
    for (const ch of sentenceChars) {
      const s = CHAR_TO_SENTENCE[ch];
      const p = CHAR_TO_POSITION[ch];
      if (s > 0) {
        const testCard: Card = {
          id: -10,
          char: ch as CardChar,
          color: 'red' as const,
          sentence: s,
          position: p,
        };
        const testHand = [...hand, testCard];
        if (canHuInternal(testHand, melds)) {
          if (!tingCards.some(t => t.char === ch)) {
            tingCards.push(testCard);
          }
        }
      }
    }
  }
}

/** 听牌胡型条件检查 */
function checkHuTypeTing(
  hand: Card[],
  melds: Meld[],
  basic: BasicTingResult,
): Card[] {
  const tingCards: Card[] = [];

  switch (basic.type) {
    case BasicTingType.ninePairs:
      findTingCardsForNinePairs(hand, melds, tingCards);
      break;
    case BasicTingType.singleWait:
      findTingCardsForSingleWait(hand, melds, basic.eSet, tingCards);
      break;
    case BasicTingType.pairWait:
      findTingCardsForPairWait(hand, melds, basic.dSet, tingCards);
      break;
    case BasicTingType.none:
      break;
  }

  return tingCards;
}

// ============================================================
// 导出函数
// ============================================================

/**
 * 判断是否听牌（匹配Flame的TingChecker.checkTing）
 * @param hand 手牌
 * @param melds 组合牌
 */
export function isTing(hand: Card[], melds: Meld[] = []): boolean {
  if (hand.length + melds.length * 3 >= 20) {
    return false;
  }

  const basicResult = checkBasicTing(hand);
  if (!basicResult.met) return false;

  const tingCards = checkHuTypeTing(hand, melds, basicResult);
  return tingCards.length > 0;
}

/**
 * 获取听哪些牌（匹配Flame的TingChecker.checkTing的tingCards）
 * @param hand 手牌
 * @param melds 组合牌
 */
export function getTingCards(hand: Card[], melds: Meld[] = []): CardChar[] {
  if (hand.length + melds.length * 3 >= 20) {
    return [];
  }

  const basicResult = checkBasicTing(hand);
  if (!basicResult.met) return [];

  const tingCards = checkHuTypeTing(hand, melds, basicResult);
  // 去重并返回CardChar
  const charSet = new Set<CardChar>();
  for (const card of tingCards) {
    charSet.add(card.char);
  }
  return [...charSet];
}
