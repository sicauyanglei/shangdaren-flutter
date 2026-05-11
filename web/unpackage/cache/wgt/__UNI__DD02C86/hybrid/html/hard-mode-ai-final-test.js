// 困难模式AI最终优化测试
// 基于hard-mode-ai-optimized-test.js的最佳参数组合

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

const cardMap = {
  '上': {s:1,p:0,c:'red'},'大':{s:1,p:1,c:'green'},'人':{s:1,p:2,c:'black'},
  '丘':{s:2,p:0,c:'red'},'乙':{s:2,p:1,c:'green'},'己':{s:2,p:2,c:'black'},
  '化':{s:3,p:0,c:'red'},'三':{s:3,p:1,c:'green'},'千':{s:3,p:2,c:'black'},
  '七':{s:4,p:0,c:'red'},'十':{s:4,p:1,c:'green'},'土':{s:4,p:2,c:'black'},
  '尔':{s:5,p:0,c:'red'},'小':{s:5,p:1,c:'green'},'生':{s:5,p:2,c:'black'},
  '八':{s:6,p:0,c:'red'},'九':{s:6,p:1,c:'green'},'子':{s:6,p:2,c:'black'},
  '佳':{s:7,p:0,c:'red'},'作':{s:7,p:1,c:'green'},'亡':{s:7,p:2,c:'black'},
  '福':{s:8,p:0,c:'red'},'禄':{s:8,p:1,c:'green'},'寿':{s:8,p:2,c:'black'}
};

