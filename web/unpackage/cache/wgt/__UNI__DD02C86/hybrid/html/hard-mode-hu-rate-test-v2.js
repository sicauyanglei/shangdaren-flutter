// 困难模式AI胡牌率测试 - 改进版
// 优化AI策略，提高胡牌率

const ALL_CHARACTERS = ['上', '大', '人', '丘', '乙', '己', '化', '三', '千', '七', '十', '土', '尔', '小', '生', '八', '九', '子', '佳', '作', '亡', '福', '禄', '寿'];

// 牌的句子和位置信息
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

let gameSettings = { difficulty: 'hard' };

function createCard(char) {
  const info = cardMap[char] || {s:0,p:0,c:'black'};
  return { character: char, sentence: info.s, position: info.p, color: info.c, id: Math.random().toString(36).substr(2, 9) };
}

function createHand(chars) {
  return chars.split('').map(c => createCard(c));
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

  // 1. 移除完整的句
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

  // 2. 移除招（4张相同）
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

  // 3. 移除坎（3张相同）
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

  // 4. 处理对子
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

  if (zhaoCount >= 6) {
    return { type: 'kuChongTaiHu', name: '库冲太胡', multiplier: { zimo: 8 } };
  }
  if (zhaoCount >= 5 && kanCount >= 1) {
    return { type: 'kuChongTaiKa', name: '库冲太卡', multiplier: { zimo: 6 } };
  }
  if (isQing && zhaoCount >= 5) {
    return { type: 'qingKuChongTaiHu', name: '清库冲太胡', multiplier: { zimo: 10 } };
  }
  if (kanCount >= 6) {
    return { type: 'kuHu', name: '库胡', multiplier: { zimo: 4 } };
  }
  if (kanCount >= 5) {
    return { type: 'taiHu', name: '太胡', multiplier: { zimo: 3 } };
  }
  if (kanCount >= 4) {
    return { type: 'chongTaiHu', name: '冲太胡', multiplier: { zimo: 2 } };
  }
  if (kanCount >= 3) {
    return { type: 'kaHu', name: '卡胡', multiplier: { zimo: 1.5 } };
  }

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

// ========== 改进的向听数计算 ==========

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

  // 计算完整句子
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

  // 计算招和坎
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

  // 听牌需要：4完整句+2张散牌 或 5完整句
  // 或者：6组+1张单张

  // 九对半斤听
  if (pairs.length >= 9 && singles.length <= 2) {
    return singles.length === 0 ? 0 : singles.length;
  }

  // 六组一单
  if (totalGroups >= 6 && singles.length === 1) {
    return 1;
  }

  // 五组两对
  if (totalGroups === 5 && pairs.length >= 2) {
    return 1;
  }
  if (totalGroups === 5 && pairs.length === 1) {
    return 2;
  }

  // 四组听牌
  if (totalGroups === 4) {
    return 3;
  }

  // 三组需要4张
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

function countRemainingCards(char, discardedChars = []) {
  let remaining = 4;
  for (const c of discardedChars) {
    if (c === char) remaining--;
  }
  return Math.max(0, remaining);
}

// ========== 改进的AI出牌策略 ==========

function selectAIDiscardHard(player, discardedChars = []) {
  const melds = player.melds || [];
  const hand = player.hand;

  const currentXT = calculateXiangTingShu(hand, melds);
  const currentTingResult = findTingCards(hand, melds);
  const isCurrentlyTing = currentTingResult.length > 0;

  // 分析句子完整度
  const sentenceCompleteness = {};
  for (let s = 1; s <= 8; s++) {
    const sentenceCards = hand.filter(c => c.sentence === s);
    const positions = new Set(sentenceCards.map(c => c.position));
    const posCount = positions.size;
    sentenceCompleteness[s] = {
      count: sentenceCards.length,
      positions: posCount,
      isComplete: posCount === 3,
      isNearlyComplete: posCount === 2,
      missingPositions: [0, 1, 2].filter(p => !positions.has(p))
    };
  }

  // 计算手牌字数统计
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

    // 计算听牌概率
    let tingProbAfter = 0;
    if (willBeTing) {
      for (const char of afterTingResult) {
        const remaining = countRemainingCards(char, discardedChars);
        tingProbAfter += remaining * 0.55;
      }
      tingProbAfter = Math.min(1, tingProbAfter);
    }

    let tingProbCurrent = 0;
    if (isCurrentlyTing) {
      for (const char of currentTingResult) {
        const remaining = countRemainingCards(char, discardedChars);
        tingProbCurrent += remaining * 0.55;
      }
      tingProbCurrent = Math.min(1, tingProbCurrent);
    }

    let baseScore = 0;

    // ========== 改进的评分系统 ==========

    // 1. 相同字符数量评分 - 优先保留3-4张相同的牌（利于形成坎和招）
    const sameCharCount = counts[card.character];
    if (sameCharCount >= 4) {
      baseScore += 100; // 四张相同，利于形成招
    } else if (sameCharCount === 3) {
      baseScore += 70; // 三张相同，利于形成坎
    } else if (sameCharCount === 2) {
      baseScore += 30; // 两张相同，保留对子
    } else {
      baseScore -= 20; // 单张，优先打出
    }

    // 2. 句子完整性评分
    const sentenceInfo = sentenceCompleteness[card.sentence];
    if (sentenceInfo.isComplete) {
      baseScore += 50; // 完整句子，保留
    } else if (sentenceInfo.isNearlyComplete && sentenceInfo.count >= 2) {
      // 接近完整的句子，只打出缺失位置的牌
      const isMissingCard = sentenceInfo.missingPositions.includes(card.position);
      if (isMissingCard) {
        baseScore += 40; // 这张牌是缺失的，保留
      } else {
        baseScore -= 30; // 这张牌不是缺失的，可以打出
      }
    }

    // 3. 特殊牌价值（福禄寿等）
    if (card.character === '福' || card.character === '寿' || card.character === '禄') {
      baseScore += 30;
    }

    // 4. 听牌改善评分 - 核心优化
    if (tingImprovement > 0) {
      baseScore += tingImprovement * 400;
    }

    // 5. 打出后能听牌，大幅加分
    if (willBeTing && !isCurrentlyTing) {
      baseScore += 1000;
    }

    // 6. 听牌时优化听牌概率
    if (isCurrentlyTing && tingProbAfter > tingProbCurrent) {
      baseScore += (tingProbAfter - tingProbCurrent) * 600;
    }

    // 7. 快听牌时（向听数<=2），优先打孤张
    if (currentXT <= 2 && sameCharCount === 1) {
      // 检查是否有对子或相邻牌
      const hasPair = hand.some(c => c.character === card.character && c.id !== card.id);
      const hasAdjacent = hand.some(c => c.sentence === card.sentence && Math.abs(c.position - card.position) === 1);

      if (!hasPair && !hasAdjacent) {
        baseScore += 200;
      }
    }

    // 8. 向听数很低时（1），优先打能接近听牌的牌
    if (currentXT === 1) {
      baseScore += 250;
    }

    // 9. 牌池已空的牌优先打
    const remainingInDeck = countRemainingCards(card.character, discardedChars);
    if (remainingInDeck === 0) {
      baseScore += 50;
    }

    scoredCards.push({
      card,
      index: i,
      score: baseScore,
      tingImprovement,
      tingProbAfter,
      makesTing: willBeTing && !isCurrentlyTing
    });
  }

  // 优先选择打出后能听牌的牌
  const makesTingCards = scoredCards.filter(c => c.makesTing);
  if (makesTingCards.length > 0) {
    makesTingCards.sort((a, b) => b.tingProbAfter - a.tingProbAfter);
    return makesTingCards[0].index;
  }

  // 听牌时优先选择听牌概率最高的牌
  if (isCurrentlyTing) {
    scoredCards.sort((a, b) => b.tingProbAfter - a.tingProbAfter);
    return scoredCards[0].index;
  }

  // 未听牌时，按听牌改善和分数排序
  scoredCards.sort((a, b) => {
    if (b.tingImprovement !== a.tingImprovement) return b.tingImprovement - a.tingImprovement;
    return b.score - a.score;
  });

  return scoredCards[0].index;
}

