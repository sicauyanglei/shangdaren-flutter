import { Card, CardChar, CARD_GROUPS, getCardGroup } from '../types/card';

// 统计手牌中每个字的数量
function countChars(cards: Card[]): Map<CardChar, number> {
  const count = new Map<CardChar, number>();
  for (const c of cards) {
    count.set(c.char, (count.get(c.char) || 0) + 1);
  }
  return count;
}

// 基本听牌条件a：手牌9对
function checkTingConditionA(hand: Card[]): boolean {
  const countMap = countChars(hand);
  let pairCount = 0;
  for (const [, count] of countMap) {
    if (count === 2) pairCount++;
    else if (count === 4) pairCount += 2;
  }
  return pairCount >= 9;
}

// 基本听牌条件b：移除句/坎/对靠后
function checkTingConditionB(hand: Card[]): { condition: 'b1' | 'b2' | null } {
  const countMap = countChars(hand);
  const remaining = [...hand];

  // 移除句
  for (let g = 0; g < CARD_GROUPS.length; g++) {
    const group = CARD_GROUPS[g];
    while (group.every(ch => (countMap.get(ch) || 0) > 0)) {
      for (const ch of group) {
        const idx = remaining.findIndex(c => c.char === ch);
        if (idx >= 0) {
          remaining.splice(idx, 1);
          countMap.set(ch, (countMap.get(ch) || 0) - 1);
        }
      }
    }
  }

  // 移除坎
  const r1Count = countChars(remaining);
  for (const [char, count] of r1Count) {
    if (count >= 3) {
      for (let i = 0; i < 3; i++) {
        const idx = remaining.findIndex(c => c.char === char);
        if (idx >= 0) remaining.splice(idx, 1);
      }
    }
  }

  // 移除对/半靠
  const r2Count = countChars(remaining);
  let cCount = 0; // 对/靠数量
  let dCount = 0; // 剩余单数量

  // 提取对
  for (const [char, count] of r2Count) {
    if (count >= 2) {
      cCount++;
      for (let i = 0; i < 2; i++) {
        const idx = remaining.findIndex(c => c.char === char);
        if (idx >= 0) remaining.splice(idx, 1);
      }
    }
  }

  // 提取半靠
  const r3Count = countChars(remaining);
  for (let g = 0; g < CARD_GROUPS.length; g++) {
    const group = CARD_GROUPS[g];
    const available = group.filter(ch => (r3Count.get(ch) || 0) > 0);
    if (available.length >= 2) {
      cCount++;
      for (let i = 0; i < 2; i++) {
        const idx = remaining.findIndex(c => c.char === available[i]);
        if (idx >= 0) remaining.splice(idx, 1);
      }
    }
  }

  // 剩余单
  dCount = remaining.length;

  if (cCount === 0 && dCount === 1) return { condition: 'b1' };
  if (cCount === 2 && dCount === 0) return { condition: 'b2' };
  return { condition: null };
}

// 判断是否听牌
export function isTing(hand: Card[]): boolean {
  // 基本听牌条件
  if (checkTingConditionA(hand)) return true;
  const result = checkTingConditionB(hand);
  if (!result.condition) return false;

  // 听牌胡型条件（简化：只要基本条件满足即听牌）
  return true;
}

// 获取听哪些牌
export function getTingCards(hand: Card[]): CardChar[] {
  const allChars: CardChar[] = ['上','大','人','丘','乙','己','化','三','千','七','十','土','尔','小','生','八','九','子','佳','作','亡','福','禄','寿'];
  const tingCards: CardChar[] = [];

  for (const char of allChars) {
    // 模拟加入这张牌
    const testHand = [...hand, { id: -1, char, color: 'red' } as Card];
    if (isTing(testHand)) {
      tingCards.push(char);
    }
  }

  return tingCards;
}
