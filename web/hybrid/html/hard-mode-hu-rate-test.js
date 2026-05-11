// 困难模式AI胡牌率测试
// 模拟真实游戏流程，测试AI的胡牌频率

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

// ========== 核心胡牌检测算法（复制自game.js）==========

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
  // 简化版胡牌类型检测
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

// ========== 向听数计算 ==========

function calculateXiangTingShu(hand, melds) {
  // 计算手牌还需要多少张才能听牌
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  // 计算完整句子数
  let completeSentences = 0;
  for (let s = 1; s <= 8; s++) {
    let has0 = false, has1 = false, has2 = false;
    for (const card of hand) {
      if (card.sentence === s) {
        if (card.position === 0) has0 = true;
        if (card.position === 1) has1 = true;
        if (card.position === 2) has2 = true;
      }
    }
    if (has0 && has1 && has2) completeSentences++;
  }

  // 计算剩余手牌数（不在组合中的）
  const meldCards = new Set();
  for (const meld of melds) {
    for (const card of meld.cards) {
      meldCards.add(card.id);
    }
  }

  const remainingCards = hand.filter(c => !meldCards.has(c.id));
  const remainingCount = remainingCards.length;

  // 听牌需要：4完整句+2张散牌 或 5完整句
  const neededForTing = Math.max(0, 4 - completeSentences) * 3 + Math.max(0, 2 - (remainingCount - (4 - completeSentences) * 3));

  return Math.max(0, neededForTing);
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

// ========== 牌池剩余数量 ==========

function countRemainingCards(char, discardedChars = []) {
  // 基础剩余4张，减去已出现的
  let remaining = 4;
  for (const c of discardedChars) {
    if (c === char) remaining--;
  }
  return Math.max(0, remaining);
}

// ========== AI出牌策略（困难模式）==========

function analyzeAbsoluteSafeCards(hand, player) {
  // 简化版安全牌分析
  const counts = {};
  for (const card of hand) {
    counts[card.character] = (counts[card.character] || 0) + 1;
  }

  const safeCards = [];
  for (const char of ALL_CHARACTERS) {
    if (counts[char] === undefined) {
      safeCards.push({ card: createCard(char), reason: '牌池已空' });
    } else if (counts[char] === 1) {
      safeCards.push({ card: createCard(char), reason: '仅剩1张' });
    }
  }
  return safeCards;
}

function selectAIDiscardHard(player, discardedChars = []) {
  const melds = player.melds || [];
  const hand = player.hand;

  const currentXT = calculateXiangTingShu(hand, melds);
  const safeCards = analyzeAbsoluteSafeCards(hand, player);
  const safeCardIds = new Set(safeCards.map(s => s.card.id));

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

  const currentTingResult = { isTing: currentXT <= 0, tingCards: currentXT <= 0 ? findTingCards(hand, melds) : [] };

  const scoredCards = [];
  for (let i = 0; i < hand.length; i++) {
    const card = hand[i];
    const tempHand = hand.filter((_, idx) => idx !== i);

    const afterXT = calculateXiangTingShu(tempHand, melds);
    const tingImprovement = currentXT - afterXT;

    const afterTingResult = { isTing: afterXT <= 0, tingCards: afterXT <= 0 ? findTingCards(tempHand, melds) : [] };
    let tingProbAfter = 0;
    if (afterTingResult.isTing && afterTingResult.tingCards) {
      for (const char of afterTingResult.tingCards) {
        const remaining = countRemainingCards(char, discardedChars);
        tingProbAfter += remaining * 0.55;
      }
      tingProbAfter = Math.min(1, tingProbAfter);
    }

    let tingProbCurrent = 0;
    if (currentTingResult.isTing && currentTingResult.tingCards) {
      for (const char of currentTingResult.tingCards) {
        const remaining = countRemainingCards(char, discardedChars);
        tingProbCurrent += remaining * 0.55;
      }
      tingProbCurrent = Math.min(1, tingProbCurrent);
    }

    let safetyBonus = 0;
    if (safeCardIds.has(card.id)) {
      safetyBonus = safeCards.find(s => s.card.id === card.id).reason === '牌池已空' ? 300 :
                    safeCards.find(s => s.card.id === card.id).reason === '仅剩1张' ? 150 : 50;
    }

    const sameCharCount = hand.filter(c => c.character === card.character).length;
    const sameSentenceCards = hand.filter(c => c.sentence === card.sentence);
    const sentenceCount = sameSentenceCards.length;

    let baseScore = 0;
    if (sameCharCount >= 3) {
      baseScore = 80;
    } else if (sameCharCount === 2) {
      baseScore = 40;
    }

    const sentenceCards = hand.filter(c => c.sentence === card.sentence && c.id !== card.id);
    const hasPair = sentenceCards.some(c => c.position === card.position);
    const hasAdjacent1 = sentenceCards.some(c => Math.abs(c.position - card.position) === 1);
    const hasAdjacent2 = sentenceCards.some(c => Math.abs(c.position - card.position) === 2);

    if (hasPair) baseScore += 20;
    if (hasAdjacent1) baseScore += 15;
    if (hasAdjacent2) baseScore += 5;

    if (card.isSpecial) baseScore += 60;

    if (tingImprovement > 0) {
      baseScore += tingImprovement * 300;
    }

    if (afterTingResult.isTing && !currentTingResult.isTing) {
      baseScore += 800;
    }

    if (player.isTing && tingProbAfter > tingProbCurrent) {
      baseScore += (tingProbAfter - tingProbCurrent) * 500;
    }

    if (player.isTing && safetyBonus > 0) {
      baseScore += safetyBonus * 0.2;
    }

    const sentenceInfo = sentenceCompleteness[card.sentence];
    if (sentenceInfo.isNearlyComplete && sentenceInfo.count >= 2) {
      baseScore -= 40;
    }

    if (currentXT <= 2 && sameCharCount === 1 && !hasPair && !hasAdjacent1 && !hasAdjacent2) {
      baseScore += 150;
    }

    if (currentXT === 1 && tingImprovement >= 0) {
      baseScore += 200;
    }

    scoredCards.push({
      card,
      index: i,
      score: baseScore,
      tingImprovement,
      safetyBonus,
      tingProbAfter,
      makesTing: afterTingResult.isTing && !currentTingResult.isTing
    });
  }

  // 优先选择打出后能听牌的牌
  const makesTingCards = scoredCards.filter(c => c.makesTing);
  if (makesTingCards.length > 0) {
    makesTingCards.sort((a, b) => b.tingProbAfter - a.tingProbAfter);
    return makesTingCards[0].index;
  }

  if (player.isTing) {
    scoredCards.sort((a, b) => b.tingProbAfter - a.tingProbAfter);
    const best = scoredCards[0];
    const safeTingCards = scoredCards.filter(c => c.safetyBonus > 0);
    if (safeTingCards.length > 0 && best.tingProbAfter - safeTingCards[0].tingProbAfter < 0.3) {
      safeTingCards.sort((a, b) => b.tingProbAfter - a.tingProbAfter);
      return safeTingCards[0].index;
    }
    return best.index;
  }

  scoredCards.sort((a, b) => {
    if (b.tingImprovement !== a.tingImprovement) return b.tingImprovement - a.tingImprovement;
    return b.score - a.score;
  });

  return scoredCards[0].index;
}

// ========== AI吃牌判断（困难模式）==========

function shouldAIChiHard(player, card) {
  const hand = player.hand || [];
  const melds = player.melds || [];
  const chiCards = [];

  // 找出可以吃的牌组合
  for (let s = 1; s <= 8; s++) {
    for (let pos = 0; pos < 3; pos++) {
      const targetChar = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === pos);
      if (!targetChar) continue;

      const neededChars = [];
      if (pos === 0) {
        neededChars.push(ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 1));
        neededChars.push(ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 2));
      } else if (pos === 1) {
        neededChars.push(ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 0));
        neededChars.push(ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 2));
      } else {
        neededChars.push(ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 0));
        neededChars.push(ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 1));
      }

      if (neededChars.every(c => c && hand.some(h => h.character === c))) {
        chiCards.push({ char: card.character, sentence: s, position: pos });
      }
    }
  }

  if (chiCards.length === 0) return false;

  const currentXiangTing = calculateXiangTingShu(hand, melds);
  const currentTingResult = { isTing: currentXiangTing <= 0, tingCards: currentXiangTing <= 0 ? findTingCards(hand, melds) : [] };

  let bestChi = null;
  let bestScore = -Infinity;

  for (const chi of chiCards) {
    const handCopy = hand.map(c => ({...c}));
    const cardCopy = {...card};
    const chiHand = handCopy.filter(c => c.character !== chi.char);
    const chiMelds = melds.map(m => ({...m, cards: m.cards.map(c => ({...c}))}));

    chiMelds.push({
      type: 'sequence',
      cards: [
        handCopy.find(c => c.character === chi.char && !chiMelds.flatMap(m => m.cards).some(gc => gc.id === c.id)) || createCard(chi.char),
        cardCopy
      ],
      huValue: 0
    });

    const afterXT = calculateXiangTingShu(chiHand, chiMelds);
    const afterTingResult = { isTing: afterXT <= 0, tingCards: afterXT <= 0 ? findTingCards(chiHand, chiMelds) : [] };

    let score = 0;
    if (afterXT < currentXiangTing) score += 500;
    if (afterTingResult.isTing && !currentTingResult.isTing) score += 800;
    if (chi.sentence === 1 || chi.sentence === 8) score += 100;

    if (score > bestScore) {
      bestScore = score;
      bestChi = chi;
    }
  }

  return bestChi !== null && bestScore > 0;
}

