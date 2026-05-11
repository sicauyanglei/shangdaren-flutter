// 困难模式AI胡牌率优化测试
// 基于实际game.js的evaluateCardExtreme函数

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

let gameState = { deck: [], difficulty: 'hard' };
let gameSettings = { difficulty: 'hard' };

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

// ========== 核心胡牌检测算法 ==========

function calculateHuCount(hand, melds, huCard = null) {
  hand = hand || [];
  melds = melds || [];
  let hu = 0;

  for (const meld of melds) {
    hu += meld.huValue || 0;
  }

  const cards = [...hand];
  if (huCard) cards.push(huCard);

  const usedCardIds = new Set();

  // 移除完整的句
  let foundSentence = true;
  while (foundSentence) {
    foundSentence = false;
    for (let sentence = 1; sentence <= 8; sentence++) {
      const sentenceCards = cards.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
      const pos0Cards = sentenceCards.filter(c => c.position === 0);
      const pos1Cards = sentenceCards.filter(c => c.position === 1);
      const pos2Cards = sentenceCards.filter(c => c.position === 2);

      if (pos0Cards.length > 0 && pos1Cards.length > 0 && pos2Cards.length > 0) {
        foundSentence = true;
        const isJingJu = sentence === 1 || sentence === 8;
        const hasShang = pos0Cards[0].character === '上' || pos1Cards[0].character === '上' || pos2Cards[0].character === '上';
        const hasFu = pos0Cards[0].character === '福' || pos1Cards[0].character === '福' || pos2Cards[0].character === '福';

        if (isJingJu && (hasShang || hasFu)) {
          hu += 4;
        }
        usedCardIds.add(pos0Cards[0].id);
        usedCardIds.add(pos1Cards[0].id);
        usedCardIds.add(pos2Cards[0].id);
      }
    }
  }

  // 移除招
  const remainingAfterJu = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterJu = {};
  for (const card of remainingAfterJu) {
    countsAfterJu[card.character] = (countsAfterJu[card.character] || 0) + 1;
  }

  for (const [char, count] of Object.entries(countsAfterJu)) {
    if (count >= 4) {
      const isJingZhao = char === '上' || char === '福';
      hu += isJingZhao ? 16 : 6;
      const zhaoCards = remainingAfterJu.filter(c => c.character === char);
      zhaoCards.forEach(c => usedCardIds.add(c.id));
    }
  }

  // 移除坎
  const remainingAfterZhao = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterZhao = {};
  for (const card of remainingAfterZhao) {
    countsAfterZhao[card.character] = (countsAfterZhao[card.character] || 0) + 1;
  }

  for (const [char, count] of Object.entries(countsAfterZhao)) {
    if (count >= 3) {
      const isJingKan = char === '上' || char === '福';
      hu += isJingKan ? 12 : 3;
      const kanCards = remainingAfterZhao.filter(c => c.character === char);
      kanCards.slice(0, 3).forEach(c => usedCardIds.add(c.id));
    }
  }

  // 对子
  const remainingAfterKan = cards.filter(c => !usedCardIds.has(c.id));
  const countsAfterKan = {};
  for (const card of remainingAfterKan) {
    countsAfterKan[card.character] = (countsAfterKan[card.character] || 0) + 1;
  }

  for (const [char, count] of Object.entries(countsAfterKan)) {
    if (count >= 2) {
      const isJinDui = char === '上' || char === '福';
      hu += isJinDui ? 8 : 0;
      const duiCards = remainingAfterKan.filter(c => c.character === char);
      duiCards.slice(0, 2).forEach(c => usedCardIds.add(c.id));
    }
  }

  return hu;
}