function createCard(char) {
  const info = cardMap[char] || {s:0,p:0,c:'black'};
  return { character: char, sentence: info.s, position: info.p, color: info.c, id: Math.random().toString(36).substr(2, 9) };
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

function calculateHuCount(hand, melds) {
  melds = melds || [];
  let hu = 0;
  for (const meld of melds) hu += meld.huValue || 0;
  const cards = [...hand];
  const usedCardIds = new Set();

  let foundSentence = true;
  while (foundSentence) {
    foundSentence = false;
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = cards.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      const pos0 = sentenceCards.filter(c => c.position === 0);
      const pos1 = sentenceCards.filter(c => c.position === 1);
      const pos2 = sentenceCards.filter(c => c.position === 2);
      if (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
        foundSentence = true;
        const isJingJu = sentence === 1 || sentence === 8;
        const hasShang = pos0[0].character === '上' || pos1[0].character === '上' || pos2[0].character === '上';
        const hasFu = pos0[0].character === '福' || pos1[0].character === '福' || pos2[0].character === '福';
        if (isJingJu && (hasShang || hasFu)) hu += 4;
        usedCardIds.add(pos0[0].id);
        usedCardIds.add(pos1[0].id);
        usedCardIds.add(pos2[0].id);
      }
    }
  }

  const remainingAfterJu = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterJu = {};
  for (const card of remainingAfterJu) countsAfterJu[card.character] = (countsAfterJu[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(countsAfterJu)) {
    if (count >= 4) {
      hu += char === '上' || char === '福' ? 16 : 6;
      remainingAfterJu.filter(c => c.character === char).forEach(c => usedCardIds.add(c.id));
    }
  }

  const remainingAfterZhao = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterZhao = {};
  for (const card of remainingAfterZhao) countsAfterZhao[card.character] = (countsAfterZhao[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(countsAfterZhao)) {
    if (count >= 3) {
      hu += char === '上' || char === '福' ? 12 : 3;
      remainingAfterZhao.filter(c => c.character === char).slice(0, 3).forEach(c => usedCardIds.add(c.id));
    }
  }

  const remainingAfterKan = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterKan = {};
  for (const card of remainingAfterKan) countsAfterKan[card.character] = (countsAfterKan[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(countsAfterKan)) {
    if (count >= 2) {
      hu += char === '上' || char === '福' ? 8 : 0;
      remainingAfterKan.filter(c => c.character === char).slice(0, 2).forEach(c => usedCardIds.add(c.id));
    }
  }

  return hu;
}

function detectHuType(hand, melds) {
  const counts = {};
  for (const card of hand) counts[card.character] = (counts[card.character] || 0) + 1;
  let isQing = true;
  for (const card of hand) {
    if (card.character === '上' || card.character === '福') { isQing = false; break; }
  }
  const zhaoCount = Object.values(counts).filter(c => c >= 4).length;
  const kanCount = Object.values(counts).filter(c => c >= 3).length;
  if (zhaoCount >= 6) return { type: 'kuChongTaiHu' };
  if (zhaoCount >= 5 && kanCount >= 1) return { type: 'kuChongTaiKa' };
  if (isQing && zhaoCount >= 5) return { type: 'qingKuChongTaiHu' };
  if (kanCount >= 6) return { type: 'kuHu' };
  if (kanCount >= 5) return { type: 'taiHu' };
  if (kanCount >= 4) return { type: 'chongTaiHu' };
  if (kanCount >= 3) return { type: 'kaHu' };
  return { type: 'puTongHu' };
}

function checkHu(hand, melds) {
  const huCount = calculateHuCount(hand, melds);
  const huType = detectHuType(hand, melds);
  const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa'];
  const canHu = (specialHuTypes.includes(huType.type) || huCount >= 11) && huType.type !== 'none';
  return { canHu, huCount, huType };
}

function analyzeHandGroups(hand, melds) {
  const meldSentenceCount = (melds || []).filter(m => m.type === 'sequence').length;
  const meldKanCount = (melds || []).filter(m => m.type === 'triplet').length;
  const meldZhaoCount = (melds || []).filter(m => m.type === 'quartet').length;
  const usedCardIds = new Set();
  for (const meld of melds || []) for (const card of meld.cards) usedCardIds.add(card.id);

  let sentenceCount = meldSentenceCount, kanCount = meldKanCount, zhaoCount = meldZhaoCount;
  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
    const pos0 = sentenceCards.filter(c => c.position === 0);
    const pos1 = sentenceCards.filter(c => c.position === 1);
    const pos2 = sentenceCards.filter(c => c.position === 2);
    while (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
      usedCardIds.add(pos0[0].id); usedCardIds.add(pos1[0].id); usedCardIds.add(pos2[0].id);
      pos0.shift(); pos1.shift(); pos2.shift();
      sentenceCount++;
    }
  }

  const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
  const counts = {};
  for (const card of remainingCards) counts[card.character] = (counts[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(counts)) {
    if (count >= 4) { zhaoCount++; remainingCards.filter(c => c.character === char).forEach(c => usedCardIds.add(c.id)); }
    else if (count === 3) { kanCount++; remainingCards.filter(c => c.character === char).forEach(c => usedCardIds.add(c.id)); }
  }

  const finalRemaining = hand.filter(c => !usedCardIds.has(c.id));
  const pairs = [], singles = [];
  const finalCounts = {};
  for (const card of finalRemaining) finalCounts[card.character] = (finalCounts[card.character] || 0) + 1;
  for (const [char, count] of Object.entries(finalCounts)) {
    if (count === 2) pairs.push(finalRemaining.find(c => c.character === char));
    else if (count === 1) singles.push(finalRemaining.find(c => c.character === char));
  }

  return { sentenceCount, kanCount, zhaoCount, pairs, singles, totalGroups: sentenceCount + kanCount + zhaoCount };
}

function calculateXiangTingShu(hand, melds) {
  const { sentenceCount, kanCount, zhaoCount, pairs, singles, totalGroups } = analyzeHandGroups(hand, melds);
  if (pairs.length >= 9 && singles.length <= 2) return singles.length === 0 ? 0 : singles.length;
  if (totalGroups >= 6 && singles.length === 1) return 1;
  if (totalGroups === 5 && pairs.length >= 2) return 1;
  if (totalGroups === 5 && pairs.length === 1) return 2;
  if (totalGroups === 4) return 3;
  if (totalGroups === 3) return 4;
  return Math.max(1, 6 - totalGroups);
}

function findTingCards(hand, melds = []) {
  const tingCards = [];
  for (const char of ALL_CHARACTERS) {
    const testCard = createCard(char);
    const testHand = [...hand.map(c => ({...c})), testCard];
    if (checkHu(testHand, melds).canHu) tingCards.push(char);
  }
  return tingCards;
}

function countRemainingCards(char) {
  return 4; // 简化
}

// 测试不同参数组合
function testParams(params, numGames = 500) {
  const { sameFour, sameThree, sameTwo, single, tingImprovement, makesTing, tingWidth, nearTing, specialCard, specialSentence } = params;

  function selectAIDiscard(player) {
    const melds = player.melds || [];
    const hand = player.hand;

    if (checkHu(hand, melds).canHu) return 0;

    const currentXT = calculateXiangTingShu(hand, melds);
    const currentTingResult = findTingCards(hand, melds);
    const isCurrentlyTing = currentTingResult.length > 0;

    const counts = {};
    for (const card of hand) counts[card.character] = (counts[card.character] || 0) + 1;

    const scoredCards = [];
    for (let i = 0; i < hand.length; i++) {
      const card = hand[i];
      const tempHand = hand.filter((_, idx) => idx !== i);
      const afterXT = calculateXiangTingShu(tempHand, melds);
      const tingImprovementVal = currentXT - afterXT;
      const afterTingResult = findTingCards(tempHand, melds);
      const willBeTing = afterTingResult.length > 0;

      let score = 0;
      const sameCharCount = counts[card.character];

      if (sameCharCount >= 4) score += sameFour;
      else if (sameCharCount === 3) score += sameThree;
      else if (sameCharCount === 2) score += sameTwo;
      else score += single;

      if (card.character === '福' || card.character === '寿' || card.character === '禄') score += specialCard;
      if (card.sentence === 1 || card.sentence === 8) score += specialSentence;

      if (tingImprovementVal > 0) score += tingImprovementVal * tingImprovement;
      if (willBeTing && !isCurrentlyTing) {
        score += makesTing;
        score += afterTingResult.length * tingWidth;
      }
      if (currentXT <= 2 && sameCharCount === 1) {
        const hasPair = hand.some(c => c.character === card.character && c.id !== card.id);
        const hasAdjacent = hand.some(c => c.sentence === card.sentence && Math.abs(c.position - card.position) === 1);
        if (!hasPair && !hasAdjacent) score += nearTing;
      }
      if (currentXT === 1) score += nearTing;

      scoredCards.push({ card, index: i, score, makesTing: willBeTing && !isCurrentlyTing });
    }

    const makesTingCards = scoredCards.filter(c => c.makesTing);
    if (makesTingCards.length > 0) {
      makesTingCards.sort((a, b) => b.score - a.score);
      return makesTingCards[0].index;
    }

    scoredCards.sort((a, b) => b.score - a.score);
    return scoredCards[0].index;
  }

  function simulateGame() {
    let totalHu = 0, totalTing = 0;
    for (let g = 0; g < numGames; g++) {
      const deck = [];
      for (const char of ALL_CHARACTERS) for (let i = 0; i < 4; i++) deck.push(createCard(char));
      shuffleArray(deck);

      const players = [
        { name: 'AI', hand: [], melds: [], isTing: false },
        { name: '对手1', hand: [], melds: [], isTing: false },
        { name: '对手2', hand: [], melds: [], isTing: false },
        { name: '对手3', hand: [], melds: [], isTing: false }
      ];

      for (let i = 0; i < 16; i++) {
        for (const player of players) {
          if (deck.length > 0) player.hand.push(deck.pop());
        }
      }

      let lastDiscardedCard = null, lastDiscardPlayer = -1;
      let turn = 0;

      while (turn < 300 && deck.length > 0) {
        turn++;
        for (let p = 0; p < 4; p++) {
          const player = players[p];
          if (player.hand.length === 0) continue;

          if (p === 0) {
            if (lastDiscardedCard && lastDiscardPlayer !== p) {
              const pengCount = player.hand.filter(c => c.character === lastDiscardedCard.character).length;
              if (pengCount >= 2 && Math.random() < 0.6) {
                const pengCards = player.hand.filter(c => c.character === lastDiscardedCard.character).slice(0, 2);
                player.hand = player.hand.filter(c => !pengCards.some(pc => pc.id === c.id));
                player.melds.push({ type: 'triplet', cards: [...pengCards, lastDiscardedCard], huValue: 2 });
                if (deck.length > 0) player.hand.push(deck.pop());
                continue;
              }
            }

            const discardIndex = selectAIDiscard(player);
            if (discardIndex < 0 || discardIndex >= player.hand.length) discardIndex = 0;
            const discardedCard = player.hand.splice(discardIndex, 1)[0];
            lastDiscardedCard = discardedCard;
            lastDiscardPlayer = p;

            if (deck.length > 0) player.hand.push(deck.pop());

            if (checkHu(player.hand, player.melds).canHu) { totalHu++; totalTing++; break; }

            if (!player.isTing) {
              const tingCards = findTingCards(player.hand, player.melds);
              if (tingCards.length > 0) { totalTing++; player.isTing = true; }
            }

          } else {
            const counts = {};
            for (const card of player.hand) counts[card.character] = (counts[card.character] || 0) + 1;
            let discardIdx = 0, minCount = Infinity;
            for (let i = 0; i < player.hand.length; i++) {
              if (counts[player.hand[i].character] < minCount) { minCount = counts[player.hand[i].character]; discardIdx = i; }
            }
            const discardedCard = player.hand.splice(discardIdx, 1)[0];
            lastDiscardedCard = discardedCard;
            lastDiscardPlayer = p;
            if (deck.length > 0) player.hand.push(deck.pop());
          }
        }
      }
    }
    return { hu: totalHu, ting: totalTing };
  }

  const result = simulateGame();
  return { huRate: (result.hu / numGames * 100).toFixed(1), tingRate: (result.ting / numGames * 100).toFixed(1) };
}

// 参数组合测试
const paramSets = [
  { name: '基准', sameFour: 200, sameThree: 120, sameTwo: 50, single: -40, tingImprovement: 1000, makesTing: 2000, tingWidth: 100, nearTing: 300, specialCard: 50, specialSentence: 30 },
  { name: 'A:更高中', sameFour: 200, sameThree: 150, sameTwo: 50, single: -40, tingImprovement: 1000, makesTing: 2000, tingWidth: 100, nearTing: 300, specialCard: 50, specialSentence: 30 },
  { name: 'B:听牌宽', sameFour: 200, sameThree: 120, sameTwo: 50, single: -40, tingImprovement: 1000, makesTing: 2000, tingWidth: 150, nearTing: 300, specialCard: 50, specialSentence: 30 },
  { name: 'C:更激进', sameFour: 180, sameThree: 100, sameTwo: 40, single: -30, tingImprovement: 1200, makesTing: 2500, tingWidth: 120, nearTing: 400, specialCard: 60, specialSentence: 40 },
  { name: 'D:向听优', sameFour: 200, sameThree: 120, sameTwo: 50, single: -40, tingImprovement: 1500, makesTing: 2000, tingWidth: 100, nearTing: 300, specialCard: 50, specialSentence: 30 },
  { name: 'E:特殊句', sameFour: 200, sameThree: 120, sameTwo: 50, single: -40, tingImprovement: 1000, makesTing: 2000, tingWidth: 100, nearTing: 300, specialCard: 50, specialSentence: 50 },
  { name: 'F:综合1', sameFour: 250, sameThree: 150, sameTwo: 60, single: -30, tingImprovement: 1200, makesTing: 2200, tingWidth: 110, nearTing: 350, specialCard: 60, specialSentence: 40 },
  { name: 'G:综合2', sameFour: 220, sameThree: 140, sameTwo: 55, single: -35, tingImprovement: 1100, makesTing: 2100, tingWidth: 105, nearTing: 320, specialCard: 55, specialSentence: 35 },
];

console.log('========================================');
console.log('  困难模式AI参数优化测试');
console.log('========================================\n');

const startTime = Date.now();

for (const params of paramSets) {
  const result = testParams(params, 500);
  console.log(`${params.name.padEnd(10)} 胡牌率: ${result.huRate}%  听牌率: ${result.tingRate}%`);
}

console.log(`\n总耗时: ${((Date.now() - startTime) / 1000).toFixed(1)}秒`);