// ========== AI碰牌判断（优化）==========

function shouldAIPeng(player, card) {
  const hand = player.hand || [];
  const sameCharCount = hand.filter(c => c.character === card.character).length;

  // 如果有三张相同，碰牌可以形成坎，利于听牌
  if (sameCharCount >= 3) {
    const tempHand = hand.filter(c => c.character !== card.character);
    const afterXT = calculateXiangTingShu(tempHand, player.melds || []);
    const currentXT = calculateXiangTingShu(hand, player.melds || []);

    // 碰牌后向听数不增加才碰
    if (afterXT <= currentXT) {
      return true;
    }
  }

  return sameCharCount >= 2;
}

// ========== AI吃牌判断（优化）==========

function shouldAIChiHard(player, card) {
  const hand = player.hand || [];
  const melds = player.melds || [];

  // 找出可以吃的牌组合
  const chiOptions = [];
  const s = card.sentence;
  const p = card.position;

  // 找出能形成完整句子的吃牌组合
  for (let offset1 = -1; offset1 <= 1; offset1++) {
    for (let offset2 = -1; offset2 <= 1; offset2++) {
      if (offset1 === 0 && offset2 === 0) continue;
      if (offset1 === offset2) continue;

      const pos1 = p + offset1;
      const pos2 = p + offset2;

      if (pos1 < 0 || pos1 > 2 || pos2 < 0 || pos2 > 2) continue;
      if (pos1 === pos2) continue;

      const char1 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === pos1);
      const char2 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === pos2);

      if (!char1 || !char2) continue;

      // 检查手牌是否有这两张牌
      const has1 = hand.some(c => c.character === char1);
      const has2 = hand.some(c => c.character === char2);

      if (has1 && has2) {
        chiOptions.push({ char1, char2, sentence: s });
      }
    }
  }

  if (chiOptions.length === 0) return false;

  const currentXT = calculateXiangTingShu(hand, melds);

  // 评估每个吃牌选项
  let bestScore = -Infinity;
  for (const opt of chiOptions) {
    const chiHand = hand.filter(c => c.character !== opt.char1 && c.character !== opt.char2);
    const afterXT = calculateXiangTingShu(chiHand, melds);

    let score = 0;
    if (afterXT < currentXT) score += 500;
    if (afterXT === 0) score += 800; // 吃牌后听牌
    if (opt.sentence === 1 || opt.sentence === 8) score += 100; // 特殊句加分

    if (score > bestScore) {
      bestScore = score;
    }
  }

  return bestScore > 0;
}