function detectHuType(hand, melds, huCount) {
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  let isQing = true;
  for (const card of hand) {
    if (card.character === '上' || card.character === '福') {
      isQing = false;
      break;
    }
  }

  const zhaoCount = Object.values(counts).filter(c => c >= 4).length;
  const kanCount = Object.values(counts).filter(c => c >= 3).length;

  if (zhaoCount >= 6) return { type: 'kuChongTaiHu', name: '库冲太胡', multiplier: { zimo: 8 } };
  if (zhaoCount >= 5 && kanCount >= 1) return { type: 'kuChongTaiKa', name: '库冲太卡', multiplier: { zimo: 6 } };
  if (isQing && zhaoCount >= 5) return { type: 'qingKuChongTaiHu', name: '清库冲太胡', multiplier: { zimo: 10 } };
  if (kanCount >= 6) return { type: 'kuHu', name: '库胡', multiplier: { zimo: 4 } };
  if (kanCount >= 5) return { type: 'taiHu', name: '太胡', multiplier: { zimo: 3 } };
  if (kanCount >= 4) return { type: 'chongTaiHu', name: '冲太胡', multiplier: { zimo: 2 } };
  if (kanCount >= 3) return { type: 'kaHu', name: '卡胡', multiplier: { zimo: 1.5 } };

  return { type: 'puTongHu', name: '普通胡', multiplier: { zimo: 1 } };
}

function checkHu(player, extraCard = null) {
  const playerHand = player.hand || [];
  const playerMelds = player.melds || [];
  const hand = [...playerHand];
  const huCount = calculateHuCount(hand, playerMelds, extraCard);

  const fullHand = extraCard ? [...playerHand, extraCard] : [...playerHand];
  const huType = detectHuType(fullHand, playerMelds, huCount);

  const specialHuTypes = ['kuHu', 'qingKuHu', 'kuTaiHu', 'kuChongTaiHu', 'kuChongTaiKa', 'qingKuTaiKa', 'qingKuTaiHu', 'qingKuChongTaiHu', 'qingKuChongTaiKa'];
  const isSpecialHu = specialHuTypes.includes(huType.type);

  const canHu = (isSpecialHu || huCount >= 11) && huType.type !== 'none';

  return { canHu, huCount, huType };
}

// ========== 向听数计算 ==========

function analyzeHandGroups(hand, melds) {
  const meldSentenceCount = (melds || []).filter(m => m.type === 'sequence').length;
  const meldKanCount = (melds || []).filter(m => m.type === 'triplet').length;
  const meldZhaoCount = (melds || []).filter(m => m.type === 'quartet').length;

  const usedCardIds = new Set();
  for (const meld of melds || []) {
    for (const card of meld.cards) {
      usedCardIds.add(card.id);
    }
  }

  let sentenceCount = meldSentenceCount;
  let kanCount = meldKanCount;
  let zhaoCount = meldZhaoCount;

  for (let sentence = 1; sentence <= 8; sentence++) {
    const sentenceCards = hand.filter(c => c.sentence === sentence && !usedCardIds.has(c.id));
    const pos0 = sentenceCards.filter(c => c.position === 0);
    const pos1 = sentenceCards.filter(c => c.position === 1);
    const pos2 = sentenceCards.filter(c => c.position === 2);

    while (pos0.length > 0 && pos1.length > 0 && pos2.length > 0) {
      usedCardIds.add(pos0[0].id);
      usedCardIds.add(pos1[0].id);
      usedCardIds.add(pos2[0].id);
      pos0.shift();
      pos1.shift();
      pos2.shift();
      sentenceCount++;
    }
  }

  const remainingCards = hand.filter(c => !usedCardIds.has(c.id));
  const counts = {};
  for (const card of remainingCards) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  for (const [char, count] of Object.entries(counts)) {
    if (count >= 4) {
      zhaoCount++;
      const cards = remainingCards.filter(c => c.character === char);
      cards.forEach(c => usedCardIds.add(c.id));
    } else if (count === 3) {
      kanCount++;
      const cards = remainingCards.filter(c => c.character === char);
      cards.forEach(c => usedCardIds.add(c.id));
    }
  }

  const finalRemaining = hand.filter(c => !usedCardIds.has(c.id));
  const pairs = [];
  const singles = [];

  const finalCounts = {};
  for (const card of finalRemaining) {
    finalCounts[card.character] = (finalCounts[card.character] || 0) + 1;
  }

  for (const [char, count] of Object.entries(finalCounts)) {
    if (count === 2) {
      const card = finalRemaining.find(c => c.character === char);
      pairs.push(card);
    } else if (count === 1) {
      const card = finalRemaining.find(c => c.character === char);
      singles.push(card);
    }
  }

  return {
    sentenceCount,
    kanCount,
    zhaoCount,
    pairs,
    singles,
    totalGroups: sentenceCount + kanCount + zhaoCount
  };
}

