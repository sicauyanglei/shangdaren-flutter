/**
 * 发牌器 —— 洗牌、发牌（庄家20张/闲家19张）、摸牌
 * 服务器只维护牌堆与发牌，不参与任何游戏判定逻辑
 */

// 24 种字，每字 4 张，共 96 张
const CARD_CHARS = [
  '上', '大', '人',
  '丘', '乙', '己',
  '化', '三', '千',
  '七', '十', '土',
  '尔', '小', '生',
  '八', '九', '子',
  '佳', '作', '亡',
  '福', '禄', '寿',
];

/** 创建洗好的牌堆（Fisher-Yates） */
function createDeck() {
  const deck = [];
  for (const ch of CARD_CHARS) {
    for (let i = 0; i < 4; i++) deck.push(ch);
  }
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

/**
 * 发牌：从牌堆顶部（pop）依次发，庄家 20 张、闲家 19 张
 * @returns {{ hands: {[seat:number]: string[]}, remaining: number }}
 */
function deal(deck, dealerSeat) {
  const hands = { 0: [], 1: [], 2: [] };
  // 庄家 20 张
  for (let i = 0; i < 20; i++) {
    hands[dealerSeat].push(deck.pop());
  }
  // 闲家各 19 张
  for (const s of [0, 1, 2]) {
    if (s === dealerSeat) continue;
    for (let i = 0; i < 19; i++) {
      hands[s].push(deck.pop());
    }
  }
  return { hands, remaining: deck.length };
}

/** 摸牌：返回顶部一张，牌堆空返回 null */
function draw(deck) {
  if (deck.length === 0) return null;
  return { card: deck.pop(), remaining: deck.length };
}

module.exports = { CARD_CHARS, createDeck, deal, draw };
