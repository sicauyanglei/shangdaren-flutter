import { Card, CardChar, CARD_GROUPS, getCardGroup } from '../types/card';
import { Player } from '../types/player';

// AI策略基类
export function aiDecideDiscard(player: Player, difficulty: string): Card {
  const hand = player.hand;
  if (hand.length === 0) return hand[0];

  // 按优先级排序：优先出低价值牌
  const scored = hand.map(card => ({
    card,
    score: evaluateCard(card, hand, difficulty),
  }));

  scored.sort((a, b) => a.score - b.score);
  return scored[0].card;
}

// 评估卡牌价值
function evaluateCard(card: Card, hand: Card[], difficulty: string): number {
  let score = 0;
  const char = card.char;
  const groupIdx = getCardGroup(char);
  const sameCharCount = hand.filter(c => c.char === char).length;

  // 同字数量越多越有价值
  score += sameCharCount * 10;

  // 精字（上/福）价值高
  if (char === '上' || char === '福') score += 30;

  // 银字（大/人/禄/寿）价值中等
  if (['大', '人', '禄', '寿'].includes(char)) score += 15;

  // 同组牌数量
  const group = CARD_GROUPS[groupIdx];
  const groupCount = group.filter(ch => hand.some(c => c.char === ch)).length;
  score += groupCount * 5;

  // 困难模式：更注重听牌和胡牌
  if (difficulty === 'hard') {
    // 接近成句的牌价值更高
    if (groupCount === 2) score += 20;
    if (groupCount === 3) score += 40;
    // 已听牌的牌不轻易出
    if (sameCharCount >= 2) score += 25;
  }

  return score;
}

// AI决定是否吃牌
export function aiDecideChi(
  player: Player,
  discardedCard: Card,
  difficulty: string
): boolean {
  const hand = player.hand;
  const groupIdx = getCardGroup(discardedCard.char);
  const group = CARD_GROUPS[groupIdx];

  // 检查手牌中是否有同组其他牌
  const otherChars = group.filter(ch => ch !== discardedCard.char);
  const hasOther = otherChars.every(ch => hand.some(c => c.char === ch));

  if (!hasOther) return false;

  // 困难模式：如果手牌有且只有这张卡牌完整的1句，不吃
  if (difficulty === 'hard') {
    const allGroupChars = group.filter(ch => hand.some(c => c.char === ch));
    if (allGroupChars.length === 2) {
      // 检查每个字是否只有一张
      const allSingle = allGroupChars.every(
        ch => hand.filter(c => c.char === ch).length === 1
      );
      if (allSingle) return false;
    }
  }

  return true;
}

// AI决定是否碰牌
export function aiDecidePeng(
  player: Player,
  discardedCard: Card,
  difficulty: string
): boolean {
  const sameCount = player.hand.filter(c => c.char === discardedCard.char).length;
  if (sameCount < 2) return false;

  // 困难模式更积极碰牌
  if (difficulty === 'hard') return true;

  // 简单模式50%概率碰
  return Math.random() > 0.5;
}

// AI决定是否招牌
export function aiDecideZhao(
  player: Player,
  discardedCard: Card,
  difficulty: string
): boolean {
  const sameCount = player.hand.filter(c => c.char === discardedCard.char).length;
  return sameCount >= 3;
}