function calculateXiangTingShu(hand, melds) {
  const analysis = analyzeHandGroups(hand, melds);
  const { sentenceCount, kanCount, zhaoCount, pairs, singles, totalGroups } = analysis;

  if (pairs.length >= 9 && singles.length <= 2) {
    return singles.length === 0 ? 0 : singles.length;
  }

  if (totalGroups >= 6 && singles.length === 1) {
    return 1;
  }

  if (totalGroups === 5 && pairs.length >= 2) {
    return 1;
  }
  if (totalGroups === 5 && pairs.length === 1) {
    return 2;
  }

  if (totalGroups === 4) {
    return 3;
  }

  if (totalGroups === 3) {
    return 4;
  }

  return Math.max(1, 6 - totalGroups);
}

function findTingCards(hand, melds = []) {
  const tingCards = [];
  for (const char of ALL_CHARACTERS) {
    const testCard = createCard(char);
    const testHand = [...hand.map(c => ({...c})), testCard];
    const huResult = checkHu({ hand: testHand, melds });
    if (huResult.canHu) {
      tingCards.push(char);
    }
  }
  return tingCards;
}

function countRemainingCards(char) {
  // 简化：假设还有4张
  return 4;
}

// ========== 优化版AI出牌策略 ==========

function selectAIDiscardOptimized(player, discardedChars = []) {
  const melds = player.melds || [];
  const hand = player.hand;

  const huResult = checkHu(player);
  if (huResult.canHu) {
    console.log('已胡牌');
  }

  const currentXT = calculateXiangTingShu(hand, melds);
  const currentTingResult = findTingCards(hand, melds);
  const isCurrentlyTing = currentTingResult.length > 0;

  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  const scoredCards = [];
  for (let i = 0; i < hand.length; i++) {
    const card = hand[i];
    const tempHand = hand.filter((_, idx) => idx !== i);

    const afterXT = calculateXiangTingShu(tempHand, melds);
    const tingImprovement = currentXT - afterXT;

    const afterTingResult = findTingCards(tempHand, melds);
    const willBeTing = afterTingResult.length > 0;

    let tingProbAfter = 0;
    if (willBeTing) {
      for (const char of afterTingResult) {
        tingProbAfter += countRemainingCards(char) * 0.6;
      }
      tingProbAfter = Math.min(1, tingProbAfter);
    }

    let tingProbCurrent = 0;
    if (isCurrentlyTing) {
      for (const char of currentTingResult) {
        tingProbCurrent += countRemainingCards(char) * 0.6;
      }
      tingProbCurrent = Math.min(1, tingProbCurrent);
    }

    let score = 0;

    // ========== 核心优化：分数越高越好 ==========

    // 1. 相同字符数量评分
    const sameCharCount = counts[card.character];
    if (sameCharCount >= 4) {
      score += 200; // 保留形成招
    } else if (sameCharCount === 3) {
      score += 120; // 保留形成坎
    } else if (sameCharCount === 2) {
      score += 50; // 保留对子
    } else {
      score -= 40; // 单张优先打出
    }

    // 2. 特殊牌（福禄寿）加分
    if (card.character === '福' || card.character === '寿' || card.character === '禄') {
      score += 50;
    }

    // 3. 向听数改善评分（核心！）
    if (tingImprovement > 0) {
      score += tingImprovement * 1000; // 向听数改善是听牌的关键
    }

    // 4. 打出后能听牌，大幅加分
    if (willBeTing && !isCurrentlyTing) {
      score += 2000;

      // 听牌概率加权
      score += tingProbAfter * 500;

      // 听牌宽度加权
      score += afterTingResult.length * 100;
    }

    // 5. 听牌时优化听牌概率
    if (isCurrentlyTing && tingProbAfter > tingProbCurrent) {
      score += (tingProbAfter - tingProbCurrent) * 800;
    }

    // 6. 听牌时选择听牌概率最高的牌
    if (isCurrentlyTing) {
      score += tingProbAfter * 600;
    }

    // 7. 接近听牌时（向听数<=2），优先打孤张
    if (currentXT <= 2 && sameCharCount === 1) {
      const hasPair = hand.some(c => c.character === card.character && c.id !== card.id);
      const hasAdjacent = hand.some(c => c.sentence === card.sentence && Math.abs(c.position - card.position) === 1);
      if (!hasPair && !hasAdjacent) {
        score += 300;
      }
    }

    // 8. 向听数为1时，大幅加分
    if (currentXT === 1) {
      score += 400;
    }

    // 9. 句子完整性评分
    for (let s = 1; s <= 8; s++) {
      const sentenceCards = hand.filter(c => c.sentence === s);
      const positions = new Set(sentenceCards.map(c => c.position));

      if (positions.size === 3) {
        // 完整句子，保留
        if (card.sentence === s) {
          score += 80;
        }
      } else if (positions.size === 2) {
        // 接近完整的句子
        const missingPos = [0, 1, 2].find(p => !positions.has(p));
        if (card.sentence === s && card.position === missingPos) {
          score += 60; // 这张牌是缺失的，保留
        }
      }
    }

    // 10. 牌池已空的牌优先打
    const remainingInDeck = countRemainingCards(card.character);
    if (remainingInDeck === 0) {
      score += 80;
    }

    // 11. 特殊句（第1句、第8句）加分
    if (card.sentence === 1 || card.sentence === 8) {
      score += 30;
    }

    scoredCards.push({
      card,
      index: i,
      score,
      tingImprovement,
      tingProbAfter,
      makesTing: willBeTing && !isCurrentlyTing
    });
  }

  // 优先选择打出后能听牌的牌
  const makesTingCards = scoredCards.filter(c => c.makesTing);
  if (makesTingCards.length > 0) {
    makesTingCards.sort((a, b) => b.score - a.score);
    return makesTingCards[0].index;
  }

  // 听牌时优先选择听牌概率最高的牌
  if (isCurrentlyTing) {
    scoredCards.sort((a, b) => b.tingProbAfter - a.tingProbAfter);
    return scoredCards[0].index;
  }

  // 未听牌时，按分数排序
  scoredCards.sort((a, b) => b.score - a.score);

  return scoredCards[0].index;
}

