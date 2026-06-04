import { Card, isJingChar, isYinChar } from '../types/card';
import { Meld, getMeldHuCount } from '../types/player';

// ============ 胡牌类型结果 ============

export interface HuTypeResult {
  type: string;
  name: string;
  dianpao: number;
  zimo: number;
}

// ============ 内部Meld构造辅助 ============

interface InternalMeld {
  type: 'ju' | 'kan' | 'zhao' | 'dui' | 'kao';
  cards: Card[];
  isJing: boolean;
}

function makeMeld(type: InternalMeld['type'], cards: Card[], isJing: boolean): InternalMeld {
  return { type, cards, isJing };
}

function meldGetHuCount(meld: InternalMeld, isHand: boolean = true, isPao: boolean = false): number {
  return getMeldHuCount(meld as Meld, isHand, isPao);
}

// ============ 单牌胡数 ============

function singleHu(card: Card): number {
  if (isJingChar(card.char)) return 4;
  if (isYinChar(card.char)) return 0;
  return 0;
}

// ============ 牌组提取 ============

/** 提取句：按sentence+position分组，找到3个不同position的牌组成一句 */
function extractJu(remaining: Card[], out: InternalMeld[]): void {
  const bySentence = new Map<number, Card[]>();
  for (const card of remaining) {
    if (!bySentence.has(card.sentence)) {
      bySentence.set(card.sentence, []);
    }
    bySentence.get(card.sentence)!.push(card);
  }

  for (let s = 1; s <= 8; s++) {
    const cards = bySentence.get(s);
    if (!cards) continue;

    const byPos = new Map<number, Card[]>();
    for (const c of cards) {
      if (!byPos.has(c.position)) {
        byPos.set(c.position, []);
      }
      byPos.get(c.position)!.push(c);
    }

    const positions = [...byPos.keys()].sort((a, b) => a - b);
    if (positions.length >= 3) {
      const juCards: Card[] = [];
      for (const pos of positions) {
        const posList = byPos.get(pos)!;
        if (posList.length > 0) {
          juCards.push(posList.pop()!);
        }
      }
      if (juCards.length === 3) {
        const hasJing = juCards.some(c => isJingChar(c.char));
        out.push(makeMeld('ju', juCards, hasJing));
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

/** 提取招：4张同字 */
function extractZhao(remaining: Card[], out: InternalMeld[]): void {
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    if (!byChar.has(card.char)) {
      byChar.set(card.char, []);
    }
    byChar.get(card.char)!.push(card);
  }

  for (const [, charCards] of byChar) {
    if (charCards.length >= 4) {
      const zhaoCards = charCards.slice(0, 4);
      out.push(makeMeld('zhao', zhaoCards, isJingChar(zhaoCards[0].char)));
      for (const c of zhaoCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractZhao(remaining, out);
      return;
    }
  }
}

/** 提取坎：3张同字 */
function extractKan(remaining: Card[], out: InternalMeld[]): void {
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    if (!byChar.has(card.char)) {
      byChar.set(card.char, []);
    }
    byChar.get(card.char)!.push(card);
  }

  for (const [, charCards] of byChar) {
    if (charCards.length >= 3) {
      const kanCards = charCards.slice(0, 3);
      out.push(makeMeld('kan', kanCards, isJingChar(kanCards[0].char)));
      for (const c of kanCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractKan(remaining, out);
      return;
    }
  }
}

/** 提取对和半靠：先提取对，再提取半靠（所有position组合） */
function extractDuiAndKao(remaining: Card[], out: InternalMeld[]): void {
  // 先提取对
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    if (!byChar.has(card.char)) {
      byChar.set(card.char, []);
    }
    byChar.get(card.char)!.push(card);
  }

  for (const [, charCards] of byChar) {
    if (charCards.length >= 2) {
      const duiCards = charCards.slice(0, 2);
      out.push(makeMeld('dui', duiCards, isJingChar(duiCards[0].char)));
      for (const c of duiCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractDuiAndKao(remaining, out);
      return;
    }
  }

  // 再提取半靠
  const bySentence = new Map<number, Card[]>();
  for (const card of remaining) {
    if (!bySentence.has(card.sentence)) {
      bySentence.set(card.sentence, []);
    }
    bySentence.get(card.sentence)!.push(card);
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
        out.push(makeMeld('kao', [c1, c2], hasJing));
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

/** 提取半靠优先，再提取对（保留供外部使用） */
export function extractKaoFirst(remaining: Card[], out: InternalMeld[]): void {
  // 先提取半靠
  const bySentence = new Map<number, Card[]>();
  for (const card of remaining) {
    if (!bySentence.has(card.sentence)) {
      bySentence.set(card.sentence, []);
    }
    bySentence.get(card.sentence)!.push(card);
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
        out.push(makeMeld('kao', [c1, c2], hasJing));
        const idx1 = remaining.indexOf(c1);
        if (idx1 >= 0) remaining.splice(idx1, 1);
        const idx2 = remaining.indexOf(c2);
        if (idx2 >= 0) remaining.splice(idx2, 1);
        extractKaoFirst(remaining, out);
        return;
      }
    }
  }

  // 再提取对
  const byChar = new Map<string, Card[]>();
  for (const card of remaining) {
    if (!byChar.has(card.char)) {
      byChar.set(card.char, []);
    }
    byChar.get(card.char)!.push(card);
  }

  for (const [, charCards] of byChar) {
    if (charCards.length >= 2) {
      const duiCards = charCards.slice(0, 2);
      out.push(makeMeld('dui', duiCards, isJingChar(duiCards[0].char)));
      for (const c of duiCards) {
        const idx = remaining.indexOf(c);
        if (idx >= 0) remaining.splice(idx, 1);
      }
      extractKaoFirst(remaining, out);
      return;
    }
  }
}

// ============ 附加胡数计算 ============

function calculateBonus(
  aSet: InternalMeld[],
  dSet: InternalMeld[],
  eSet: Card[],
): number {
  let bonus = 0;

  // A集中每个字出现的次数
  const aCharCount = new Map<string, number>();
  for (const meld of aSet) {
    for (const card of meld.cards) {
      aCharCount.set(card.char, (aCharCount.get(card.char) || 0) + 1);
    }
  }

  // a. D中的普对，对应字在A中有1张 → +3（金对除外）
  for (const meld of dSet) {
    if (meld.type === 'dui' && !meld.isJing) {
      const ch = meld.cards[0].char;
      const count = aCharCount.get(ch) || 0;
      if (count === 1) bonus += 3;
    }
    // b. D中的普靠，靠中任意字在A中有2张 → +6（金靠除外）
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

  // c. E中的普单，对应字在A中有2张 → +3（金单除外）
  for (const card of eSet) {
    if (isJingChar(card.char)) continue;
    const count = aCharCount.get(card.char) || 0;
    if (count === 2) bonus += 3;
  }

  // d. A中3句相同
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

// ============ 结构检查 ============

/** 检查手牌是否满足胡牌结构条件 */
function _checkStructural(hand: Card[]): boolean {
  const remaining = [...hand];
  const aSet: InternalMeld[] = [];
  const bSet: InternalMeld[] = [];
  const cSet: InternalMeld[] = [];

  extractJu(remaining, aSet);
  extractKan(remaining, bSet);
  extractDuiAndKao(remaining, cSet);

  // C=1(一对/靠) 且 D=0(无剩余单牌)
  if (cSet.length === 1 && remaining.length === 0) return true;

  // 10对检查
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

// ============ 特殊胡型检查 ============

/** 检查招牌是否被用于组句 */
function _isZhaoUsedInSentence(hand: Card[], melds: Meld[]): boolean {
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

/** 十对检查：手牌+组合牌共10对（坎算1对，招算2对） */
function _checkShiDui(hand: Card[], melds: Meld[]): boolean {
  const counts = new Map<string, number>();
  for (const card of hand) {
    counts.set(card.char, (counts.get(card.char) || 0) + 1);
  }

  let duiCount = 0;
  for (const count of counts.values()) {
    if (count === 2) {
      duiCount++;
    } else if (count === 4) {
      duiCount += 2;
    }
  }

  for (const meld of melds) {
    if (meld.type === 'kan') {
      duiCount += 1;
    } else if (meld.type === 'zhao') {
      duiCount += 2;
    }
  }

  return duiCount === 10;
}

/** 黑元检查：无sentence 1/8，无上/福，全是句+一个靠 */
function _checkHeiYuan(hand: Card[], melds: Meld[], effectiveHasZhao: boolean): boolean {
  const hasPeng = melds.some(m => m.type === 'kan');
  const hasZhao = melds.some(m => m.type === 'zhao');

  if (hasPeng || (hasZhao && effectiveHasZhao)) return false;

  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  if (allCards.some(c => c.sentence === 1 || c.sentence === 8)) return false;
  if (allCards.some(c => c.char === '上' || c.char === '福')) return false;

  return _checkSentencePattern(hand, melds);
}

/** 检查句型模式：6句+1靠 */
function _checkSentencePattern(hand: Card[], melds: Meld[]): boolean {
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

/** 红元检查：返回精数(0表示不满足) */
function _checkHongYuan(hand: Card[], melds: Meld[], effectiveHasZhao: boolean): number {
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

/** 枯胡检查：无吃，有上/福，手牌全是坎/对（无单牌，无招） */
function _checkKuHu(hand: Card[], melds: Meld[], _effectiveHasZhao: boolean): boolean {
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
    if (count === 3) {
      kanCount++;
    } else if (count === 2) {
      duiCount++;
    }
  }

  for (const meld of melds) {
    if (meld.type === 'kan') {
      kanCount++;
    } else if (meld.type === 'zhao') {
      zhaoCount++;
    }
  }

  return (kanCount + zhaoCount) === 6 && duiCount === 1;
}

/** 清枯胡检查：无吃，无上/福，手牌全是坎/对 */
function _checkQingKuHu(hand: Card[], melds: Meld[], _effectiveHasZhao: boolean): boolean {
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
    if (count === 3) {
      kanCount++;
    } else if (count === 2) {
      duiCount++;
    }
  }

  for (const meld of melds) {
    if (meld.type === 'kan') {
      kanCount++;
    } else if (meld.type === 'zhao') {
      zhaoCount++;
    }
  }

  return (kanCount + zhaoCount) === 6 && duiCount === 1;
}

/** 清枯重台检查：无上/福，全是招+一个对/靠 */
function _checkQingKuChongTai(hand: Card[], melds: Meld[]): string | null {
  const zhaoCount = melds.filter(m => m.type === 'zhao').length;
  const hasShangFu = melds.some(
    m => m.cards.some(c => c.char === '上' || c.char === '福'),
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

  // 检查半靠情况
  let halfKaoCount = 0;
  for (let s = 1; s <= 8; s++) {
    const sentenceCards = hand.filter(c => c.sentence === s);
    const positions = new Set(sentenceCards.map(c => c.position));
    if (
      positions.size === 2 &&
      !sentenceCards.some(c => c.char === '上' || c.char === '福')
    ) {
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

/** 清胡检查 */
function _checkQingHu(hand: Card[], melds: Meld[], huCount: number): boolean {
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  const shangCount = allCards.filter(c => c.char === '上').length;
  const fuCount = allCards.filter(c => c.char === '福').length;

  if (shangCount > 0 || fuCount > 0) return false;

  if (_hasHalfKao(hand, melds, 1) || _hasHalfKao(hand, melds, 8)) return false;

  if (huCount < 11 || huCount > 21) return false;

  return _checkQingHuRemaining(hand);
}

/** 清胡条件检查（用于清卡胡判断） */
function _checkQingHuConditions(hand: Card[], melds: Meld[]): boolean {
  const allCards = [...hand, ...melds.flatMap(m => m.cards)];
  if (allCards.some(c => c.char === '上')) return false;
  if (allCards.some(c => c.char === '福')) return false;
  if (_hasHalfKao(hand, melds, 1)) return false;
  if (_hasHalfKao(hand, melds, 8)) return false;
  return _checkQingHuRemaining(hand);
}

/** 检查是否有指定sentence的半靠 */
function _hasHalfKao(hand: Card[], melds: Meld[], sentence: number): boolean {
  for (const meld of melds) {
    if (meld.type === 'kao' && meld.cards[0].sentence === sentence) {
      return true;
    }
  }
  for (let i = 0; i < hand.length - 1; i++) {
    for (let j = i + 1; j < hand.length; j++) {
      const c1 = hand[i];
      const c2 = hand[j];
      if (
        c1.sentence === sentence &&
        c2.sentence === sentence &&
        c1.position !== c2.position &&
        c1.char !== c2.char
      ) {
        return true;
      }
    }
  }
  return false;
}

/** 清胡剩余检查 */
function _checkQingHuRemaining(hand: Card[]): boolean {
  const cards = [...hand];
  const usedIds = new Set<number>();

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

  const byChar = new Map<string, number>();
  for (const card of remaining) {
    byChar.set(card.char, (byChar.get(card.char) || 0) + 1);
  }
  for (const count of byChar.values()) {
    if (count >= 3) {
      return _checkQingHuRemainingWithKan(cards);
    }
  }

  if (remaining.length === 2) {
    const c1 = remaining[0];
    const c2 = remaining[1];
    if (c1.char === c2.char) return true;
    if (c1.sentence === c2.sentence && c1.position !== c2.position) return true;
  }

  return false;
}

/** 清胡剩余检查（含坎） */
function _checkQingHuRemainingWithKan(cards: Card[]): boolean {
  const remaining = [...cards];
  const aSet: InternalMeld[] = [];
  const cSet: InternalMeld[] = [];
  const dSet: InternalMeld[] = [];

  extractJu(remaining, aSet);
  extractKan(remaining, cSet);
  extractDuiAndKao(remaining, dSet);

  return remaining.length === 0 || (remaining.length === 2 && dSet.length > 0);
}

// ============ 胡数计算 ============

/** 计算组合牌胡数 */
export function calculateMeldHu(melds: Meld[], isPao: boolean = false): number {
  let total = 0;
  for (const meld of melds) {
    total += getMeldHuCount(meld, false, isPao);
  }
  return total;
}

/** 计算手牌胡数 */
export function calculateHandHu(hand: Card[], _melds: Meld[], paoCard?: Card): number {
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
  for (const m of aSet) {
    hu += meldGetHuCount(m, true);
  }
  for (const m of bSet) {
    hu += meldGetHuCount(m, true);
  }
  for (const m of cSet) {
    if (paoCard && !m.isJing && m.cards.some(c => c.id === paoCard.id)) {
      hu += 2;
    } else {
      hu += meldGetHuCount(m, true);
    }
  }
  for (const m of dSet) {
    hu += meldGetHuCount(m, true);
  }
  for (const card of eSet) {
    hu += singleHu(card);
  }

  hu += calculateBonus(aSet, dSet, eSet);

  return hu;
}

/** 计算总胡数 */
export function calculateTotalHu(hand: Card[], melds: Meld[], paoCard?: Card): number {
  return calculateMeldHu(melds) + calculateHandHu(hand, melds, paoCard);
}

// ============ 胡牌判断 ============

/** 判断是否可以胡牌（点炮场景，需要isTing） */
export function canHu(hand: Card[], melds: Meld[], isTing: boolean): boolean {
  if (!isTing) return false;
  if (!_checkStructural(hand)) return false;

  const totalHu = calculateTotalHu(hand, melds);
  if (totalHu >= 11) return true;

  const hasZhao = melds.some(m => m.type === 'zhao');
  const effectiveHasZhao = hasZhao && !_isZhaoUsedInSentence(hand, melds);

  if (_checkShiDui(hand, melds)) return true;
  if (_checkHeiYuan(hand, melds, effectiveHasZhao)) return true;
  if (_checkHongYuan(hand, melds, effectiveHasZhao) > 0) return true;
  if (_checkKuHu(hand, melds, effectiveHasZhao)) return true;
  if (_checkQingKuHu(hand, melds, effectiveHasZhao)) return true;
  if (_checkQingKuChongTai(hand, melds) !== null) return true;

  return false;
}

/** 判断是否可以自摸（不需要isTing） */
export function canZimo(hand: Card[], melds: Meld[]): boolean {
  if (!_checkStructural(hand)) return false;

  const totalHu = calculateTotalHu(hand, melds);
  if (totalHu >= 11) return true;

  const hasZhao = melds.some(m => m.type === 'zhao');
  const effectiveHasZhao = hasZhao && !_isZhaoUsedInSentence(hand, melds);

  if (_checkShiDui(hand, melds)) return true;
  if (_checkHeiYuan(hand, melds, effectiveHasZhao)) return true;
  if (_checkHongYuan(hand, melds, effectiveHasZhao) > 0) return true;
  if (_checkKuHu(hand, melds, effectiveHasZhao)) return true;
  if (_checkQingKuHu(hand, melds, effectiveHasZhao)) return true;
  if (_checkQingKuChongTai(hand, melds) !== null) return true;

  return false;
}

// ============ 胡牌类型检测 ============

/** 检测胡牌类型，返回HuTypeResult */
export function detectHuType(hand: Card[], melds: Meld[], paoCard?: Card): HuTypeResult {
  const huCount = calculateTotalHu(hand, melds, paoCard);

  const hasZhao = melds.some(m => m.type === 'zhao');
  const effectiveHasZhao = hasZhao && !_isZhaoUsedInSentence(hand, melds);

  const isKuHu = _checkKuHu(hand, melds, effectiveHasZhao);
  const isQingKuHu = _checkQingKuHu(hand, melds, effectiveHasZhao);
  const isShiDui = _checkShiDui(hand, melds);
  const isHeiYuan = _checkHeiYuan(hand, melds, effectiveHasZhao);
  const hongYuanJing = _checkHongYuan(hand, melds, effectiveHasZhao);
  const isQingHu = _checkQingHu(hand, melds, huCount);

  const qingKuChongTaiResult = _checkQingKuChongTai(hand, melds);

  // 优先级顺序检测
  if (qingKuChongTaiResult === 'qingKuChongTaiKa') {
    return { type: 'qingKuChongTaiKa', name: '清枯重台卡', dianpao: 14, zimo: 15 };
  }
  if (qingKuChongTaiResult === 'qingKuChongTaiHu') {
    return { type: 'qingKuChongTaiHu', name: '清枯重台胡', dianpao: 13, zimo: 14 };
  }
  if (isQingKuHu && huCount >= 23 && huCount <= 32) {
    return { type: 'qingKuTaiHu', name: '清枯台胡', dianpao: 7, zimo: 8 };
  }
  if (isKuHu && huCount === 33) {
    return { type: 'kuChongTaiKa', name: '枯重台卡', dianpao: 12, zimo: 13 };
  }
  if (isKuHu && huCount >= 34) {
    return { type: 'kuChongTaiHu', name: '枯重台胡', dianpao: 11, zimo: 12 };
  }
  if (isKuHu && huCount >= 23 && huCount <= 32) {
    return { type: 'kuTaiHu', name: '枯台胡', dianpao: 6, zimo: 7 };
  }
  if (isQingKuHu && huCount === 22) {
    return { type: 'qingKuTaiKa', name: '清枯台卡', dianpao: 8, zimo: 9 };
  }
  if (isQingKuHu) {
    return { type: 'qingKuHu', name: '清枯胡', dianpao: 6, zimo: 7 };
  }
  if (isKuHu) {
    return { type: 'kuHu', name: '枯胡', dianpao: 5, zimo: 6 };
  }
  if (isShiDui) {
    return { type: 'shiDui', name: '十对', dianpao: 10, zimo: 11 };
  }
  if (hongYuanJing > 0) {
    return {
      type: `hongYuan${hongYuanJing}Jing`,
      name: `红元${hongYuanJing}精`,
      dianpao: hongYuanJing,
      zimo: hongYuanJing + 1,
    };
  }
  if (isHeiYuan) {
    return { type: 'heiYuan', name: '黑元', dianpao: 4, zimo: 5 };
  }

  const isQingHuCond = _checkQingHuConditions(hand, melds);
  if (isQingHuCond && huCount === 11) {
    return { type: 'qingKaHu', name: '清卡胡', dianpao: 2, zimo: 3 };
  }
  if (isQingHu) {
    return { type: 'qingHu', name: '清胡', dianpao: 1, zimo: 2 };
  }

  if (huCount < 11) {
    return { type: 'none', name: '无', dianpao: 0, zimo: 0 };
  }
  if (huCount === 11) {
    return { type: 'kaHu', name: '卡胡', dianpao: 1, zimo: 2 };
  }
  if (huCount >= 12 && huCount <= 21) {
    return { type: 'puTongHu', name: '普通胡', dianpao: 0, zimo: 1 };
  }
  if (huCount === 22) {
    return { type: 'taiKa', name: '台卡', dianpao: 2, zimo: 3 };
  }
  if (huCount >= 23 && huCount <= 32) {
    return { type: 'taiHu', name: '台胡', dianpao: 1, zimo: 2 };
  }
  if (huCount === 33) {
    return { type: 'chongTaiKa', name: '重台卡', dianpao: 7, zimo: 8 };
  }
  if (huCount >= 34) {
    return { type: 'chongTaiHu', name: '重台胡', dianpao: 6, zimo: 7 };
  }

  return { type: 'none', name: '无', dianpao: 0, zimo: 0 };
}