// ========== 模拟游戏 ==========

function simulateGameHardMode(gameId) {
  const stats = {
    gameId,
    huCount: 0,
    zimoCount: 0,
    dianpaoCount: 0,
    tingCount: 0,
    turnsPlayed: 0,
    huRate: 0,
    reachedTing: false,
    huTypes: {}
  };

  // 创建牌堆
  const deck = [];
  for (const char of ALL_CHARACTERS) {
    for (let i = 0; i < 4; i++) {
      deck.push(createCard(char));
    }
  }
  shuffleArray(deck);

  // 初始化玩家
  const players = [
    { name: 'AI', hand: [], melds: [], isTing: false, tingCards: [] },
    { name: '对手1', hand: [], melds: [], isTing: false },
    { name: '对手2', hand: [], melds: [], isTing: false },
    { name: '对手3', hand: [], melds: [], isTing: false }
  ];

  // 发牌
  for (let i = 0; i < 16; i++) {
    for (const player of players) {
      if (deck.length > 0) {
        player.hand.push(deck.pop());
      }
    }
  }

  const discardedChars = [];
  let turn = 0;
  const maxTurns = 300;

  while (turn < maxTurns && deck.length > 0) {
    turn++;

    for (let p = 0; p < 4; p++) {
      const player = players[p];

      if (player.hand.length === 0) continue;

      // AI玩家
      if (p === 0) {
        stats.turnsPlayed++;

        // 检查胡牌
        const huResult = checkHu(player);
        if (huResult.canHu) {
          stats.huCount++;
          stats.huTypes[huResult.huType.type] = (stats.huTypes[huResult.huType.type] || 0) + 1;
          return stats;
        }

        // 检查听牌
        if (!stats.reachedTing) {
          const tingCards = findTingCards(player.hand, player.melds);
          if (tingCards.length > 0) {
            stats.tingCount++;
            stats.reachedTing = true;
            player.isTing = true;
            player.tingCards = tingCards;
          }
        }

        // 出牌
        const discardIndex = selectAIDiscardHard(player, discardedChars);
        if (discardIndex < 0 || discardIndex >= player.hand.length) {
          discardIndex = 0;
        }
        const discardedCard = player.hand.splice(discardIndex, 1)[0];
        discardedChars.push(discardedCard.character);

        // 摸牌
        if (deck.length > 0 && player.hand.length < 20) {
          player.hand.push(deck.pop());
        }

      } else {
        // 对手简单策略
        const counts = {};
        for (const card of player.hand) {
          counts[card.character] = (counts[card.character] || 0) + 1;
        }

        // 优先打单张
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

        // 对手摸牌
        if (deck.length > 0 && player.hand.length < 20) {
          player.hand.push(deck.pop());
        }

        // 模拟对手碰牌
        const pengCount = player.hand.filter(c => c.character === discardedCard.character).length;
        if (pengCount >= 2 && Math.random() < 0.4) {
          const pengCards = player.hand.filter(c => c.character === discardedCard.character).slice(0, 2);
          player.hand = player.hand.filter(c => c.character !== discardedCard.character || !pengCards.some(pc => pc.id === c.id));
          player.melds.push({ type: 'triplet', cards: [...pengCards, discardedCard], huValue: 2 });
        }

        // 模拟对手吃牌
        if (shouldAIChiHard(player, discardedCard) && Math.random() < 0.3) {
          const s = discardedCard.sentence;
          let chi1, chi2;
          if (discardedCard.position === 0) {
            chi1 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 1);
            chi2 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 2);
          } else if (discardedCard.position === 1) {
            chi1 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 0);
            chi2 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 2);
          } else {
            chi1 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 0);
            chi2 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 1);
          }

          const chiCards = player.hand.filter(c => c.character === chi1 || c.character === chi2);
          if (chiCards.length >= 2) {
            player.hand = player.hand.filter(c => !chiCards.some(cc => cc.id === c.id));
            player.melds.push({ type: 'sequence', cards: [...chiCards, discardedCard], huValue: 0 });
          }
        }
      }
    }
  }

  return stats;
}

// ========== 主测试 ==========

async function runHuRateTest(numGames = 500) {
  console.log('========================================');
  console.log('  困难模式AI胡牌率测试 v2');
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

    const gameStats = simulateGameHardMode(i);

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

// 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runHuRateTest };
}