// ========== AI碰牌判断 ==========

function shouldAIPeng(player, card) {
  const hand = player.hand || [];
  const sameCharCount = hand.filter(c => c.character === card.character).length;
  return sameCharCount >= 2;
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

  // 初始化玩家：1个AI + 3个模拟对手
  const players = [
    { name: 'AI', hand: [], melds: [], isTing: false, tingCards: [] },
    { name: '对手1', hand: [], melds: [], isTing: false },
    { name: '对手2', hand: [], melds: [], isTing: false },
    { name: '对手3', hand: [], melds: [], isTing: false }
  ];

  // 发牌（每人16张）
  for (let i = 0; i < 16; i++) {
    for (const player of players) {
      if (deck.length > 0) {
        player.hand.push(deck.pop());
      }
    }
  }

  const discardedChars = [];
  let turn = 0;
  const maxTurns = 200;

  while (turn < maxTurns && deck.length > 0) {
    turn++;

    for (let p = 0; p < 4; p++) {
      const player = players[p];

      if (player.hand.length === 0) continue;

      // AI玩家（玩家0）
      if (p === 0) {
        stats.turnsPlayed++;

        // 检查胡牌
        const huResult = checkHu(player);
        if (huResult.canHu) {
          stats.huCount++;
          stats.huTypes[huResult.huType.type] = (stats.huTypes[huResult.huType.type] || 0) + 1;
          if (stats.huByDianPao !== undefined) {
            stats.huRate = stats.huCount * 100;
          }
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
        if (deck.length > 0) {
          player.hand.push(deck.pop());
        }

      } else {
        // 对手简单策略
        const discardIndex = Math.floor(Math.random() * player.hand.length);
        const discardedCard = player.hand.splice(discardIndex, 1)[0];
        discardedChars.push(discardedCard.character);

        // 对手摸牌
        if (deck.length > 0) {
          player.hand.push(deck.pop());
        }

        // 模拟对手碰牌
        const pengCount = player.hand.filter(c => c.character === discardedCard.character).length;
        if (pengCount >= 2 && Math.random() < 0.3) {
          const pengCards = player.hand.filter(c => c.character === discardedCard.character).slice(0, 2);
          player.hand = player.hand.filter(c => c.character !== discardedCard.character || !pengCards.some(pc => pc.id === c.id));
          player.melds.push({ type: 'triplet', cards: [...pengCards, discardedCard], huValue: 2 });
        }

        // 模拟对手吃牌
        if (shouldAIChiHard(player, discardedCard) && Math.random() < 0.2) {
          // 简单吃牌
          const s = discardedCard.sentence;
          const p = discardedCard.position;
          let chi1, chi2;
          if (p === 0) {
            chi1 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 1);
            chi2 = ALL_CHARACTERS.find(c => cardMap[c].s === s && cardMap[c].p === 2);
          } else if (p === 1) {
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

  stats.huRate = stats.huCount * 100;
  return stats;
}

// ========== 主测试 ==========

async function runHuRateTest(numGames = 100) {
  console.log('========================================');
  console.log('  困难模式AI胡牌率测试');
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
    if (i % 20 === 0) {
      process.stdout.write(`\n进度: ${i}/${numGames}`);
    } else if (i % 5 === 0) {
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
  console.log(`平均每局: ${(elapsed / numGames).toFixed(0)}毫秒`);

  console.log('\n胡牌类型分布:');
  for (const [type, count] of Object.entries(results.huTypes)) {
    console.log(`  ${type}: ${count}次`);
  }

  return results;
}

// 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runHuRateTest };
} else {
  window.runHuRateTest = runHuRateTest;
}