// ========== 模拟游戏 ==========

function simulateGame(gameId, useOptimized = true) {
  const stats = {
    gameId,
    huCount: 0,
    tingCount: 0,
    turnsPlayed: 0,
    huTypes: {}
  };

  const deck = [];
  for (const char of ALL_CHARACTERS) {
    for (let i = 0; i < 4; i++) {
      deck.push(createCard(char));
    }
  }
  shuffleArray(deck);

  const players = [
    { name: 'AI', hand: [], melds: [], isTing: false },
    { name: '对手1', hand: [], melds: [], isTing: false },
    { name: '对手2', hand: [], melds: [], isTing: false },
    { name: '对手3', hand: [], melds: [], isTing: false }
  ];

  for (let i = 0; i < 16; i++) {
    for (const player of players) {
      if (deck.length > 0) {
        player.hand.push(deck.pop());
      }
    }
  }

  const discardedChars = [];
  let lastDiscardedCard = null;
  let lastDiscardPlayer = -1;
  let turn = 0;
  const maxTurns = 300;

  while (turn < maxTurns && deck.length > 0) {
    turn++;

    for (let p = 0; p < 4; p++) {
      const player = players[p];

      if (player.hand.length === 0) continue;

      if (p === 0) {
        // 处理碰牌
        if (lastDiscardedCard && lastDiscardPlayer !== p) {
          const pengCount = player.hand.filter(c => c.character === lastDiscardedCard.character).length;
          if (pengCount >= 2 && Math.random() < 0.6) {
            const pengCards = player.hand.filter(c => c.character === lastDiscardedCard.character).slice(0, 2);
            player.hand = player.hand.filter(c => !pengCards.some(pc => pc.id === c.id));
            player.melds.push({ type: 'triplet', cards: [...pengCards, lastDiscardedCard], huValue: 2 });

            if (deck.length > 0) {
              player.hand.push(deck.pop());
            }
            continue;
          }
        }

        // 出牌
        const discardIndex = selectAIDiscardOptimized(player, discardedChars);
        if (discardIndex < 0 || discardIndex >= player.hand.length) {
          discardIndex = 0;
        }
        const discardedCard = player.hand.splice(discardIndex, 1)[0];
        discardedChars.push(discardedCard.character);
        lastDiscardedCard = discardedCard;
        lastDiscardPlayer = p;

        // 摸牌
        if (deck.length > 0) {
          player.hand.push(deck.pop());
        }

        // 检查胡牌
        const huResult = checkHu(player);
        if (huResult.canHu) {
          stats.huCount++;
          stats.huTypes[huResult.huType.type] = (stats.huTypes[huResult.huType.type] || 0) + 1;
          return stats;
        }

        // 检查听牌
        if (!player.isTing) {
          const tingCards = findTingCards(player.hand, player.melds);
          if (tingCards.length > 0) {
            stats.tingCount++;
            player.isTing = true;
            player.tingCards = tingCards;
          }
        }

        stats.turnsPlayed++;

      } else {
        // 对手出牌
        const counts = {};
        for (const card of player.hand) {
          counts[card.character] = (counts[card.character] || 0) + 1;
        }

        let discardIdx = 0;
        let minCount = Infinity;
        for (let i = 0; i < player.hand.length; i++) {
          const c = player.hand[i].character;
          if (counts[c] < minCount) {
            minCount = counts[c];
            discardIdx = i;
          }
        }

        const discardedCard = player.hand.splice(discardIdx, 1)[0];
        discardedChars.push(discardedCard.character);
        lastDiscardedCard = discardedCard;
        lastDiscardPlayer = p;

        if (deck.length > 0) {
          player.hand.push(deck.pop());
        }
      }
    }
  }

  return stats;
}

// ========== 主测试 ==========

async function runTest(numGames = 500) {
  console.log('========================================');
  console.log('  困难模式AI优化测试');
  console.log('========================================');
  console.log(`测试局数: ${numGames}`);
  console.log(`开始时间: ${new Date().toLocaleTimeString()}\n`);

  const results = {
    totalGames: numGames,
    huCount: 0,
    tingCount: 0,
    totalTurns: 0,
    huTypes: {}
  };

  const startTime = Date.now();

  for (let i = 0; i < numGames; i++) {
    if (i % 50 === 0) {
      process.stdout.write(`\n进度: ${i}/${numGames}`);
    } else if (i % 10 === 0) {
      process.stdout.write('.');
    }

    const gameStats = simulateGame(i, true);

    results.huCount += gameStats.huCount;
    results.tingCount += gameStats.tingCount;
    results.totalTurns += gameStats.turnsPlayed;

    for (const [type, count] of Object.entries(gameStats.huTypes)) {
      results.huTypes[type] = (results.huTypes[type] || 0) + count;
    }
  }

  const elapsed = Date.now() - startTime;

  console.log('\n\n========================================');
  console.log('  测试结果');
  console.log('========================================');
  console.log(`\n总局数: ${results.totalGames}`);
  console.log(`胡牌局数: ${results.huCount}`);
  console.log(`胡牌率: ${(results.huCount / results.totalGames * 100).toFixed(2)}%`);
  console.log(`听牌率: ${(results.tingCount / results.totalGames * 100).toFixed(2)}%`);
  console.log(`平均回合数: ${(results.totalTurns / results.totalGames).toFixed(1)}`);
  console.log(`总耗时: ${(elapsed / 1000).toFixed(2)}秒`);

  console.log('\n胡牌类型分布:');
  for (const [type, count] of Object.entries(results.huTypes)) {
    console.log(`  ${type}: ${count}次`);
  }

  return results;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runTest };
}
